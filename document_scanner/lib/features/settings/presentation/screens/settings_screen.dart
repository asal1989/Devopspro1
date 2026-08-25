import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';

/// Scanner defaults, appearance, storage, account, and about — grouped
/// the way a production scanner app organizes settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.lg),

        const _SettingsSectionLabel('Scanner'),
        _SettingsCard(children: [
          SwitchListTile(
            title: const Text('Auto Capture'),
            subtitle: const Text('Capture automatically once a document is detected'),
            value: settings.autoCapture,
            onChanged: settings.toggleAutoCapture,
          ),
          ListTile(
            title: const Text('Default Filter'),
            trailing: Text(settings.defaultFilter, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            title: const Text('Default PDF Quality'),
            trailing: Text(settings.defaultPdfQuality, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SwitchListTile(
            title: const Text('Auto OCR'),
            subtitle: const Text('Run text recognition right after scanning'),
            value: settings.autoOcr,
            onChanged: settings.toggleAutoOcr,
          ),
          SwitchListTile(
            title: const Text('Save Original Image'),
            subtitle: const Text('Keep the unedited capture for reprocessing'),
            value: settings.saveOriginalImage,
            onChanged: settings.toggleSaveOriginal,
          ),
        ]),

        const SizedBox(height: AppSpacing.lg),
        const _SettingsSectionLabel('Appearance'),
        _SettingsCard(children: [
          RadioListTile<ThemeMode>(
            title: const Text('Light Mode'),
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (v) => settings.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark Mode'),
            value: ThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (v) => settings.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (v) => settings.setThemeMode(v!),
          ),
        ]),

        const SizedBox(height: AppSpacing.lg),
        const _SettingsSectionLabel('Storage'),
        _SettingsCard(children: [
          const ListTile(title: Text('Storage Used'), trailing: Text('42.3 MB', style: TextStyle(fontWeight: FontWeight.w600))),
          ListTile(
            title: const Text('Clear Cache'),
            trailing: TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared'))),
              child: const Text('Clear'),
            ),
          ),
          ListTile(
            title: const Text('Manage Documents'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {},
          ),
        ]),

        const SizedBox(height: AppSpacing.lg),
        const _SettingsSectionLabel('Account'),
        _SettingsCard(children: [
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(settings.isSignedIn ? (settings.userEmail ?? 'Signed in') : 'Not signed in'),
            subtitle: Text(settings.isSignedIn ? 'Tap to view profile' : 'Sign in for cloud backup'),
            trailing: settings.isSignedIn ? null : const Icon(Icons.chevron_right_rounded),
            onTap: settings.isSignedIn ? null : () => context.push(AppRoutes.signIn),
          ),
          SwitchListTile(
            title: const Text('Cloud Sync'),
            subtitle: Text(settings.isSignedIn ? 'Keep documents backed up' : 'Sign in to enable'),
            value: settings.cloudSyncEnabled,
            onChanged: settings.isSignedIn ? settings.toggleCloudSync : null,
          ),
          if (settings.isSignedIn)
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign Out'),
              onTap: settings.signOut,
            ),
        ]),

        const SizedBox(height: AppSpacing.lg),
        const _SettingsSectionLabel('About'),
        _SettingsCard(children: const [
          ListTile(title: Text('Privacy Policy'), trailing: Icon(Icons.chevron_right_rounded)),
          ListTile(title: Text('Terms of Service'), trailing: Icon(Icons.chevron_right_rounded)),
          ListTile(title: Text('Version'), trailing: Text('0.1.0', style: TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ],
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String label;
  const _SettingsSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).extension<AppSemanticColors>()?.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
      child: Text(label.toUpperCase(), style: TextStyle(color: secondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: _withDividers(children)),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) result.add(const Divider(height: 1));
    }
    return result;
  }
}
