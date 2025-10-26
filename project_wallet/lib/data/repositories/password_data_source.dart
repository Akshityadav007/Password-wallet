import '../models/password_entry.dart';
import '../sources/local/db_service.dart';

class PasswordDataSource {
  final DbService db;

  PasswordDataSource({required this.db});

  Future<int> add(PasswordEntry e) => db.insert(e);
  Future<List<PasswordEntry>> getAll() => db.all();
  Future<int> remove(int id) => db.delete(id);
}
