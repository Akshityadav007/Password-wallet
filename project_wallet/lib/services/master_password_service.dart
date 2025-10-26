import 'dart:typed_data';
import 'package:password_wallet/domain/interfaces/crypto_service.dart';
import 'package:password_wallet/domain/repositories/password_repository.dart';

class MasterPasswordService {
  final PasswordRepository _repo;
  final CryptoService _crypto;

  MasterPasswordService(this._repo, this._crypto);

  /// Re-encrypts all stored entries with a new key derived from the new password.
  Future<void> changeMasterPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final entries = await _repo.getAllPasswords();

    final oldSalt = Uint8List.fromList([]); // fetch per-entry salt if stored
    final oldKey = await _crypto.deriveKeyFromPassword(
      oldPassword,
      outLen: 32,
      salt: oldSalt,
    );

    final newSalt = _crypto.generateSalt();
    final newKey = await _crypto.deriveKeyFromPassword(
      newPassword,
      outLen: 32,
      salt: newSalt,
    );

    // decrypt → re-encrypt all
    // (pseudo code — actual field names depend on PasswordEntry)
    for (final entry in entries) {
      final decrypted = await _crypto.decrypt(
        entry['ciphertext'],
        entry['nonce'],
        oldKey,
      );
      final reenc = await _crypto.encrypt(decrypted, newKey);
      entry['ciphertext'] = reenc['ciphertext']!;
      entry['nonce'] = reenc['nonce']!;
      // store new salt in metadata if applicable
    }

    await _repo.restoreFromJson(entries);
  }
}
