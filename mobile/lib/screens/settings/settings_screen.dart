import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Settings screen — theme, language, notification toggles.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String _language = 'English';
  final _languages = ['English', 'Hindi', 'French', 'Spanish'];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ──────────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            trailing: Switch(
              value: themeProvider.isDark,
              activeColor: AppTheme.primary,
              onChanged: (v) => themeProvider.setTheme(
                v ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.brightness_auto,
            title: 'Use System Theme',
            trailing: Switch(
              value: themeProvider.themeMode == ThemeMode.system,
              activeColor: AppTheme.primary,
              onChanged: (v) => themeProvider.setTheme(
                v ? ThemeMode.system : ThemeMode.light,
              ),
            ),
          ),

          // ── Language ────────────────────────────────────────────────────────
          _SectionHeader('Language'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.language_outlined),
              ),
              items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) => setState(() => _language = v!),
            ),
          ),
          const SizedBox(height: 8),

          // ── Notifications ───────────────────────────────────────────────────
          _SectionHeader('Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            trailing: Switch(
              value: _notifications,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ),

          // ── About ───────────────────────────────────────────────────────────
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'App Version',
            trailing: const Text('1.0.0', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {},
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
              letterSpacing: 1.0,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppTheme.textHint) : null),
      onTap: onTap,
    );
  }
}
