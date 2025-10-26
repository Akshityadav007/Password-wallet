import 'dart:typed_data';

abstract class CryptoService {
  Uint8List generateSalt();

  Future<Uint8List> deriveKeyFromPassword(
    String password, {
    required int outLen,
    Uint8List? salt,
  });

  Future<Map<String, Uint8List>> encrypt(
    Uint8List message,
    Uint8List key,
  );

  Future<Uint8List> decrypt(
    Uint8List ciphertext,
    Uint8List nonce,
    Uint8List key,
  );

  Future<Uint8List> hashKey(Uint8List key);
}
