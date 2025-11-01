import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/app/routes.dart';
import 'package:password_wallet/services/lock_service.dart';
import 'package:password_wallet/app/theme.dart';


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _lockService = GetIt.I<LockService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockService.resetAutoLockTimer(); // start the first timer
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockService.cancelAutoLockTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Reset timer when app comes back to foreground
      _lockService.resetAutoLockTimer();
    }
  }

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: _lockService.resetAutoLockTimer, // reset on user activity
      onPanDown: (_) => _lockService.resetAutoLockTimer(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Password Wallet',
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routes: appRoutes,
        initialRoute: '/',
      ),
    );
  }
}

