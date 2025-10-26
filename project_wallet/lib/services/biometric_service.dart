import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Handles biometric authentication (fingerprint, face, etc.)
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check whether biometrics are available and supported on device.
  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      print('🔍 canCheck=$canCheck, supported=$supported');
      return canCheck && supported;
    } on PlatformException catch (e) {
      print('⚠️ Biometric check failed: $e');
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      print('📋 Available biometrics: $biometrics');
      return biometrics;
    } on PlatformException catch (e) {
      print('⚠️ Error fetching biometrics: $e');
      return <BiometricType>[];
    }
  }

  /// Trigger biometric prompt (fingerprint/face ID)
  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to unlock your vault',
  }) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      print('❌ Unsupported platform for biometrics');
      return false;
    }

    try {
      final canUse = await canUseBiometrics();
      if (!canUse) {
        print('❌ Biometrics not available or not enrolled');
        return false;
      }

      print('🔐 Launching biometric prompt...');
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
      );

      print('✅ Biometric authentication result: $didAuthenticate');
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('⚠️ PlatformException during biometrics: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      print('⚠️ Unknown biometric error: $e');
      return false;
    }
  }

  /// Optional: fallback to biometrics + device credential (PIN/pattern)
  Future<bool> authenticate({
    String reason = 'Authenticate to continue',
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Unlock Password Vault',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
      );

      print('✅ Biometric/device auth result: $didAuthenticate');
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('⚠️ Auth failed: ${e.message}');
      return false;
    }
  }

  /// Cancel any ongoing authentication prompt
  Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      print('⚠️ stopAuthentication() error: $e');
    }
  }
}
