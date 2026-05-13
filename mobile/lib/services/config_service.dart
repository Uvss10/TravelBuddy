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

  /// Override the URL at runtime (called from Settings screen).
  /// Persists to SharedPreferences and rebuilds Dio.
  void overrideUrl(String url) {
    _backendUrl = url;
  }

  /// Called once at app startup in main().
  /// 1. Instantly loads last-cached URL (zero-latency for offline use).
  /// 2. Then tries to refresh from Supabase in the background.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Step 1: Load cached URL from last successful fetch (works offline)
    final cached = prefs.getString(_prefKey);
    if (cached != null && cached.isNotEmpty) {
      _backendUrl = cached;
      debugPrint('[ConfigService] Using cached backend URL: $_backendUrl');
    }

    // Step 2: Auto-refresh disabled to keep developer settings persistent
    // try {
    //   final supabase = Supabase.instance.client;
    //   final res = await supabase
    //       .from('app_config')
    //       .select('value')
    //       .eq('key', 'backend_url')
    //       .single()
    //       .timeout(const Duration(seconds: 5));

    //   final fresh = res['value'] as String?;
    //   if (fresh != null && fresh.isNotEmpty) {
    //     _backendUrl = fresh;
    //     await prefs.setString(_prefKey, fresh);
    //     debugPrint('[ConfigService] Updated backend URL from Supabase: $_backendUrl');
    //   }
    // } catch (e) {
    //   debugPrint('[ConfigService] Could not refresh from Supabase: $e');
    // }
  }

  /// Refresh config from a public Google Drive version.json file
  Future<void> refreshFromGoogleDrive(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final url = 'https://docs.google.com/uc?export=download&id=$fileId';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 1. Update Backend URL from Google Drive version.json (DISABLED to preserve custom URLs)
        // final freshUrl = data['backend_url'] as String?;
        // if (freshUrl != null && freshUrl.isNotEmpty) {
        //   _backendUrl = freshUrl;
        //   await prefs.setString(_prefKey, freshUrl);
        //   debugPrint('[ConfigService] Updated backend URL from Google Drive: $_backendUrl');
        // }

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
