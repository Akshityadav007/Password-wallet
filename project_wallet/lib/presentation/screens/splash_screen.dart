import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/services/auth_service.dart';
import 'package:password_wallet/services/biometric_service.dart';
import 'package:password_wallet/services/lock_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = GetIt.I<AuthService>();
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _animateIn();
    _initApp();
  }

  Future<void> _animateIn() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _opacity = 1.0);
  }

Future<void> _initApp() async {
  await Future.delayed(const Duration(milliseconds: 800));

  final authService = _authService;
  final biometricService = GetIt.I<BiometricService>();
  final lockService = GetIt.I<LockService>();

  final hasPassword = await authService.hasMasterPassword();
  if (!mounted) return;

  if (!hasPassword) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/master-password', (route) => false);
    return;
  }

  // Ensure services are ready
  final supported = await biometricService.canUseBiometrics();
  final enabled = await authService.isBiometricEnabled();

  if (enabled && supported) {
    if (!mounted) return;
    final success = await lockService.tryBiometricUnlock(context);

    if (success) {
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/home', (route) => false);
      return;
    } else {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  // fallback
  if (!mounted) return;
  Navigator.of(context)
      .pushNamedAndRemoveUntil('/login', (route) => false);
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _opacity,
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 80, color: theme.primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    'Password Wallet',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
