import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';
import 'injection.dart' as injection;
import 'app/app.dart';
import 'package:password_wallet/services/lock_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sodium = await SodiumSumoInit.init();
  await injection.configureDependencies(sodium);

  final lockService = GetIt.I<LockService>();
  lockService.enableAutoPrompt();

  runApp(const MyApp());
}
