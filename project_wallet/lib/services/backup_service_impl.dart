// services/backup_service_impl.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:password_wallet/domain/interfaces/backup_service.dart';
import 'package:password_wallet/domain/interfaces/crypto_service.dart';
import 'package:password_wallet/domain/repositories/password_repository.dart';
import 'package:sodium/sodium_sumo.dart';


enum BackupShareStatus { success, cancelled, unavailable, error }

class BackupServiceImpl implements BackupService {
  final PasswordRepository _passwordRepo;
  final CryptoService _cryptoService;

  BackupServiceImpl(this._passwordRepo, this._cryptoService);

  static const int _formatVersion = 2;
  

  // ---------------------------------------------------
  // 🔐 HMAC computation and verification
  // ---------------------------------------------------
 // new raw-byte HMAC helper

Uint8List _concat3(Uint8List a, Uint8List b, Uint8List c) {
  final result = Uint8List(a.length + b.length + c.length);
  result.setRange(0, a.length, a);
  result.setRange(a.length, a.length + b.length, b);
  result.setRange(a.length + b.length, a.length + b.length + c.length, c);
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
    // message = salt || nonce || ciphertext (binary concat)
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

    return sodium.crypto.auth.verify(message: message, tag: expectedMac, key: secureKey);
  } finally {
    secureKey.dispose();
  }
}


  // ---------------------------------------------------
  // 📤 EXPORT ENCRYPTED BACKUP (Android/iOS only)
  // ---------------------------------------------------
@override
Future<String> exportEncryptedBackup({
  String? masterPassword,
  Uint8List? masterKey,
}) async {
  if (masterKey == null && (masterPassword == null || masterPassword.isEmpty)) {
    throw ArgumentError('Either masterKey or masterPassword must be provided');
  }

  final sodium = (_cryptoService as dynamic).sodium as SodiumSumo;

  // 1️⃣ Get all entries
  final entries = await _passwordRepo.getAllPasswords();
  final plainJson = jsonEncode(entries);

  // 2️⃣ Derive key and encrypt
  final salt = _cryptoService.generateSalt();
  final key = masterKey ??
      await _cryptoService.deriveKeyFromPassword(
        masterPassword!,
        outLen: 32,
        salt: salt,
      );

  final cipherResult = await _cryptoService.encrypt(
    Uint8List.fromList(utf8.encode(plainJson)),
    key,
  );
  final ciphertext = cipherResult['ciphertext'] ?? Uint8List(0);
  final nonceUsed = cipherResult['nonce'] ?? Uint8List(0);

  // 3️⃣ Compute HMAC
  final hmacBytes = _computeHmacRaw(key, salt, nonceUsed, ciphertext, sodium);



  // 4️⃣ Prepare JSON payload
  final payload = {
    'version': _formatVersion,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonceUsed),
    'ciphertext': base64Encode(ciphertext),
    'hmac': base64Encode(hmacBytes),
    'created_at': DateTime.now().toIso8601String(),
  };

  // Encode file data to bytes (UTF-8)
  final backupBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

  // 5️⃣ Ask user where to save (works on Android/iOS too)
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save encrypted backup file',
    fileName: 'pwbackup_${DateTime.now().millisecondsSinceEpoch}.pwbackup',
    type: FileType.custom,
    allowedExtensions: ['pwbackup'],
    bytes: backupBytes, // 🟩 REQUIRED on Android/iOS
  );

  if (savePath == null) {
    throw Exception('Backup export cancelled by user');
  }

  return savePath;
}



  // ---------------------------------------------------
  // 📥 IMPORT ENCRYPTED BACKUP
  // ---------------------------------------------------
  @override
  Future<int> importEncryptedBackup({
    required String filePath,
    String? masterPassword,
    Uint8List? masterKey,
  }) async {
    int passLength = 0;
    if (masterKey == null &&
        (masterPassword == null || masterPassword.isEmpty)) {
      throw ArgumentError(
        'Either masterKey or masterPassword must be provided',
      );
    }

    final file = File(filePath);
    if (!await file.exists())
     { throw Exception('Backup file not found at $filePath');}

    final raw = await file.readAsString();
    final Map<String, dynamic> payload = jsonDecode(raw);
    final version = payload['version'] ?? 1;

    if (version > _formatVersion) {
      throw Exception('Unsupported backup version: $version');
    }

    try {
      final salt = base64Decode(payload['salt'] as String);
      final nonce = base64Decode(payload['nonce'] as String);
      final ciphertext = base64Decode(payload['ciphertext'] as String);

      final key =
          masterKey ??
          await _cryptoService.deriveKeyFromPassword(
            masterPassword!,
            outLen: 32,
            salt: salt,
          );

      final sodium = (_cryptoService as dynamic).sodium as SodiumSumo;

      // ✅ Verify HMAC if available
      if (payload.containsKey('hmac')) {
        final storedHmac = base64Decode(payload['hmac'] as String);
        final ok = _verifyHmacRaw(
          key,
          salt,
          nonce,
          ciphertext,
          storedHmac,
          sodium,
        );


        if (!ok) {
          throw Exception(
            'Backup integrity check failed — file may be tampered.',
          );
        }
      }

      // ✅ Decrypt and restore
      final decryptedBytes = await _cryptoService.decrypt(
        ciphertext,
        nonce,
        key,
      );
      final decryptedJson = utf8.decode(decryptedBytes);
      final List<dynamic> jsonList = jsonDecode(decryptedJson);

      await _passwordRepo.restoreFromJson(jsonList);
      print('✅ Backup import successful — ${jsonList.length} entries restored.');
      passLength = jsonList.length;
    } catch (e) {
      throw Exception('Failed to decrypt/restore backup: $e');
    }
    return passLength;
  }

  // ---------------------------------------------------
  // ✅ VERIFY BACKUP
  // ---------------------------------------------------
  @override
  Future<bool> verifyBackup({
    required String filePath,
    String? masterPassword,
    Uint8List? masterKey,
  }) async {
    try {
      if (masterKey == null &&
          (masterPassword == null || masterPassword.isEmpty)) {
        throw ArgumentError(
          'Either masterKey or masterPassword must be provided',
        );
      }

      final file = File(filePath);
      if (!await file.exists()) return false;

      final raw = await file.readAsString();
      final Map<String, dynamic> payload = jsonDecode(raw);
      final version = payload['version'] ?? 1;

      final salt = base64Decode(payload['salt'] as String);
      final nonce = base64Decode(payload['nonce'] as String);
      final ciphertext = base64Decode(payload['ciphertext'] as String);

      final key =
          masterKey ??
          await _cryptoService.deriveKeyFromPassword(
            masterPassword!,
            outLen: 32,
            salt: salt,
          );

      final sodium = (_cryptoService as dynamic).sodium as SodiumSumo;

      if (version >= 2 && payload.containsKey('hmac')) {
        final storedHmac = base64Decode(payload['hmac'] as String);
        final ok = _verifyHmacRaw(
          key,
          salt,
          nonce,
          ciphertext,
          storedHmac,
          sodium,
        );
        if (!ok) return false;
      }

      await _cryptoService.decrypt(ciphertext, nonce, key);
      return true;
    } catch (_) {
      return false;
    }
  }
}
