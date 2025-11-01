// password_repository_impl.dart
import 'package:password_wallet/domain/repositories/password_repository.dart';
import 'package:password_wallet/data/sources/local/db_service.dart';
import 'package:password_wallet/data/models/password_entry.dart';

class PasswordRepositoryImpl implements PasswordRepository {
  final DbService _db;
  PasswordRepositoryImpl(this._db);

  static const table = 'passwords';

  // -------------------------------------------------
  // 🔹 Basic CRUD
  // -------------------------------------------------
  @override
  Future<int> add(PasswordEntry entry) async {
    await _db.open();
    final map = Map<String, dynamic>.from(entry.toMap());
    map.remove('id'); // let SQLite assign
    return await _db.db.insert(table, map);
  }

  @override
  Future<List<PasswordEntry>> getAll() async {
    await _db.open();
    final maps = await _db.allAsMaps();
    return maps.map(PasswordEntry.fromMap).toList();
  }

  @override
  Future<void> update(PasswordEntry entry) async {
    await _db.open();
    final map = Map<String, dynamic>.from(entry.toMap());
    map.remove('id');
    await _db.db.update(
      table,
      map,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  @override
  Future<int> remove(int id) async {
    await _db.open();
    return await _db.db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll() async => _db.clearAll();

  // -------------------------------------------------
  // 🔹 Backup / Restore
  // -------------------------------------------------
  @override
  Future<void> restoreFromJson(List<dynamic> jsonList) async {
    await _db.open();
    await _db.clearAll();

    for (final item in jsonList) {
      final map = Map<String, dynamic>.from(item as Map);

      // Normalize key names and ensure valid ints
      if (map.containsKey('isFolder')) {
        map['is_folder'] = (map['isFolder'] == true || map['isFolder'] == 1) ? 1 : 0;
        map.remove('isFolder');
      } else if (map.containsKey('is_folder')) {
        map['is_folder'] = (map['is_folder'] == true || map['is_folder'] == 1) ? 1 : 0;
      }

      if (map.containsKey('parentId')) {
        map['parent_id'] = map['parentId'];
        map.remove('parentId');
      }

      map['is_folder'] = (map['is_folder'] ?? 0).toInt();
      map['pinned'] = (map['pinned'] ?? 0).toInt();

      await _db.insertRaw(map);
    }
  }

  // -------------------------------------------------
  // 🔹 Folder / Group Helpers
  // -------------------------------------------------
  @override
  Future<List<PasswordEntry>> childrenOf(int folderId) async {
    await _db.open();
    final rows = await _db.db.query(
      table,
      where: 'parent_id = ?',
      whereArgs: [folderId],
      orderBy: 'created_at DESC',
    );
    return rows.map(PasswordEntry.fromMap).toList();
  }

  @override
  Future<void> moveToFolder(int entryId, int folderId) async {
    await _db.open();
    await _db.db.update(
      table,
      {'parent_id': folderId},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  @override
  Future<int> deleteWithChildren(int folderId) async {
    await _db.open();
    final children = await _db.db.query(table, where: 'parent_id = ?', whereArgs: [folderId]);
    int totalDeleted = 0;

    for (final child in children) {
      final isFolder = (child['is_folder'] ?? 0) == 1;
      final id = child['id'] as int;
      totalDeleted += isFolder
          ? await deleteWithChildren(id)
          : await _db.db.delete(table, where: 'id = ?', whereArgs: [id]);
    }

    totalDeleted += await _db.db.delete(table, where: 'id = ?', whereArgs: [folderId]);
    return totalDeleted;
  }
}
