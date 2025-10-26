import 'dart:typed_data';
import 'dart:convert';
import 'package:sodium_libs/sodium_libs_sumo.dart';
import 'package:password_wallet/domain/interfaces/crypto_service.dart';

class CryptoServiceImpl implements CryptoService {
  final SodiumSumo _sodium;
  CryptoServiceImpl(this._sodium);

  SodiumSumo get sodium => _sodium;   // getter

  /// Derives a secure key using Argon2id (libsodium's pwhash)
  @override
  Future<Uint8List> deriveKeyFromPassword(
    String password, {
    required int outLen,
    Uint8List? salt,
  }) async {
    final actualSalt =
        salt ?? _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);

    final passwordBytes = Int8List.fromList(utf8.encode(password));

    // Derive key (returns SecureKey)
    final secureKey = _sodium.crypto.pwhash(
      outLen: outLen,
      password: passwordBytes,
      salt: actualSalt,
      opsLimit: _sodium.crypto.pwhash.opsLimitInteractive,
      memLimit: _sodium.crypto.pwhash.memLimitInteractive,
    );

    // Extract as Uint8List
    final keyBytes = secureKey.extractBytes();
    secureKey.dispose();

    return keyBytes;
  }

  /// Generates a random salt for key derivation
  @override
  Uint8List generateSalt() {
    return _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);
  }

  ///  Encrypts plaintext using SecretBox (XSalsa20-Poly1305)
  @override
  Future<Map<String, Uint8List>> encrypt(
    Uint8List message,
    Uint8List key,
  ) async {
    final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);
    final secureKey = _sodium.secureCopy(key);

    try {
      final ciphertext = _sodium.crypto.secretBox.easy(
        message: message,
        nonce: nonce,
        key: secureKey,
      );

      return {
        'nonce': nonce,
        'ciphertext': ciphertext,
      };
    } finally {
      secureKey.dispose(); // securely wipes memory
    }
  }

  /// Decrypts ciphertext using the given nonce + key.
  @override
  Future<Uint8List> decrypt(
    Uint8List ciphertext,
    Uint8List nonce,
    Uint8List key,
  ) async {
    final secureKey = _sodium.secureCopy(key);

    try {
      final plain = _sodium.crypto.secretBox.openEasy(
        cipherText: ciphertext,
        nonce: nonce,
        key: secureKey,
      );

      return Uint8List.fromList(plain);
    } finally {
      secureKey.dispose();
    }
  }


  // ---------------------------------------------------------------------------
  //  Compute a cryptographic hash (BLAKE2b) of a key
  // ---------------------------------------------------------------------------

  @override
  @override
  Future<Uint8List> hashKey(Uint8List key) async {
    // Use libsodium's generic hash (BLAKE2b) via the GenericHash helper
    final hash = _sodium.crypto.genericHash(message: key, outLen: 32);
    return Uint8List.fromList(hash);
  }
  
}
