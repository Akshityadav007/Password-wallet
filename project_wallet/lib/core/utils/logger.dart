// Safe logging wrapper

import 'package:flutter/material.dart';

void logInfo(String msg) {
  // Replace with more advanced logger if needed.
  // Avoid printing secrets.
  debugPrint('[INFO] $msg');
}
