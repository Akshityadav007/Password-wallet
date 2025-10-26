import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'dart:typed_data';
import 'package:password_wallet/domain/interfaces/backup_service.dart';
import 'package:password_wallet/presentation/utils/safe_snack.dart';
import 'package:password_wallet/services/lock_service.dart';
import 'package:password_wallet/services/biometric_service.dart';
import 'package:password_wallet/services/session_service.dart';
import 'package:password_wallet/services/auth_service.dart';
import 'package:password_wallet/services/theme_service.dart';
import 'package:provider/provider.dart';

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
  bool _darkMode = false;
  bool _biometricEnabled = false;

  // void safeSnack(String message) {
  //   if (!mounted) return;
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(SnackBar(content: Text(message)));
  // }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _darkMode = context.read<ThemeService>().isDarkMode;
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

  Future<Uint8List?> _getActiveMasterKeyOrPrompt() async {
    Uint8List? key = _session.masterKey;
    if (key != null) return key;

    final masterPassword = await _askForMasterPassword(context);
    if (masterPassword == null || masterPassword.isEmpty) return null;

    final derived = await _authService.verifyMasterPassword(masterPassword);
    if (derived == null) {
      if (!mounted) return null;
      safeSnack(context, 'Invalid master password');
      return null;
    }
    return derived;
  }

  Future<void> _exportBackup() async {
    try {
      final key = await _getActiveMasterKeyOrPrompt();
      if (key == null) return;

      if (!mounted) return;
      safeSnack(context, 'Exporting encrypted backup...');

      final path = await _backupService.exportEncryptedBackup(masterKey: key);

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
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path!;
    final masterPassword = await _askForMasterPassword(context);
    if (masterPassword == null || masterPassword.isEmpty) {
      if (!mounted) return;
      safeSnack(context, 'Import cancelled — password required');
      return;
    }

    safeSnack(context, 'Verifying and decrypting backup...');

    final importedCount = await _backupService.importEncryptedBackup(
      filePath: filePath,
      masterPassword: masterPassword,
    );

    if (!mounted) return;
    safeSnack(context, 'Imported $importedCount passwords successfully!');
  } catch (e) {
    if (!mounted) return;
    safeSnack(context, 'Import failed: $e');
  }
}

  Future<void> _onBiometricToggle(bool value) async {
    if (value) {
      final canUse = await _biometricService.canUseBiometrics();
      if (!canUse) {
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
        safeSnack(context, 'Biometric enrollment failed or cancelled');
        return;
      }
    }

    await _lockService.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
    safeSnack(context, value ? 'Biometric enabled' : 'Biometric disabled');
  }

  Future<String?> _askForMasterPassword(BuildContext context) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Enter Master Password',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: TextField(
            controller: controller,
            obscureText: true,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Master password',
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
              onPressed: () => Navigator.pop(context, controller.text),
              label: const Text('Confirm'),
            ),
          ],
        );
      },
    );
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
      body: ListView(
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
                  onChanged: (val) => setState(() => _selectedTimeout = val),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: Text(
                    'Enable Biometric Login',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  value: _biometricEnabled,
                  activeColor: colorScheme.primary,
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

          _buildSectionTitle('Appearance', Icons.palette_rounded),
          _buildCard(
            SwitchListTile(
              title: Text(
                'Dark Mode',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                _darkMode
                    ? 'Currently using dark theme'
                    : 'Currently using light theme',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              value: _darkMode,
              activeColor: colorScheme.primary,
              onChanged: (v) async {
                setState(() => _darkMode = v);
                final themeService = context.read<ThemeService>();
                await themeService.toggleTheme(v);
              },
              secondary: Icon(
                _darkMode ? Icons.dark_mode : Icons.light_mode,
                color: colorScheme.primary,
              ),
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
    );
  }
}
