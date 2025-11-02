// lib/presentation/screens/home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/domain/interfaces/crypto_service.dart';
import 'package:password_wallet/domain/repositories/password_repository.dart';
import 'package:password_wallet/data/models/password_entry.dart';
import 'package:password_wallet/presentation/screens/settings_screen.dart';
import 'package:password_wallet/presentation/widgets/password_tile.dart';
import 'package:password_wallet/services/auth_service.dart';
import 'package:password_wallet/services/session_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = GetIt.I<AuthService>();
  final _cryptoService = GetIt.I<CryptoService>();
  final _passwordRepo = GetIt.I<PasswordRepository>();

  int _selectedIndex = 0;
  Uint8List? _masterKey;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  List<PasswordEntry> _entries = [];
  Map<int, List<PasswordEntry>> _childrenByFolder = {};
  Map<int, bool> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeVault());

    // Listen for vault refresh requests
    GetIt.I<SessionService>().vaultNeedsRefresh.addListener(() async {
      if (mounted) await _loadPasswords();
    });
  }

  // -------------------------
  // Initialization / Vault
  // -------------------------
  Future<void> _initializeVault() async {
  final session = GetIt.I<SessionService>();

  // If a key is already in session (biometric or login), use it directly
  if (session.masterKey != null) {
    _masterKey = session.masterKey;
    await _loadPasswords();
    return;
  }

  // Only if no session or key at all, ask for password
  final password = await _askForMasterPassword(context);
  if (password == null || password.isEmpty) return;

  final derived = await _authService.verifyMasterPassword(password);
  if (derived == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid master password')),
    );
    return;
  }

  _masterKey = derived;
  session.setMasterKey(derived);
  await _loadPasswords();
}


  // -------------------------
  // Load + organize entries
  // -------------------------
  Future<void> _loadPasswords() async {
    final all = await _passwordRepo.getAll();
    if (!mounted) return;

    // Build children map (clear existing and rebuild)
    _childrenByFolder = {};
    for (final e in all.where((e) => e.parentId != null)) {
      _childrenByFolder.putIfAbsent(e.parentId!, () => []).add(e);
    }

    // Sorting: pinned > folders > singles (latest first)
    final pinned = all.where((e) => e.pinned && e.parentId == null).toList();
    final folders = all.where((e) => e.isFolder && e.parentId == null).toList();
    final singles = all.where((e) => !e.isFolder && e.parentId == null && !e.pinned).toList();

    for (final list in [pinned, folders, singles]) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    setState(() {
      _entries = [...pinned, ...folders, ...singles];
      _selectionMode = false;
      _selectedIds.clear();
      _expandedFolders = {}; // collapse all on reload for stability
    });
  }

  Future<void> _toggleFolder(int folderId) async {
    final expanded = _expandedFolders[folderId] ?? false;
    if (!expanded) {
      final children = await _passwordRepo.childrenOf(folderId);
      // ensure children stored in in-memory map so PasswordTile receives List<PasswordEntry>
      setState(() {
        _childrenByFolder[folderId] = children;
        _expandedFolders[folderId] = true;
      });
    } else {
      setState(() => _expandedFolders[folderId] = false);
    }
  }

  // -------------------------
  // Add / Edit / Convert / Delete
  // -------------------------
  Future<void> _addPasswordDialog({int? parentId}) async {
    final titleController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();
final result = await showDialog<bool>(
  context: context,
  builder: (ctx) {
    final colorScheme = Theme.of(ctx).colorScheme;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      backgroundColor: isDark
          ? colorScheme.surface.withValues(alpha: 0.95)
          : colorScheme.surface,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.15),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.lock_outline, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Add New Password',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(thickness: 0.6, height: 20),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              prefixIcon: const Icon(Icons.title_outlined),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.15 : 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: userController,
            decoration: InputDecoration(
              labelText: 'Username / Email',
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.15 : 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.15 : 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  },
);


    if (result == true && _masterKey != null) {
      final title = titleController.text.trim();
      final username = userController.text.trim();
      final plainPassword = passController.text;

      if (title.isEmpty || plainPassword.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and password are required')));
        return;
      }

      final encrypted = await _cryptoService.encrypt(utf8.encode(plainPassword), _masterKey!);
      final entry = PasswordEntry(
        title: title,
        username: username,
        ciphertext: base64Encode(encrypted['ciphertext']!),
        nonce: base64Encode(encrypted['nonce']!),
        createdAt: DateTime.now(),
        parentId: parentId,
      );

      await _passwordRepo.add(entry);
      await _loadPasswords();
    }
  }

  Future<void> _editEntry(PasswordEntry entry) async {
    final titleCtrl = TextEditingController(text: entry.title);
    final isFolder = entry.isFolder;
    final userCtrl = TextEditingController(text: entry.username);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFolder ? 'Edit Folder' : 'Edit Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            if (!isFolder) ...[
              const SizedBox(height: 10),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username')),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    final updated = entry.copyWith(
      title: titleCtrl.text.trim(),
      username: isFolder ? '' : userCtrl.text.trim(),
    );

    await _passwordRepo.update(updated);
    await _loadPasswords();
  }

  Future<void> _convertToFolder(PasswordEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Folder'),
        content: Text('Create a new folder and move "${entry.title}" under it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed != true) return;

    final nameCtrl = TextEditingController(text: entry.title);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Folder Name'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;

    final folderName = nameCtrl.text.trim();

    // Busy 
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    int? createdFolderId;
    try {
      final folderEntry = PasswordEntry(
        id: null,
        title: folderName,
        username: '',
        ciphertext: '',
        nonce: '',
        createdAt: DateTime.now(),
        parentId: null,
        isFolder: true,
        pinned: false,
      );

      createdFolderId = await _passwordRepo.add(folderEntry);

      if (entry.id == null) {
        throw Exception('Original entry is not persisted (missing id).');
      }
      await _passwordRepo.moveToFolder(entry.id!, createdFolderId);

      await _loadPasswords();
      if (mounted) {
        Navigator.pop(context); // dismiss progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created folder "$folderName" and moved "${entry.title}" inside')),
        );
      }
    } catch (err) {
      if (createdFolderId != null) {
        try {
          await _passwordRepo.remove(createdFolderId);
        } catch (_) {}
      }
      if (mounted) {
        Navigator.pop(context); // dismiss progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert to folder: ${err.toString()}')),
        );
      }
    }
  }

  // -------------------------
  // Reveal / Copy actions
  // -------------------------
