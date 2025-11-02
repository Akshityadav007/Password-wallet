import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/services/auth_service.dart';
import 'package:password_wallet/services/biometric_service.dart';
import 'package:password_wallet/services/lock_service.dart';
import 'package:password_wallet/services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final AuthService _authService = GetIt.I<AuthService>();
  final BiometricService _biometricService = GetIt.I<BiometricService>();
  final LockService _lockService = GetIt.I<LockService>();

  bool _biometricAvailable = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUser();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final enabled = await _authService.isBiometricEnabled();
      final supported = await _biometricService.canUseBiometrics();  
      setState(() => _biometricAvailable = enabled && supported);
    } catch (e) {
      setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _checkFirstTimeUser() async {
    final hasPassword = await _authService.hasMasterPassword();

    if (!hasPassword && mounted) {
      Navigator.of(context).pushReplacementNamed('/master-password');
      return;
    }

    // check biometrics
    await _checkBiometricAvailability();

    // Auto prompt if allowed by LockService
    if (_lockService.shouldAutoPromptBiometric) {
      _attemptBiometricUnlock();
    }
  }

  Future<void> _attemptBiometricUnlock() async {
    setState(() => _isLoading = true);

    try {
      final enabled = await _authService.isBiometricEnabled();
      final supported = await _biometricService.canUseBiometrics();

      if (enabled && supported) {
        final success = await _biometricService.authenticateWithBiometrics(
          reason: 'Use your fingerdebugPrint to unlock vault',
        );

        if (success) {
          final key = await _authService.unlockWithBiometrics();
          if (key != null) {
            final session = GetIt.I<SessionService>();
            session.setMasterKey(key);

            final lockService = GetIt.I<LockService>();
            lockService.resetAutoLockTimer();
            lockService.disableAutoPrompt(); 

            _showSnack('Unlocked via biometrics!');
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/home');
            return;
          } else {
            _showSnack('Biometric key not found or corrupted');
          }
        } else {
          _showSnack('Biometric authentication failed or canceled');
        }
      } else {
        _showSnack('Biometric unlock not available or not enabled');
      }
    } catch (e) {
      _showSnack('Error during biometric unlock: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _biometricAvailable = true;
      });
    }
  }

  Future<void> _onUnlockPressed() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _showSnack('Enter your master password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final key = await _authService.verifyMasterPassword(password);
      if (key != null) {
        _showSnack('Unlocked successfully!');

        final session = GetIt.I<SessionService>();
        session.setMasterKey(key);

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showSnack('Invalid password');
      }
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Unlock Your Vault',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your master password or use biometrics to unlock.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Master Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onUnlockPressed,
                      icon: const Icon(Icons.login),
                      label: const Text('Unlock Vault'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_biometricAvailable)
                    GestureDetector(
                      onTap: _attemptBiometricUnlock,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.9),
                              theme.colorScheme.primary.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint,
                              size: 26,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Unlock with Biometrics',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/master-password');
                    },
                    child: Text(
                      "Create a new vault",
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
