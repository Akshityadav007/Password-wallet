import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  
    // Use fixed, cross-device constants
    const int opsLimit = 3;                  // ~Interactive
    const int memLimit = 64 * 1024 * 1024;   // 64 MB

    // Derive key (returns SecureKey)
    final secureKey = _sodium.crypto.pwhash(
      outLen: outLen,
      password: passwordBytes,
      salt: actualSalt,
      opsLimit: opsLimit,
      memLimit: memLimit,
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
    if (key.length != _sodium.crypto.secretBox.keyBytes) {
      throw ArgumentError(
        'Invalid key length: expected ${_sodium.crypto.secretBox.keyBytes}, got ${key.length}',
      );
    }

    final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);

    // Normalize key for current sodium context
    final secureKey = _sodium.secureCopy(Uint8List.fromList(key));

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
    } catch (e) {
      debugPrint('[CryptoService.encrypt] libsodium failed: $e');
      rethrow;
    } finally {
      secureKey.dispose();
    }
  }

  @override
  Future<Uint8List> decrypt(
    Uint8List ciphertext,
    Uint8List nonce,
    Uint8List key,
  ) async {
    if (key.length != _sodium.crypto.secretBox.keyBytes) {
      throw ArgumentError(
        'Invalid key length: expected ${_sodium.crypto.secretBox.keyBytes}, got ${key.length}',
      );
    }

    final secureKey = _sodium.secureCopy(Uint8List.fromList(key));

    try {
      final plain = _sodium.crypto.secretBox.openEasy(
        cipherText: ciphertext,
        nonce: nonce,
        key: secureKey,
      );
      return Uint8List.fromList(plain);
    } catch (e) {
      debugPrint('[CryptoService.decrypt] libsodium failed: $e');
      rethrow;
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
