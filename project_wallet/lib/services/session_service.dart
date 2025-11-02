import 'package:flutter/foundation.dart';

// Holds sensitive session data (e.g. decrypted master key)
// Exists only in memory — cleared when app restarts or logs out.

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Uint8List? _masterKey;
  final ValueNotifier<bool> vaultNeedsRefresh = ValueNotifier(false);

  // Save decrypted master key in memory
// session_service.dart

void setMasterKey(Uint8List key) {
  _masterKey = Uint8List.fromList(key);
}

  // Retrieve master key if available
  Uint8List? get masterKey => _masterKey;

  // Clear session data (e.g. on logout or lock)
 void clear() {
  _masterKey = null;
}

  void notifyVaultUpdated() {
    vaultNeedsRefresh.value = !vaultNeedsRefresh.value;
  }

  // Quick helper
  bool get hasActiveSession => _masterKey != null;

  
}
