// lib/presentation/widgets/password_tile.dart
import 'package:flutter/material.dart';
import 'package:password_wallet/data/models/password_entry.dart';
import 'package:password_wallet/presentation/utils/icon_mapper.dart';
import 'package:password_wallet/presentation/utils/safe_snack.dart';

typedef AddToFolderCallback = Future<void> Function(int folderId);
typedef RevealChildCallback = Future<void> Function(PasswordEntry child);
typedef ChildTapCallback = void Function(PasswordEntry child);
typedef ChildLongPressCallback = void Function(PasswordEntry child);

class PasswordTile extends StatefulWidget {
  final PasswordEntry entry;
  final bool isSelected;
  final bool expanded;
  final List<PasswordEntry> children;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleExpand;
  final AddToFolderCallback? onAddToFolder;
  final RevealChildCallback? onRevealChild;
  final ChildTapCallback? onChildTap;
  final ChildLongPressCallback? onChildLongPress;

  const PasswordTile({
    super.key,
    required this.entry,
    this.isSelected = false,
    this.expanded = false,
    this.children = const [],
    this.onTap,
    this.onLongPress,
    this.onToggleExpand,
    this.onAddToFolder,
    this.onRevealChild,
    this.onChildTap,
    this.onChildLongPress,
  });

  @override
  State<PasswordTile> createState() => _PasswordTileState();
}

class _PasswordTileState extends State<PasswordTile> {
  Future<void> _handleAddTap() async {
    final id = widget.entry.id;
    if (id == null || widget.onAddToFolder == null) return;

    // Wait for UI stability before opening dialog
    await Future.delayed(const Duration(milliseconds: 60));

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await widget.onAddToFolder!(id);
      } catch (e) {
        if (!mounted) return;
        safeSnack(context, 'Failed to open add dialog.', isError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final entry = widget.entry;
    final icon = detectIconForTitle(entry.title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                  : (isDark ? colorScheme.surface : theme.cardColor),
              borderRadius: BorderRadius.circular(12),
              border: widget.isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    )
                  : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                  child: Icon(icon, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (entry.isFolder)
                  IconButton(
                    icon: Icon(
                      widget.expanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: widget.onToggleExpand,
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.visibility_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    onPressed: widget.onTap,
                    tooltip: 'Reveal',
                  ),
              ],
            ),
          ),
        ),

        // Children list for folders
        if (entry.isFolder && widget.expanded)
          Padding(
            padding:
                const EdgeInsets.only(left: 56, right: 8, top: 14, bottom: 12),
            child: Stack(
              children: [
                // Children list
                Padding(
                  padding: const EdgeInsets.only(top: 14, left: 24, right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.children.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colorScheme.surface.withValues(alpha: 0.3)
                                : colorScheme.surface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.onSurface.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            'No items yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: widget.children.map((child) {
                            return GestureDetector(
                              onTap: () => widget.onChildTap?.call(child),
                              onLongPress: () =>
                                  widget.onChildLongPress?.call(child),
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colorScheme.surface.withValues(alpha: 0.5)
                                      : colorScheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline,
                                        size: 20,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.5)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        child.title,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.visibility,
                                          size: 20,
                                          color: colorScheme.primary),
                                      tooltip: 'Reveal',
                                      onPressed: () =>
                                          widget.onRevealChild?.call(child),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                // Floating Add Button
                Align(
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: const Offset(-32, -8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _handleAddTap,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                    alpha: isDark ? 0.3 : 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add,
                            color:
                                isDark ? Colors.black : Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
