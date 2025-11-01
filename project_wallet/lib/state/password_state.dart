// Password list management (Provider, Riverpod, etc.)

import 'package:flutter/foundation.dart';
import '../data/models/password_entry.dart';
import '../domain/repositories/password_repository.dart';

class PasswordState extends ChangeNotifier {
  final PasswordRepository repo;
  List<PasswordEntry> entries = [];
  bool loading = false;

  PasswordState(this.repo);

  Future<void> load() async {
    loading = true;
    notifyListeners();
      try {
        entries = await repo.getAll();
      } 
      finally {
        loading = false;
        notifyListeners();
      }
  }

  Future<void> add(PasswordEntry e) async {
    final id = await repo.add(e);
    entries.insert(0, e.copyWith(id: id));
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await repo.remove(id);
    entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

}
