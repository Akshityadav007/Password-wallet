// data/models/password_entry.dart

class PasswordEntry {
  final int? id;
  final String title;
  final String username;
  final String ciphertext;
  final String nonce;
  final DateTime createdAt;
  final int? parentId; 
  final bool isFolder;
  final bool pinned;

  PasswordEntry({
    this.id,
    required this.title,
    required this.username,
    required this.ciphertext,
    required this.nonce,
    required this.createdAt,
    this.parentId,
    this.isFolder = false,
    this.pinned = false,
  });

  PasswordEntry copyWith({
    int? id,
    String? title,
    String? username,
    String? ciphertext,
    String? nonce,
    DateTime? createdAt,
    int? parentId,
    bool? isFolder,
    bool? pinned,
  }) =>
      PasswordEntry(
        id: id ?? this.id,
        title: title ?? this.title,
        username: username ?? this.username,
        ciphertext: ciphertext ?? this.ciphertext,
        nonce: nonce ?? this.nonce,
        createdAt: createdAt ?? this.createdAt,
        parentId: parentId ?? this.parentId,
        isFolder: isFolder ?? this.isFolder,
        pinned: pinned ?? this.pinned,
      );

    factory PasswordEntry.fromMap(Map<String, dynamic> map) {
      bool parseBool(dynamic v) {
        if (v is bool) return v;
        if (v is int) return v == 1;
        if (v is String) return v == '1' || v.toLowerCase() == 'true';
        return false;
      }

      return PasswordEntry(
        id: map['id'] as int?,
        title: map['title'] ?? '',
        username: map['username'] ?? '',
        ciphertext: map['ciphertext'] ?? '',
        nonce: map['nonce'] ?? '',
        createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
        parentId: map['parent_id'] is int ? map['parent_id'] : int.tryParse(map['parent_id']?.toString() ?? ''),
        isFolder: parseBool(map['is_folder']),
        pinned: parseBool(map['pinned']),
      );
    }


  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'username': username,
        'ciphertext': ciphertext,
        'nonce': nonce,
        'created_at': createdAt.toIso8601String(),
        'parent_id': parentId,
        'is_folder': isFolder ? 1 : 0,
        'pinned': pinned ? 1 : 0,
      };
}
