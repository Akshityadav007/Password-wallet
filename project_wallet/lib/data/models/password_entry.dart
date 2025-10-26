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
        parentId: parentId,
        isFolder: isFolder ?? this.isFolder,
        pinned: pinned ?? this.pinned,
      );

  factory PasswordEntry.fromMap(Map<String, dynamic> m) => PasswordEntry(
        id: m['id'] as int?,
        title: m['title'] as String,
        username: m['username'] as String,
        ciphertext: m['ciphertext'] as String,
        nonce: m['nonce'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        parentId: m['parent_id'] as int?,
        isFolder: (m['is_folder'] as int? ?? 0) == 1,
        pinned: (m['pinned'] as int? ?? 0) == 1,
      );

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
