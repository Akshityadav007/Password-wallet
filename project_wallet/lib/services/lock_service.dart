import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/services/auth_service.dart';
import 'package:password_wallet/services/biometric_service.dart';
import 'package:password_wallet/services/session_service.dart';

// 🔹 Global navigation key for logout navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Manages app lock/unlock logic, biometric behavior, and timeout preferences.
class LockService {
  final AuthService _authService = GetIt.I<AuthService>();
  final BiometricService _biometricService = GetIt.I<BiometricService>();
  final SessionService _session = GetIt.I<SessionService>();

  // ---------------------------------------------------------------------------
  // 🔹 App Lock Configuration
  // ---------------------------------------------------------------------------
  Duration _lockTimeout = const Duration(minutes: 5);
  bool _lockOnBackground = true;

  Duration get lockTimeout => _lockTimeout;
  bool get lockOnBackground => _lockOnBackground;

  Future<void> updatePreferences({
    Duration? timeout,
    bool? lockOnBackground,
  }) async {
    if (timeout != null) _lockTimeout = timeout;
    if (lockOnBackground != null) _lockOnBackground = lockOnBackground;
    // resetAutoLockTimer();
  }

  // ---------------------------------------------------------------------------
  // 🔹 Biometric Auto Prompt Handling
  // ---------------------------------------------------------------------------
  bool _shouldAutoPromptBiometric = true;

  bool get shouldAutoPromptBiometric => _shouldAutoPromptBiometric;

  void disableAutoPrompt() => _shouldAutoPromptBiometric = false;
  void enableAutoPrompt() => _shouldAutoPromptBiometric = true;

  // ---------------------------------------------------------------------------
  // 🔹 Biometric Control via AuthService (Fixed)
  // ---------------------------------------------------------------------------
  Future<bool> isBiometricEnabled() async {
    return await _authService.isBiometricEnabled();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final canUse = await _biometricService.canUseBiometrics();
      if (!canUse) throw Exception('Biometric authentication not supported.');

      final ok = await _biometricService.authenticateWithBiometrics(
        reason: 'Confirm biometric to enable unlock',
      );
      if (!ok) throw Exception('Biometric authentication failed or cancelled.');

      final key = _session.masterKey;
      if (key == null) throw Exception('Master key not found.');

      await _authService.enableBiometricUnlock(key);
    } else {
      await _authService.secureStorage.write(key: 'biometric_enabled', value: 'false');
      await _authService.secureStorage.delete(key: 'bio_token');
      await _authService.secureStorage.delete(key: 'bio_salt');
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 Manual Lock / Unlock Control
  // ---------------------------------------------------------------------------
  Future<void> lockVault() async {
    await _authService.clearSession();
  }

  bool _biometricInProgress = false;

Future<bool> tryBiometricUnlock(BuildContext context) async {
  if (_biometricInProgress) {
    return false;
  }

  _biometricInProgress = true;
  try {
    final enabled = await _authService.isBiometricEnabled();
    final supported = await _biometricService.canUseBiometrics();

    if (!enabled || !supported) {
      _biometricInProgress = false;
      return false;
    }

    final success = await _biometricService.authenticateWithBiometrics(
      reason: 'Authenticate to unlock your vault',
    );

    if (success) {
      final key = await _authService.unlockWithBiometrics();
      if (key != null) {
        _session.setMasterKey(key);
        debugPrint('Biometric unlock successful, setting master key in session.');
        return true;
      }
    }

    return false;
  } finally {
    _biometricInProgress = false;
  }
}



  // ---------------------------------------------------------------------------
  // 🔹 Logout (used by auto-lock timer or manually)
  // ---------------------------------------------------------------------------
  Future<void> logout({bool showMessage = false}) async {
    await _authService.clearSession();
    disableAutoPrompt();

    final hasPassword = await _authService.hasMasterPassword();
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final context = navigator.context;

    if (showMessage && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired — please log in again'),
          duration: Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    if (hasPassword) {
      navigator.pushNamedAndRemoveUntil('/login', (r) => false);
    } else {
      navigator.pushNamedAndRemoveUntil('/master-password', (r) => false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 Auto-lock timer (based on user inactivity)
  // ---------------------------------------------------------------------------
  Timer? _lockTimer;

 // lock_service.dart

void resetAutoLockTimer() {
  _lockTimer?.cancel();

  if (_lockTimeout == Duration.zero) {
    return;
  }

  _lockTimer = Timer(_lockTimeout, () async {
    await logout(showMessage: true);
  });
}


  void cancelAutoLockTimer() {
    _lockTimer?.cancel();
  }

}
