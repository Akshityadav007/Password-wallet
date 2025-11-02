import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/data/sources/local/secure_storage.dart';
import 'package:password_wallet/domain/interfaces/crypto_service.dart';
import 'package:password_wallet/services/session_service.dart';
import 'biometric_service.dart';

// Handles master password registration, verification, and biometric unlock.
class AuthService {
  final CryptoService crypto;
  final SecureStorage secureStorage;
  final BiometricService biometricService;

  // Secure storage keys
  static const _keySalt = 'master_salt';
  static const _keyHash = 'master_key_hash';
  static const _keyBioToken = 'bio_token';
  static const _keyBioEnabled = 'biometric_enabled';
  static const _keyBioSalt = 'bio_salt'; 

  AuthService({
    required this.crypto,
    required this.biometricService,
    required this.secureStorage,
  });

  static String get keySalt => _keySalt;

  // ---------------------------------------------------------------------------
  // 🔹 1. Registration — first-time setup
  // ---------------------------------------------------------------------------
  Future<void> registerMasterPassword(String password) async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKeyFromPassword(password, outLen: 32, salt: salt);
    final keyHash = base64Encode(await crypto.hashKey(key));

    await secureStorage.write(key: _keySalt, value: base64Encode(salt));
    await secureStorage.write(key: _keyHash, value: keyHash);

    // Clear any old biometric data
    await secureStorage.delete(key: _keyBioToken);
    await secureStorage.delete(key: _keyBioEnabled);
    await secureStorage.delete(key: _keyBioSalt);
  }

  // ---------------------------------------------------------------------------
  // 🔹 2. Login — derive key from entered password & verify
  // ---------------------------------------------------------------------------
  Future<Uint8List?> verifyMasterPassword(String password) async {
    final saltB64 = await secureStorage.read(key: _keySalt);
    final storedHash = await secureStorage.read(key: _keyHash);
    if (saltB64 == null || storedHash == null) return null;

    final salt = base64Decode(saltB64);
    final derivedKey = await crypto.deriveKeyFromPassword(password, outLen: 32, salt: salt);
    final derivedHash = base64Encode(await crypto.hashKey(derivedKey));

    if (derivedHash != storedHash) return null;
    return derivedKey;
  }

  // ---------------------------------------------------------------------------
  // 🔹 3. Enable Biometric Unlock — store encrypted master key
  // ---------------------------------------------------------------------------
  Future<void> enableBiometricUnlock(Uint8List masterKey) async {
    final canUse = await biometricService.canUseBiometrics();
    if (!canUse) throw Exception('Biometrics not supported or not enrolled');

    // Derive a device-bound encryption key using random salt
    final bioSalt = crypto.generateSalt();
    final bioKey = await crypto.deriveKeyFromPassword('biometric', outLen: 32, salt: bioSalt);

    // Encrypt master key with the derived bio key
    final encrypted = await crypto.encrypt(masterKey, bioKey);

    final payload = {
      'nonce': base64Encode(encrypted['nonce']!),
      'ciphertext': base64Encode(encrypted['ciphertext']!),
    };

    await secureStorage.write(key: _keyBioToken, value: jsonEncode(payload));
    await secureStorage.write(key: _keyBioSalt, value: base64Encode(bioSalt));
    await secureStorage.write(key: _keyBioEnabled, value: 'true');

  }

  Future<bool> isBiometricEnabled() async {
    final v = await secureStorage.read(key: _keyBioEnabled);
    return v == 'true';
  }

  // ---------------------------------------------------------------------------
  // 🔹 4. Biometric Unlock — decrypt stored master key
  // ---------------------------------------------------------------------------
  Future<Uint8List?> unlockWithBiometrics() async {
    final enabled = await isBiometricEnabled();
    if (!enabled) return null;

    final canUse = await biometricService.canUseBiometrics();
    if (!canUse) return null;

    final authenticated = await biometricService.authenticateWithBiometrics(
      reason: 'Unlock your password vault',
    );
    if (!authenticated) return null;

    final tokenJson = await secureStorage.read(key: _keyBioToken);
    final saltB64 = await secureStorage.read(key: _keyBioSalt);
    if (tokenJson == null || saltB64 == null) {
      return null;
    }

    final payload = jsonDecode(tokenJson);
    final nonce = base64Decode(payload['nonce']);
    final ciphertext = base64Decode(payload['ciphertext']);
    final bioSalt = base64Decode(saltB64);

    try {
      // Re-derive the same key used during encryption
      final bioKey = await crypto.deriveKeyFromPassword('biometric', outLen: 32, salt: bioSalt);
      final masterKey = await crypto.decrypt(ciphertext, nonce, bioKey);
      return masterKey;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 5. Utility Helpers
  // ---------------------------------------------------------------------------
  Future<bool> hasMasterPassword() async {
    final salt = await secureStorage.read(key: _keySalt);
    final hash = await secureStorage.read(key: _keyHash);
    return salt != null && hash != null;
  }

  //  logout — clear session but keep biometric data
Future<void> clearSession() async {
  final session = GetIt.I<SessionService>();
  session.clear();
}


  // factory reset
  Future<void> clearAll() async {
    await secureStorage.delete(key: _keySalt);
    await secureStorage.delete(key: _keyHash);
    await secureStorage.delete(key: _keyBioToken);
    await secureStorage.delete(key: _keyBioEnabled);
    await secureStorage.delete(key: _keyBioSalt);
  }


}
