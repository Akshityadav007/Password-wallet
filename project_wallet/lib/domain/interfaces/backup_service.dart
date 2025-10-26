import 'dart:typed_data';

abstract class BackupService {
  Future<String> exportEncryptedBackup({
    String? masterPassword,
    Uint8List? masterKey,
  });

  Future<int> importEncryptedBackup({
    required String filePath,
    String? masterPassword,
    Uint8List? masterKey,
  });

  Future<bool> verifyBackup({
    required String filePath,
    String? masterPassword,
    Uint8List? masterKey,
  });
  
}
