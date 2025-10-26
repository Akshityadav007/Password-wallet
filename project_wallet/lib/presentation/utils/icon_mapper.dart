// presentation/utils/icon_mapper.dart
import 'package:flutter/material.dart';

IconData detectIconForTitle(String title) {
  final t = title.toLowerCase();
  if (t.contains('gmail') || t.contains('google') || t.contains('@gmail')) {
    return Icons.email;
  }
  if (t.contains('facebook')) return Icons.facebook;
  if (t.contains('twitter')) return Icons.tag;
  if (t.contains('bank') || t.contains('hdfc') || t.contains('sbi') || t.contains('icici')) {
    return Icons.account_balance;
  }
  if (t.contains('github')) return Icons.code;
  if (t.contains('amazon')) return Icons.shopping_bag;
  if (t.contains('paypal')) return Icons.account_balance_wallet;
  // fallback
  return Icons.grid_view;
}

// Helper to get theme-aware icon color
Color getIconColor(BuildContext context, {bool isPrimary = false}) {
  final theme = Theme.of(context);
  if (isPrimary) {
    return theme.colorScheme.primary;
  }
  return theme.brightness == Brightness.dark
      ? Colors.white70
      : Colors.black87;
}

// Helper to get background color for icon containers
Color getIconBackgroundColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? Colors.grey.shade800
      : Colors.grey.shade200;
}