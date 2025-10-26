// password_repository_impl.dart
import 'package:password_wallet/domain/repositories/password_repository.dart';
import 'package:password_wallet/data/sources/local/db_service.dart';
import 'package:password_wallet/data/models/password_entry.dart';

class PasswordRepositoryImpl implements PasswordRepository {
  final DbService _db;
  PasswordRepositoryImpl(this._db);

  static const table = 'passwords';

  // ----- CRUD -----
  @override
  Future<int> add(PasswordEntry entry) async {
    await _db.open();
    final map = Map<String, dynamic>.from(entry.toMap());
    if (map['id'] == null) map.remove('id');
    return await _db.db.insert(table, map);
  }

  @override
  Future<List<PasswordEntry>> all() async => _db.all();

  @override
  Future<int> remove(int id) async {
    await _db.open();
    return await _db.db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // ----- Backup/restore -----
  @override
  Future<List<Map<String, dynamic>>> getAllPasswords() async => _db.allAsMaps();

  @override
  Future<void> restoreFromJson(List<dynamic> jsonList) async {
    await _db.open();
    await _db.clearAll();
    for (final item in jsonList) {
      final map = Map<String, dynamic>.from(item as Map);
      // If map contains id but you want to preserve original ids, keep it.
      // Otherwise remove id to let sqlite assign new ones.
      // Here we attempt to preserve if present:
      await _db.insertRaw(map);
    }
  }

  @override
  Future<void> clearAll() async => _db.clearAll();

  // ---------------------------------------------------------------------------
  // 🔹 Folder / Group Helpers (FIXED: use snake_case column names)
  // ---------------------------------------------------------------------------

  @override
  Future<List<PasswordEntry>> childrenOf(int folderId) async {
    final db = _db.db;
    final rows = await db.query(
      table,
      where: 'parent_id = ?',
      whereArgs: [folderId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => PasswordEntry.fromMap(r)).toList();
  }

  @override
  Future<void> moveToFolder(int entryId, int folderId) async {
    final db = _db.db;
    await db.update(
      table,
      {'parent_id': folderId},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  @override
  Future<int> deleteWithChildren(int folderId) async {
    final db = _db.db;

    // Find all direct children first
    final children = await db.query('passwords', where: 'parent_id = ?', whereArgs: [folderId]);

    int totalDeleted = 0;

    // For each child, if it's a folder — delete its children recursively
    for (final child in children) {
      final isFolder = (child['is_folder'] ?? 0) == 1;
      final id = child['id'] as int;
      if (isFolder) {
        totalDeleted += await deleteWithChildren(id);
      } else {
        totalDeleted += await db.delete('passwords', where: 'id = ?', whereArgs: [id]);
      }
    }

    // Finally, delete the parent folder itself
    totalDeleted += await db.delete('passwords', where: 'id = ?', whereArgs: [folderId]);
    return totalDeleted;
  }



  @override
  Future<void> update(PasswordEntry entry) async {
    final db = _db.db;
    // Use toMap (already uses snake_case)
    final map = Map<String, dynamic>.from(entry.toMap());
    // Avoid attempting to set id in the update map (SQLite will ignore but keep map clean)
    map.remove('id');
    await db.update(
      table,
      map,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }
}
