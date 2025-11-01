// lib/app/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static final lightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.light,
  );

  static final darkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.dark,
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightColorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: lightColorScheme.surface,
      foregroundColor: lightColorScheme.onSurface,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightColorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightColorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightColorScheme.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightColorScheme.primary,
        foregroundColor: lightColorScheme.onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: lightColorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: lightColorScheme.onInverseSurface),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkColorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: darkColorScheme.surface,
      foregroundColor: darkColorScheme.onSurface,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkColorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: darkColorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: darkColorScheme.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkColorScheme.primary,
        foregroundColor: darkColorScheme.onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: darkColorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: darkColorScheme.onInverseSurface),
    ),
  );
}
