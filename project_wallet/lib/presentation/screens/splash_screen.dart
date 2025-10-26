import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/services/auth_service.dart';

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

    final hasPassword = await _authService.hasMasterPassword();
    if (!mounted) return;

    if (!hasPassword) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/master-password', (route) => false);
      return;
    }

    final key = await _authService.unlockWithBiometrics();
    if (!mounted) return;

    if (key != null) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
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
