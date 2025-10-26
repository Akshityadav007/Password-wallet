// Custom exceptions (DecryptionError, InvalidKey, etc.)

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => 'AppException: $message';
}

class DecryptionException extends AppException {
  DecryptionException(super.message);
}
