import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/password_entry.dart';

class DbService {
  static const _dbName = 'pw_wallet.db';
  static const _table = 'passwords';
  Database? _db;

  Future<void> open() async {
    if (_db != null) return;

    final path = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, v) async => await _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migration from v1 → v2
          await db.execute('ALTER TABLE $_table ADD COLUMN parent_id INTEGER;');
          await db.execute('ALTER TABLE $_table ADD COLUMN is_folder INTEGER DEFAULT 0;');
          await db.execute('ALTER TABLE $_table ADD COLUMN pinned INTEGER DEFAULT 0;');
        }
        if (oldVersion < 3) {
          // Migration from v2 → v3 (rename columns for consistency)
          await _migrateColumnNames(db);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        username TEXT,
        ciphertext TEXT,
        nonce TEXT,
        created_at TEXT,
        parent_id INTEGER,
        is_folder INTEGER DEFAULT 0,
        pinned INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _migrateColumnNames(Database db) async {
    // Check if legacy columns exist; if so, migrate data
    final tables = await db.rawQuery('PRAGMA table_info($_table)');
    final hasOld = tables.any((r) => r['name'] == 'createdAt');
    if (hasOld) {
      await db.execute('''
        ALTER TABLE $_table RENAME TO ${_table}_old;
      ''');
      await _createSchema(db);
      await db.execute('''
        INSERT INTO $_table (id, title, username, ciphertext, nonce, created_at, parent_id, is_folder, pinned)
        SELECT id, title, username, ciphertext, nonce, createdAt, parentId, isFolder, pinned FROM ${_table}_old;
      ''');
      await db.execute('DROP TABLE ${_table}_old;');
    }
  }

  Database get db => _db!;

  // -----------------------------------------------------
  
  // Basic CRUD
  // -----------------------------------------------------
    Future<int> insert(PasswordEntry e) async {
      await open();
      final map = Map<String, dynamic>.from(e.toMap());
      if (map['id'] == null) map.remove('id');
      return await _db!.insert(_table, map);
    }


  Future<List<PasswordEntry>> all() async {
    await open();
    final rows = await _db!.query(_table, orderBy: 'created_at DESC');
    return rows.map((r) => PasswordEntry.fromMap(r)).toList();
  }

  Future<int> delete(int id) async {
    await open();
    return await _db!.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    await open();
    await _db!.delete(_table);
  }

  Future<void> insertRaw(Map<String, dynamic> map) async {
    await open();
    await _db!.insert(_table, map);
  }

  Future<List<Map<String, dynamic>>> allAsMaps() async {
    await open();
    final rows = await _db!.query(_table, orderBy: 'created_at DESC');
    return rows;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
