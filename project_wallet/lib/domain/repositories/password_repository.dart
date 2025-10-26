// domain/repositories/password_repository.dart

import '../../data/models/password_entry.dart';

abstract class PasswordRepository {
  // Normal CRUD operations for app use
  Future<int> add(PasswordEntry entry);
  Future<List<PasswordEntry>> all();
  Future<int> remove(int id);

  // Backup/restore-specific operations
  Future<List<Map<String, dynamic>>> getAllPasswords();
  Future<void> restoreFromJson(List<dynamic> jsonList);
  Future<void> clearAll();

  Future<void> update(PasswordEntry entry); // used for edits, toggling folder/pin, assigning parent
  Future<void> moveToFolder(int entryId, int folderId);
  Future<List<PasswordEntry>> childrenOf(int folderId);
  Future<int> deleteWithChildren(int id); // deletes a folder and all its children

}
