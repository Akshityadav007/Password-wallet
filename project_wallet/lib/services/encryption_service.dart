// services/encryption_service.dart
import 'dart:convert';
import 'dart:typed_data';
import '../domain/interfaces/crypto_service.dart';

class EncryptionService {
  final CryptoService crypto;
  EncryptionService(this.crypto);

  /// Encrypts a UTF-8 string using the provided key.
  /// Returns a map containing Base64-encoded nonce and ciphertext.
  Future<Map<String, String>> encryptString(String plain, Uint8List key) async {
    final encrypted = await crypto.encrypt(
      Uint8List.fromList(utf8.encode(plain)),
      key,
    );

    final nonce = encrypted['nonce']!;
    final ciphertext = encrypted['ciphertext']!;

    return {
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
    };
  }

  /// Decrypts a Base64-encoded ciphertext and nonce using the provided key.
  Future<String> decryptString(
    String cipherBase64,
    String nonceBase64,
    Uint8List key,
  ) async {
    final ciphertext = base64Decode(cipherBase64);
    final nonce = base64Decode(nonceBase64);

    final plainBytes = await crypto.decrypt(
      ciphertext,
      nonce,
      key,
    );

    return utf8.decode(plainBytes);
  }
}
