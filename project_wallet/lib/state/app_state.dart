// Global app lock/unlock status

import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool _unlocked = false;

  bool get unlocked => _unlocked;

  void unlock() {
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    _unlocked = false;
    notifyListeners();
  }
}
