import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/domain/interfaces/crypto_service.dart';
import 'package:password_wallet/domain/repositories/password_repository.dart';
import 'package:password_wallet/data/models/password_entry.dart';
import 'package:password_wallet/services/auth_service.dart';

class MasterPasswordService {
  final PasswordRepository _repo;
  final CryptoService _crypto;

  MasterPasswordService(this._repo, this._crypto);

  /// Re-encrypts all stored entries with a new key derived from the new password.
  Future<void> changeMasterPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final authService = GetIt.I.get<AuthService>();

    // Fetch device salt from secure storage
    final saltB64 = await authService.secureStorage.read(key: AuthService.keySalt);
    if (saltB64 == null) {
      throw Exception('Device salt not found in secure storage.');
    }

    final oldSalt = base64Decode(saltB64);
    final newSalt = _crypto.generateSalt();

    // Derive old and new keys
    final oldKey = await _crypto.deriveKeyFromPassword(
      oldPassword,
      outLen: 32,
      salt: oldSalt,
    );

    final newKey = await _crypto.deriveKeyFromPassword(
      newPassword,
      outLen: 32,
      salt: newSalt,
    );

    //  Save the new salt in secure storage
    await authService.secureStorage.write(
      key: AuthService.keySalt,
      value: base64Encode(newSalt),
    );

    // Fetch all entries from DB
    final entries = await _repo.getAll();
    final updatedEntries = <PasswordEntry>[];

    for (final entry in entries) {
      try {
        // Decrypt existing data using old key
        final decrypted = await _crypto.decrypt(
          base64Decode(entry.ciphertext),
          base64Decode(entry.nonce),
          oldKey,
        );

        // Re-encrypt using new key
        final reenc = await _crypto.encrypt(decrypted, newKey);

        final updated = entry.copyWith(
          ciphertext: base64Encode(reenc['ciphertext']!),
          nonce: base64Encode(reenc['nonce']!),
        );

        updatedEntries.add(updated);
      } catch (e) {
        debugPrint('Failed to re-encrypt entry ${entry.id}: $e');
      }
    }

    // Replace all entries with updated (re-encrypted) ones
    await _repo.clearAll();
    for (final entry in updatedEntries) {
      await _repo.add(entry);
    }
  }
}
