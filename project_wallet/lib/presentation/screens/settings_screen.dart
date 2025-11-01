import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:password_wallet/domain/interfaces/backup_service.dart';
import 'package:password_wallet/presentation/utils/safe_snack.dart';
import 'package:password_wallet/services/lock_service.dart';
import 'package:password_wallet/services/biometric_service.dart';
import 'package:password_wallet/services/session_service.dart';
import 'package:password_wallet/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lockService = GetIt.I<LockService>();
  final _backupService = GetIt.I<BackupService>();
  final _biometricService = GetIt.I<BiometricService>();
  final _authService = GetIt.I<AuthService>();
  final _session = GetIt.I<SessionService>();

  final List<Duration> _timeoutOptions = const [
    Duration(seconds: 0),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  Duration? _selectedTimeout;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _selectedTimeout = _timeoutOptions.contains(_lockService.lockTimeout)
        ? _lockService.lockTimeout
        : _timeoutOptions.first;

    _biometricEnabled = await _lockService.isBiometricEnabled();
    if (mounted) setState(() {});
  }

  Future<void> _saveSecurityPrefs() async {
    await _lockService.updatePreferences(timeout: _selectedTimeout);
    if (!mounted) return;
    safeSnack(context, 'Security preferences updated');
  }

  Future<void> _exportBackup() async {
    try {
      // Always ask for the master password — ensures portability
      final masterPassword = await _askForMasterPassword(
        context: context,
        note:
            'Enter you master password to encrypt the backup file. You will need this password to restore the backup later.',
      );

      if (masterPassword == null || masterPassword.isEmpty) {
        if (!mounted) return;
        safeSnack(context, 'Export cancelled — password required');
        return;
      }

      if (!mounted) return;
      safeSnack(context, 'Exporting encrypted backup...');

      final path = await _backupService.exportEncryptedBackup(
        masterPassword: masterPassword,
      );

      if (!mounted) return;
      safeSnack(context, 'Backup saved at: $path');
    } catch (e) {
      if (!mounted) return;
      safeSnack(context, 'Backup failed: $e');
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pwbackup'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.single.path!;

      if (!mounted) return;

      // two-step password flow (old + new)
      final passwords = await _askForTwoPasswords(context: context);

      if (passwords == null) {
        if (!mounted) return;
        safeSnack(context, 'Import cancelled.');
        return;
      }

      final oldPassword = passwords['backupPassword']!;
      final newPassword = passwords['devicePassword']!;
 
      if (!mounted) return;
      safeSnack(context, 'Verifying and decrypting backup...');

      final importedCount = await _backupService.importEncryptedBackup(
        filePath: filePath,
        oldMasterPassword: oldPassword,
        newMasterPassword: newPassword,
      );

      if (!mounted) return;
      safeSnack(context, 'Imported $importedCount passwords successfully!');
      _session.notifyVaultUpdated();
    } catch (e) {
      if (!mounted) return;
      safeSnack(context, 'Import failed: $e');
    }
  }

  Future<void> _onBiometricToggle(bool value) async {
    if (value) {
      final canUse = await _biometricService.canUseBiometrics();
      if (!canUse) {
        if (!mounted) return;
        safeSnack(
          context,
          'Biometric authentication not supported on this device',
        );
        return;
      }

      final ok = await _biometricService.authenticateWithBiometrics(
        reason: 'Confirm biometric to enable unlock',
      );
      if (!ok) {
        if (!mounted) return;
        safeSnack(context, 'Biometric enrollment failed or cancelled');
        return;
      }
    }

    await _lockService.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
    safeSnack(context, value ? 'Biometric enabled' : 'Biometric disabled');
  }

  Future<String?> _askForMasterPassword({
    required BuildContext context,
    String title = 'Enter Master Password',
    String? note,
  }) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    note,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Master password',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) Navigator.pop(ctx, value.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) Navigator.pop(ctx, text);
                },
                label: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  Future<Map<String, String>?> _askForTwoPasswords({
    required BuildContext context,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final oldController = TextEditingController();
    final newController = TextEditingController();
    int step = 0;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final isOldStep = step == 0;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(isOldStep ? 0.1 : -0.1, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: AlertDialog(
                key: ValueKey(step),
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  isOldStep
                      ? 'Step 1 of 2 — Backup Password'
                      : 'Step 2 of 2 — Device Password',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOldStep
                          ? 'Enter the password you used on the previous device to decrypt this backup file.'
                          : 'Enter your current device master password. Imported entries will be re-encrypted using this password.',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: isOldStep ? oldController : newController,
                      obscureText: true,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (isOldStep)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: Icon(
                      isOldStep ? Icons.arrow_forward : Icons.check,
                      size: 18,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    onPressed: () {
                      if (isOldStep) {
                        if (oldController.text.trim().isEmpty) {
                          return;
                        }
                        setState(() => step = 1);
                      } else {
                        if (newController.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(ctx, {
                          'backupPassword': oldController.text,
                          'devicePassword': newController.text,
                        });
                      }
                    },
                    label: Text(isOldStep ? 'Next' : 'Confirm'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _logout() async {
    final lockService = GetIt.I<LockService>();
    await _authService.clearSession();
    lockService.disableAutoPrompt();

    final hasPassword = await _authService.hasMasterPassword();
    if (!mounted) return;

    if (hasPassword) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/master-password', (r) => false);
    }
  }

  Future<void> _confirmLogout() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout?', style: TextStyle(color: colorScheme.onSurface)),
        content: Text(
          'Are you sure you want to log out? Your vault will be locked until you log in again.',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colorScheme.primary)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            label: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _logout();
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark
            ? BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              )
            : BorderSide.none,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
      body: Column(
        children: [
          // Main scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('Security Settings', Icons.security_rounded),
                _buildCard(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<Duration>(
                        initialValue: _timeoutOptions.contains(_selectedTimeout)
                            ? _selectedTimeout
                            : _timeoutOptions.first,
                        style: TextStyle(color: colorScheme.onSurface),
                        dropdownColor: colorScheme.surface,
                        decoration: InputDecoration(
                          labelText: 'Auto-lock Timeout',
                          labelStyle: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        items: _timeoutOptions.map((d) {
                          final label = d == Duration.zero
                              ? 'Never'
                              : '${d.inMinutes == 0 ? d.inSeconds : d.inMinutes} '
                                    '${d.inMinutes == 0 ? 'seconds' : 'minutes'}';
                          return DropdownMenuItem(
                            value: d,
                            child: Text(
                              label,
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedTimeout = val),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: Text(
                          'Enable Biometric Login',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        value: _biometricEnabled,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (v) => _onBiometricToggle(v),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save Preferences'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _saveSecurityPrefs,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildSectionTitle('Backup & Restore', Icons.cloud_rounded),
                _buildCard(
                  Column(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Export Encrypted Backup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _exportBackup,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Import Backup'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _importBackup,
                      ),
                    ],
                  ),
                ),

                _buildSectionTitle('Account', Icons.person_rounded),
                _buildCard(
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _confirmLogout,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer always fixed at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text(
              'Developed by Akshit Yadav',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: theme.brightness == Brightness.dark
                    ? colorScheme.onSurface.withValues(alpha: 0.6)
                    : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
