import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

/// Fetches runtime configuration from Supabase app_config table.
/// This lets you change the backend URL without rebuilding the APK —
/// just update the value in Supabase and every user gets it on next launch.
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static const _prefKey = 'cached_backend_url';

  /// The live backend URL — always use this instead of ApiConfig.baseUrl
  String _backendUrl = ApiConfig.baseUrl;
  String get backendUrl => _backendUrl;

  /// Called once at app startup in main().
  /// 1. Instantly loads last-cached URL (zero-latency for offline use).
  /// 2. Then tries to refresh from Supabase in the background.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Step 1: Force use of ApiConfig.baseUrl (Clear any cached old IPs)
    await prefs.remove(_prefKey);
    _backendUrl = ApiConfig.baseUrl;

    // Step 2: Try to refresh from Supabase (non-blocking)
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('app_config')
          .select('value')
          .eq('key', 'backend_url')
          .single()
          .timeout(const Duration(seconds: 5));

      final fresh = res['value'] as String?;
      if (fresh != null && fresh.isNotEmpty) {
        // Disabled for local dev so it doesn't overwrite your local IP
        // _backendUrl = fresh;
        // await prefs.setString(_prefKey, fresh);
        debugPrint('[ConfigService] Supabase URL found but ignoring for local dev: $fresh');
      }
    } catch (e) {
      // Supabase unreachable — keep using cached/default URL
      debugPrint('[ConfigService] Could not refresh backend_url: $e');
    }
  }

  /// New: Refresh config from a public Google Drive version.json file
  Future<void> refreshFromGoogleDrive(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final url = 'https://docs.google.com/uc?export=download&id=$fileId';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 1. Update Backend URL (Disabled for local dev)
        final freshUrl = data['backend_url'] as String?;
        if (freshUrl != null && freshUrl.isNotEmpty) {
          // _backendUrl = freshUrl;
          // await prefs.setString(_prefKey, freshUrl);
          debugPrint('[ConfigService] Drive URL found but ignoring for local dev: $freshUrl');
        }

        // 2. Check for APK Version Updates
        final latestVersion = data['latest_version'] as int?;
        if (latestVersion != null) {
          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = int.tryParse(packageInfo.buildNumber) ?? 0;

          if (latestVersion > currentVersion) {
            _hasUpdate = true;
            _apkUrl = data['apk_url'] as String?;
            _updateMessage = data['update_message'] as String? ?? 'A new version is available!';
            debugPrint('[ConfigService] NEW UPDATE AVAILABLE: v$latestVersion (Current: v$currentVersion)');
          }
        }
        
        debugPrint('[ConfigService] Successfully refreshed from Google Drive');
      }
    } catch (e) {
      debugPrint('[ConfigService] Google Drive refresh failed: $e');
    }
  }

  bool _hasUpdate = false;
  String? _apkUrl;
  String? _updateMessage;

  bool get hasUpdate => _hasUpdate;
  String? get apkUrl => _apkUrl;
  String? get updateMessage => _updateMessage;
}
