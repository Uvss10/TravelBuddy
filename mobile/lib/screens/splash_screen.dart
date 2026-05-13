import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../config/routes.dart';
import '../theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../widgets/travel_loaders.dart';
import '../services/config_service.dart';

/// Beautiful modern splash screen with animations
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // 1. Wait for AuthProvider to finish restoring session from cache/Supabase.
    //    Without this wait, the app reads isLoggedIn=false before _restore() completes
    //    and always sends the user back to the login screen on every launch.
    final auth = context.read<AuthProvider>();

    // Minimum splash time removed for instant startup
    if (!mounted) return;

    // Poll until _restore() finishes (usually <300ms after the 2s delay, max 4s safety)
    int waited = 0;
    while (auth.isLoading && waited < 4000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    if (!mounted) return;

    // 2. Check for OTA Updates (non-blocking — if backend offline, skip)
    try {
      final dio = Dio();
      final versionUrl = '${ConfigService().backendUrl}${ApiConfig.versionCheck}';
      final response = await dio.get(
        versionUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 1),
          sendTimeout: const Duration(seconds: 1),
          headers: {'bypass-tunnel-reminder': 'true', 'Bypass-Tunnel-Reminder': 'true'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // ── Integer build-number comparison ──────────────────────────────────
        // backend/api/health.py returns latest_version as an int (e.g. 6).
        // PackageInfo.buildNumber matches pubspec.yaml version: 1.0.0+5 → "5".
        // The release pipeline (scripts/release.py) bumps both automatically.
        final latestBuild = (data['latest_version'] as num?)?.toInt() ?? 0;
        final packageInfo = await PackageInfo.fromPlatform();
        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

        if (latestBuild > currentBuild) {
          if (!mounted) return;
          final apkUrl    = data['apk_url']      as String? ?? '';
          final notes     = data['release_notes'] as String? ?? 'New features and improvements.';
          final isMandatory = data['is_mandatory'] as bool? ?? true;

          showDialog(
            context: context,
            barrierDismissible: !isMandatory,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.system_update_rounded, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  const Text("Update Available", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Build v$latestBuild is now available!  (You have v$currentBuild)",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(notes, style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
              actions: [
                if (!isMandatory)
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Later"),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final url = Uri.parse(apkUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text(
                    "DOWNLOAD UPDATE",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
          if (isMandatory) return; // Halt navigation until user downloads
        }
      }
    } catch (_) {
      // Backend offline or version check failed — proceed normally
    }

    // 3. Normal Navigation Flow
    if (!mounted) return;
    final tripProvider = context.read<TripProvider>();

    if (!auth.onboardingDone) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else if (auth.isLoggedIn) {
      tripProvider.setUserId(auth.user?.id);
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use the new custom Travel Loader for the Splash Screen
              TravelLoaders.globePlaneLoader(context, message: "Preparing your adventure..."),
              const SizedBox(height: AppTheme.xl),
              
              // App Name - Animated
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'TravelBuddy',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PRO API EDITION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
