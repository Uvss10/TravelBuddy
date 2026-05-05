import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'legal_screens.dart';

/// Settings screen — theme, language, notifications, legal.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String _appVersion = '1.0.0+4';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final langProvider   = context.watch<LanguageProvider>();
    final s = langProvider.strings;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          // ── Appearance ──────────────────────────────────────────────────────
          _SectionHeader(s.appearance),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: s.darkMode,
            trailing: Switch(
              value: themeProvider.isDark,
              activeColor: AppTheme.primary,
              onChanged: (v) => themeProvider.setTheme(v ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          _SettingsTile(
            icon: Icons.brightness_auto,
            title: s.useSystemTheme,
            trailing: Switch(
              value: themeProvider.themeMode == ThemeMode.system,
              activeColor: AppTheme.primary,
              onChanged: (v) => themeProvider.setTheme(v ? ThemeMode.system : ThemeMode.light),
            ),
          ),

          // ── Language ────────────────────────────────────────────────────────
          _SectionHeader(s.language),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: AppLanguage.values.map((lang) {
                  final isSelected = langProvider.language == lang;
                  final name = switch (lang) {
                    AppLanguage.english => '🇬🇧  English',
                    AppLanguage.hindi   => '🇮🇳  हिंदी (Hindi)',
                    AppLanguage.french  => '🇫🇷  Français (French)',
                    AppLanguage.spanish => '🇪🇸  Español (Spanish)',
                  };
                  return ListTile(
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                        : null,
                    onTap: () => langProvider.setLanguage(lang),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Notifications ───────────────────────────────────────────────────
          _SectionHeader(s.notifications),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: s.pushNotifications,
            trailing: Switch(
              value: _notifications,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ),

          // ── About ───────────────────────────────────────────────────────────
          _SectionHeader(s.about),
          _SettingsTile(
            icon: Icons.info_outline,
            title: s.appVersion,
            trailing: Text(_appVersion, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: s.privacyPolicy,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: s.termsOfService,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
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
          color: AppTheme.textSecondary, letterSpacing: 1.0,
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
