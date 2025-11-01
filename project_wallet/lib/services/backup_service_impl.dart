// services/backup_service_impl.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/data/models/password_entry.dart';
import 'package:password_wallet/domain/interfaces/backup_service.dart';
import 'package:password_wallet/domain/interfaces/crypto_service.dart';
import 'package:password_wallet/domain/repositories/password_repository.dart';
import 'package:password_wallet/services/auth_service.dart';
import 'package:password_wallet/services/session_service.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';


enum BackupShareStatus { success, cancelled, unavailable, error }

class BackupServiceImpl implements BackupService {
  final PasswordRepository _passwordRepo;
  final CryptoService _cryptoService;

  BackupServiceImpl(this._passwordRepo, this._cryptoService);

  static const int _formatVersion = 2;

  // ---------------------------------------------------
  // HMAC computation and verification
  // ---------------------------------------------------
  Uint8List _concat3(Uint8List a, Uint8List b, Uint8List c) {
    final result = Uint8List(a.length + b.length + c.length);
    result.setRange(0, a.length, a);
    result.setRange(a.length, a.length + b.length, b);
    result.setRange(a.length + b.length, result.length, c);
    return result;
  }

  Uint8List _computeHmacRaw(
    Uint8List key,
    Uint8List salt,
    Uint8List nonce,
    Uint8List ciphertext,
    SodiumSumo sodium,
  ) {
    final hmacKey = key.length > 32 ? key.sublist(0, 32) : key;
    final secureKey = sodium.secureCopy(hmacKey);
    try {
      final message = _concat3(salt, nonce, ciphertext);
      final tag = sodium.crypto.auth(message: message, key: secureKey);
      return Uint8List.fromList(tag);
    } finally {
      secureKey.dispose();
    }
  }

  bool _verifyHmacRaw(
    Uint8List key,
    Uint8List salt,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List expectedMac,
    SodiumSumo sodium,
  ) {
    final hmacKey = key.length > 32 ? key.sublist(0, 32) : key;
    final secureKey = sodium.secureCopy(hmacKey);
    try {
      final message = _concat3(salt, nonce, ciphertext);
      final verified = sodium.crypto.auth.verify(
        message: message,
        tag: expectedMac,
        key: secureKey,
      );
      return verified;
    } finally {
      secureKey.dispose();
    }
  }

  // ---------------------------------------------------
  // EXPORT ENCRYPTED BACKUP
  // ---------------------------------------------------
  @override
  Future<String> exportEncryptedBackup({
    String? masterPassword,
    Uint8List? masterKey,
  }) async {
    if (masterKey == null && (masterPassword == null || masterPassword.isEmpty)) {
      throw ArgumentError('Either masterKey or masterPassword must be provided');
    }

    final authService = GetIt.I.get<AuthService>();
    final deviceSaltB64 = await authService.secureStorage.read(key: AuthService.keySalt);

    final sodium = (_cryptoService as dynamic).sodium as SodiumSumo;
    final salt = _cryptoService.generateSalt();
    final key = await _cryptoService.deriveKeyFromPassword(
      masterPassword!,
      outLen: 32,
      salt: salt,
    );

    final entries = await _passwordRepo.getAll();
    final plainJson = jsonEncode(entries.map((e) => e.toMap()).toList());

    final cipherResult = await _cryptoService.encrypt(
      Uint8List.fromList(utf8.encode(plainJson)),
      key,
    );
    final ciphertext = cipherResult['ciphertext'] ?? Uint8List(0);
    final nonceUsed = cipherResult['nonce'] ?? Uint8List(0);

    final hmacBytes = _computeHmacRaw(key, salt, nonceUsed, ciphertext, sodium);

    final payload = {
      'version': _formatVersion,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonceUsed),
      'ciphertext': base64Encode(ciphertext),
      'hmac': base64Encode(hmacBytes),
      'device_salt': deviceSaltB64,
      'created_at': DateTime.now().toIso8601String(),
    };

    final backupBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save encrypted backup file',
      fileName:
          'pwbackup_${DateTime.now().millisecondsSinceEpoch}.pwbackup',
      type: FileType.custom,
      allowedExtensions: ['pwbackup'],
      bytes: backupBytes,
    );

    if (savePath == null) throw Exception('Backup export cancelled by user');
    return savePath;
  }

