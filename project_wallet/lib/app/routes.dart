import 'package:flutter/material.dart';
import 'package:password_wallet/presentation/screens/settings_screen.dart';
import 'package:password_wallet/presentation/screens/splash_screen.dart';
import 'package:password_wallet/presentation/screens/login_screen.dart';
import 'package:password_wallet/presentation/screens/master_password_screen.dart';
import 'package:password_wallet/presentation/screens/home_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashScreen(),
  '/login': (context) => const LoginScreen(),
  '/master-password': (context) => const MasterPasswordScreen(),
  '/home': (context) => const HomeScreen(),
  '/settings': (context) => const SettingsScreen(),
};