Future<void> _revealPassword(BuildContext context, PasswordEntry entry) async {
  if (_masterKey == null) return;
  try {
    final decrypted = await _cryptoService.decrypt(
      base64Decode(entry.ciphertext),
      base64Decode(entry.nonce),
      _masterKey!,
    );
    final password = utf8.decode(decrypted);

    bool showPassword = false;

    await showDialog(
      context: mounted ? context: throw Exception('Context not mounted'),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark
                ? colorScheme.surface.withValues(alpha: 0.95)
                : colorScheme.surface,
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),

            title: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.lock_open_rounded, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(thickness: 0.6, height: 20),
                  Text(
                    'Username / Email',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            entry.username.isEmpty ? '—' : entry.username,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copy Username',
                          color: colorScheme.primary,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: entry.username));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Username copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Password',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            showPassword ? password : '•' * password.length,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                          ),
                          color: colorScheme.primary,
                          tooltip: showPassword ? 'Hide Password' : 'Show Password',
                          onPressed: () => setState(() => showPassword = !showPassword),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          color: colorScheme.primary,
                          tooltip: 'Copy Password',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: password));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurface.withValues(alpha: 0.7),
                    textStyle: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  } catch (_) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to decrypt password')),
    );
  }
}


  // -------------------------
  // Selection logic (folder-aware)
  // -------------------------
  void _enterSelectionMode(int id, {bool includeChildrenIfFolder = true}) {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(id);

      if (includeChildrenIfFolder) {
        final entry = _findEntryById(id);
        if (entry != null && entry.isFolder) {
          final kids = _childrenByFolder[id] ?? [];
          for (final c in kids) {
            if (c.id != null) _selectedIds.add(c.id!);
          }
        }
      }
    });
  }

  PasswordEntry? _findEntryById(int id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      // look among children
      for (final list in _childrenByFolder.values) {
        try {
          return list.firstWhere((c) => c.id == id);
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _confirmAndDeleteSelected() async {
    if (_selectedIds.isEmpty) return;

    // Prepare the actual entries
    final entriesToDelete = _selectedIds.map(_findEntryById).whereType<PasswordEntry>().toList();

    int folderCount = 0;
    int totalChildCount = 0;

    for (final e in entriesToDelete) {
      if (e.isFolder) {
        folderCount++;
        final children = _childrenByFolder[e.id] ?? [];
        totalChildCount += children.length;
      }
    }

    final entryCount = entriesToDelete.where((e) => !e.isFolder).length;

    final description = folderCount > 0
        ? 'This will permanently delete $folderCount folder${folderCount > 1 ? "s" : ""} '
            'and $totalChildCount entr${totalChildCount == 1 ? "y" : "ies"} inside them, '
            'along with ${entryCount > 0 ? "$entryCount additional entr${entryCount > 1 ? "ies" : "y"}" : "no separate entries"}.'
        : 'This will permanently delete ${entriesToDelete.length} entr${entriesToDelete.length > 1 ? "ies" : "y"}.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Items?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 10),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Perform actual deletion
    int deletedCount = 0;

    for (final entry in entriesToDelete) {
      if (entry.isFolder) {
        deletedCount += await _passwordRepo.deleteWithChildren(entry.id!);
      } else {
        await _passwordRepo.remove(entry.id!);
        deletedCount++;
      }
    }

    await _loadPasswords();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $deletedCount entr${deletedCount == 1 ? "y" : "ies"} successfully',
          ),
        ),
      );
    }
  }

  // -------------------------
  // Helper: ask for master password
  // -------------------------
  Future<String?> _askForMasterPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Master Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter master password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Confirm')),
        ],
      ),
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  // -------------------------
  // Build UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final isVaultTab = _selectedIndex == 0;

    PasswordEntry? singleSelectedEntry() {
      if (_selectedIds.length != 1) return null;
      final id = _selectedIds.first;
      try {
        return _entries.firstWhere((e) => e.id == id);
      } catch (_) {
        try {
          return _childrenByFolder.values.expand((x) => x).firstWhere((c) => c.id == id);
        } catch (_) {
          return null;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _selectionMode ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.12) : null,
        title: _selectionMode ? Text('${_selectedIds.length} selected') : const Text('Password Wallet'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              )
            : null,
      actions: [
  if (_selectionMode)
    Builder(builder: (ctx) {
      final widgets = <Widget>[];

      // When exactly ONE item is selected → show contextual actions
      if (_selectedIds.length == 1) {
        final entry = singleSelectedEntry();

        if (entry != null) {
          // Edit button — always visible for single selection
          widgets.add(
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () async => await _editEntry(entry),
            ),
          );

          // Add New Item — visible only when a FOLDER is selected
          if (entry.isFolder) {
            widgets.add(
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add New Item',
                onPressed: () async => await _addPasswordDialog(parentId: entry.id),
              ),
            );
          }

          // Convert to Folder — visible only for entries (not inside folders)
else {
  final isInsideFolder = entry.parentId != null;
  widgets.add(
    IconButton(
      icon: const Icon(Icons.create_new_folder_outlined),
      tooltip: isInsideFolder
          ? 'Already inside a folder'
          : 'Convert to Folder',
      onPressed: isInsideFolder ? null : () async => await _convertToFolder(entry),
    ),
  );
}

        }
      }

      // Delete button — always visible in selection mode
      widgets.add(
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete selected',
          onPressed: _confirmAndDeleteSelected,
        ),
      );

      return Row(mainAxisSize: MainAxisSize.min, children: widgets);
    }),
],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _entries.isEmpty
              ? const Center(child: Text('No passwords saved'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) {
                    final e = _entries[i];
                    final isSelected = e.id != null && _selectedIds.contains(e.id);
                    final expanded = _expandedFolders[e.id] ?? false;
                    final children = _childrenByFolder[e.id] ?? [];

                    return PasswordTile(
                      entry: e,
                      children: children,
                      expanded: expanded,
                      isSelected: isSelected,
                      // Parent tile tapped:
                      onTap: e.id != null
                          ? () {
                              if (_selectionMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(e.id!);
                                    final kids = _childrenByFolder[e.id] ?? [];
                                    for (final c in kids) {
                                      if (c.id != null) _selectedIds.remove(c.id!);
                                    }
                                  } else {
                                    _selectedIds.add(e.id!);
                                    final kids = _childrenByFolder[e.id] ?? [];
                                    for (final c in kids) {
                                      if (c.id != null) _selectedIds.add(c.id!);
                                    }
                                  }
                                  if (_selectedIds.isEmpty) {_selectionMode = false;}
                                  else {_selectionMode = true;}
                                });
                              } 
                              else if (e.isFolder) {
                                if (_expandedFolders[e.id] == true) {
                                  // If folder is already open → rename it
                                  _editEntry(e);
                                } else {
                                  // Otherwise, expand/collapse
                                  _toggleFolder(e.id!);
                                }
                              }
                              else {
                                _revealPassword(context, e);
                              }
                            }
                          : null,
                      onLongPress: e.id != null
                          ? () {
                              // long-press parent: select folder and children
                              _enterSelectionMode(e.id!, includeChildrenIfFolder: true);
                            }
                          : null,
                      onToggleExpand: () => _toggleFolder(e.id!),
                      onAddToFolder: (folderId) async {
                        await _addPasswordDialog(parentId: folderId);
                      },
                      onRevealChild: (child) async {
                        _revealPassword(context, child);
                      },
                      // child-specific callbacks:
                      onChildTap: (child) async {
                        if (_selectionMode) {
                          setState(() {
                            if (child.id != null && _selectedIds.contains(child.id)) {
                              _selectedIds.remove(child.id!);
                            } else if (child.id != null) {
                              _selectedIds.add(child.id!);
                            }
                            if (_selectedIds.isEmpty) _selectionMode = false;
                          });
                        } else {
                          _revealPassword(context, child);
                        }
                      },
                      onChildLongPress: (child) {
                        if (child.id != null) {
                          // long-pressing a child selects only that child
                          _enterSelectionMode(child.id!, includeChildrenIfFolder: false);
                        }
                      },
                    );
                  },
                ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Vault'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: isVaultTab && !_selectionMode
          ? FloatingActionButton(
              onPressed: () => _addPasswordDialog(),
              tooltip: 'Add Password',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
