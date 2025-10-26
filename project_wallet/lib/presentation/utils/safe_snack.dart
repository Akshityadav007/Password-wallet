import 'package:flutter/material.dart';

/// Displays a reusable, safe SnackBar throughout the app.
/// Automatically hides any existing snackbar before showing a new one.
/// Use [isError] to display it in red for errors.
void safeSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return; // Prevents crashes if context is invalid

  // Hide any existing snackbar before showing a new one
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: isError ? Colors.redAccent : Colors.black87,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      duration: duration,
    ),
  );
}