// Import logic
@override
Future<int> importEncryptedBackup({required String filePath, required String oldMasterPassword, required String newMasterPassword}) async {
  

  final file = File(filePath);
  if (!await file.exists()) throw Exception('Backup file not found');
  final payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

  // Decrypt the outer backup layer using the backup salt
  final backupSalt = base64Decode(payload['salt']);
  final nonce = base64Decode(payload['nonce']);
  final ciphertext = base64Decode(payload['ciphertext']);

  final backupKey = await _cryptoService.deriveKeyFromPassword(
    oldMasterPassword,
    outLen: 32,
    salt: backupSalt,
  );

  final decryptedBytes = await _cryptoService.decrypt(ciphertext, nonce, backupKey);
  final entriesJson = utf8.decode(decryptedBytes);
  final List<dynamic> entriesList = jsonDecode(entriesJson);

  await _passwordRepo.restoreFromJson(entriesList);

  // Derive key used for inner (per-entry) encryption on the old device
  final deviceSaltB64FromBackup = payload['device_salt'];
  if (deviceSaltB64FromBackup == null) {
    throw Exception('Old device salt missing in backup.');
  }
  final oldDeviceSalt = base64Decode(deviceSaltB64FromBackup);

  final oldDeviceKey = await _cryptoService.deriveKeyFromPassword(
    oldMasterPassword,
    outLen: 32,
    salt: oldDeviceSalt,
  );

  // Derive the new key for this device (new password + current device salt)
  final authService = GetIt.I<AuthService>();
  final sessionService = GetIt.I<SessionService>();
  final newDeviceSaltB64 = await authService.secureStorage.read(key: AuthService.keySalt);
  if (newDeviceSaltB64 == null) throw Exception('New device salt missing!');

  final newDeviceKey = sessionService.masterKey;
  if (newDeviceKey == null) {
    throw Exception('Session master key missing — user must be logged in.');
  }

  // Re-encrypt entries with new device key
  final entries = await _passwordRepo.getAll();

  // Serialize entries before sending to isolate
  final entryMaps = entries.map((e) => e.toMap()).toList();

  await Future.delayed(Duration(milliseconds: 100));

  final updated = await Future(() async {
  final cryptoService = _cryptoService; // reuse existing instance, same sodium
  final List<Map<String, dynamic>> updated = [];

  for (final e in entryMaps) {
    final entry = PasswordEntry.fromMap(e);
    if (entry.isFolder) {
      updated.add(entry.toMap());
      continue;
    }
    try {
      final plain = await cryptoService.decrypt(
        base64Decode(entry.ciphertext),
        base64Decode(entry.nonce),
        oldDeviceKey,
      );
      final reenc = await cryptoService.encrypt(plain, newDeviceKey);
      updated.add(entry.copyWith(
        ciphertext: base64Encode(reenc['ciphertext']!),
        nonce: base64Encode(reenc['nonce']!),
      ).toMap());
    } catch (_) {}
  }
  return updated;
});


  // Apply updates back in the main isolate (DB access must stay on main)
  for (final e in updated) {
    final entry = PasswordEntry.fromMap(Map<String, dynamic>.from(e));
    await _passwordRepo.update(entry);
  }

  return updated.length;

}



  // ---------------------------------------------------
  // VERIFY BACKUP
  // ---------------------------------------------------
  @override
  Future<bool> verifyBackup({
    required String filePath,
    String? masterPassword,
    Uint8List? masterKey,
  }) async {
    try {
      if (masterKey == null && (masterPassword == null || masterPassword.isEmpty)) {
        throw ArgumentError('Either masterKey or masterPassword must be provided');
      }

      final file = File(filePath);
      if (!await file.exists()) return false;

      final payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final salt = base64Decode(payload['salt']);
      final nonce = base64Decode(payload['nonce']);
      final ciphertext = base64Decode(payload['ciphertext']);

      final key = masterKey ??
          await _cryptoService.deriveKeyFromPassword(
            masterPassword!,
            outLen: 32,
            salt: salt,
          );

      final sodium = (_cryptoService as dynamic).sodium as SodiumSumo;

      if (payload.containsKey('hmac')) {
        final storedHmac = base64Decode(payload['hmac']);
        if (!_verifyHmacRaw(key, salt, nonce, ciphertext, storedHmac, sodium)) return false;
      }

      await _cryptoService.decrypt(ciphertext, nonce, key);
      return true;
    } catch (_) {
      return false;
    }
  }
}
