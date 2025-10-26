import 'dart:typed_data';

/// Holds sensitive session data (e.g. decrypted master key)
/// Exists only in memory — cleared when app restarts or logs out.
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Uint8List? _masterKey;

  /// Save decrypted master key in memory
  void setMasterKey(Uint8List key) {
    _masterKey = Uint8List.fromList(key);
    print('🔐 Master key stored in session memory.');
  }

  /// Retrieve master key if available
  Uint8List? get masterKey => _masterKey;

  /// Clear session data (e.g. on logout or lock)
  void clear() {
    _masterKey = null;
    print('🧹 Session memory cleared.');
  }

  /// Quick helper
  bool get hasActiveSession => _masterKey != null;

  
}
