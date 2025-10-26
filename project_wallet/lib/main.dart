import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';
import 'injection.dart' as injection;
import 'app/app.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/services/lock_service.dart';
import 'package:password_wallet/services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sodium = await SodiumSumoInit.init();
  await injection.configureDependencies(sodium);

  final lockService = GetIt.I<LockService>();
  lockService.enableAutoPrompt();

  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(
    ChangeNotifierProvider.value(
      value: themeService,
      child: const MyApp(),
    ),
  );
}
