import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/config_service.dart';
import '../../services/api_service.dart';
import 'legal_screens.dart';

/// Settings screen — theme, language, notifications, legal, developer.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  String _appVersion = '1.0.0';
  String _currentUrl = '';
  String _pingStatus = '';
  bool _pinging = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadCurrentUrl();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
  }

  Future<void> _loadCurrentUrl() async {
    if (mounted) setState(() => _currentUrl = ConfigService().backendUrl);
  }

  // ── Developer: open URL editor dialog ───────────────────────────────────────
  void _openUrlEditor() {
    final controller = TextEditingController(text: ConfigService().backendUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.developer_mode, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text('Backend URL', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your laptop's IP and port.\nExample: http://10.28.227.234:8080",
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'http://192.168.x.x:8080',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => controller.clear(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final url = controller.text.trim().replaceAll(RegExp(r'/$'), '');
              if (url.isEmpty ||
                  (!url.startsWith('http://') && !url.startsWith('https://'))) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('URL must start with http:// or https://')),
                  );
                }
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('cached_backend_url', url);
              ConfigService().overrideUrl(url);
              ApiService().reinitialize();
              if (mounted) {
                setState(() => _currentUrl = url);
                if (ctx.mounted) Navigator.pop(ctx);
                _pingBackend();
              }
            },
            child: const Text('Save & Test'),
          ),
        ],
      ),
    );
  }

  // ── Ping /health ─────────────────────────────────────────────────────────────
  Future<void> _pingBackend() async {
    setState(() {
      _pinging = true;
      _pingStatus = 'Testing...';
    });
    try {
      final dio = ApiService().dio;
      final resp = await dio
          .get('/health')
          .timeout(const Duration(seconds: 6));
      setState(() {
        _pingStatus = (resp.statusCode == 200) ? 'Connected!' : 'Error ${resp.statusCode}';
        _pinging = false;
      });
    } catch (e) {
      setState(() {
        _pingStatus = 'Failed: cannot reach server';
        _pinging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final s = langProvider.strings;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader(s.appearance),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: s.darkMode,
            trailing: Switch(
              value: themeProvider.isDark,
              activeColor: AppTheme.primary,
              onChanged: (v) =>
                  themeProvider.setTheme(v ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          _SettingsTile(
            icon: Icons.brightness_auto,
            title: s.useSystemTheme,
            trailing: Switch(
              value: themeProvider.themeMode == ThemeMode.system,
              activeColor: AppTheme.primary,
              onChanged: (v) =>
                  themeProvider.setTheme(v ? ThemeMode.system : ThemeMode.light),
            ),
          ),

          // ── Language ──────────────────────────────────────────────────────
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
                    AppLanguage.hindi => '🇮🇳  हिंदी (Hindi)',
                    AppLanguage.french => '🇫🇷  Français (French)',
                    AppLanguage.spanish => '🇪🇸  Español (Spanish)',
                  };
                  return ListTile(
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                        color:
                            isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primary)
                        : null,
                    onTap: () => langProvider.setLanguage(lang),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Notifications ─────────────────────────────────────────────────
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

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader(s.about),
          _SettingsTile(
            icon: Icons.info_outline,
            title: s.appVersion,
            trailing: Text(_appVersion,
                style: const TextStyle(color: AppTheme.textSecondary)),
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
                MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen())),
          ),

          // ── Developer ─────────────────────────────────────────────────────
          _SectionHeader('Developer'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.orange.withOpacity(0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current URL row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.dns_outlined,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentUrl.isEmpty ? 'Not set' : _currentUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'Copy URL',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _currentUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('URL copied!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Ping status
                if (_pingStatus.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        _pinging
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(
                                _pingStatus.startsWith('Connected')
                                    ? Icons.check_circle
                                    : Icons.error,
                                size: 14,
                                color: _pingStatus.startsWith('Connected')
                                    ? Colors.green
                                    : Colors.red,
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pingStatus,
                            style: TextStyle(
                              fontSize: 12,
                              color: _pingStatus.startsWith('Connected')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Change URL'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange),
                          onPressed: _openUrlEditor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.network_check, size: 16),
                          label: const Text('Test Connection'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary),
                          onPressed: _pinging ? null : _pingBackend,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

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
  const _SettingsTile(
      {required this.icon, required this.title, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, color: AppTheme.textHint)
              : null),
      onTap: onTap,
    );
  }
}
