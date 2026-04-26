import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/trip/create_trip_screen.dart';
import '../screens/trip/photo_upload_screen.dart';
import '../screens/trip/ai_processing_screen.dart';
import '../screens/trip/itinerary_screen.dart';
import '../screens/trip/story_screen.dart';
import '../screens/trip/reel_preview_screen.dart';
import '../screens/trip/download_share_screen.dart';
import '../screens/trip/reel_studio_screen.dart';
import '../screens/trip/reel_curation_screen.dart';
import '../screens/trip/reel_storyboard_screen.dart';
import '../screens/trip/reel_atmosphere_screen.dart';
import '../screens/trip/reel_annotation_screen.dart';
import '../screens/trip/reel_production_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/discovery/discovery_screen.dart';
import '../models/trip_model.dart';

/// Named routes for the entire application.
class AppRoutes {
  static const String splash       = '/';
  static const String onboarding   = '/onboarding';
  static const String login        = '/login';
  static const String signup       = '/signup';
  static const String home         = '/home';
  static const String createTrip   = '/create-trip';
  static const String photoUpload  = '/photo-upload';
  static const String aiProcessing = '/ai-processing';
  static const String itinerary    = '/itinerary';
  static const String story        = '/story';
  static const String reelPreview  = '/reel-preview';
  static const String downloadShare = '/download-share';
  // ── Reel Studio (multi-stage) ──
  static const String reelStudio    = '/reel-studio';
  static const String reelCuration  = '/reel-curation';
  static const String reelStoryboard = '/reel-storyboard';
  static const String reelAtmosphere = '/reel-atmosphere';
  static const String reelAnnotation = '/reel-annotation';
  static const String reelProduction = '/reel-production';
  static const String profile      = '/profile';
  static const String settings     = '/settings';
  static const String discovery    = '/discovery';

  /// Route generator — handles named routes + argument passing.
  static Route<dynamic> onGenerateRoute(RouteSettings settings_) {
    switch (settings_.name) {
      case splash:
        return _fadeRoute(const SplashScreen(), settings_);
      case onboarding:
        return _slideRoute(const OnboardingScreen(), settings_);
      case login:
        return _fadeRoute(const LoginScreen(), settings_);
      case signup:
        return _fadeRoute(const SignupScreen(), settings_);
      case home:
        return _fadeRoute(const HomeScreen(), settings_);
      case createTrip:
        return _slideRoute(const CreateTripScreen(), settings_);
      case photoUpload:
        final args = settings_.arguments as Map<String, dynamic>?;
        return _slideRoute(
          PhotoUploadScreen(
            initialDestination: args?['destination'] as String?,
            initialSceneTags: (args?['scene_tags'] as List?)?.cast<String>(),
            initialTone: args?['tone'] as String?,
          ),
          settings_,
        );
      case aiProcessing:
        final args = settings_.arguments as Map<String, dynamic>?;
        return _fadeRoute(
          AiProcessingScreen(
            destination: args?['destination'] as String? ?? 'Travel',
            sceneTags: (args?['scene_tags'] as List?)?.cast<String>() ?? [],
            tone: args?['tone'] as String? ?? 'cinematic',
            audioPath: args?['audio_path'] as String?,
          ),
          settings_,
        );
      case itinerary:
        final trip = settings_.arguments as TripModel?;
        return _slideRoute(ItineraryScreen(trip: trip), settings_);
      case story:
        final trip = settings_.arguments as TripModel?;
        return _slideRoute(StoryScreen(trip: trip), settings_);
      case reelPreview:
        final url = settings_.arguments as String?;
        return _slideRoute(ReelPreviewScreen(videoUrl: url), settings_);
      case downloadShare:
        return _slideRoute(const DownloadShareScreen(), settings_);
      // ── Reel Studio routes ──────────────────────────────────────────────────
      case reelStudio:
        return _slideRoute(const ReelStudioScreen(), settings_);
      case reelCuration:
        return _slideRoute(const ReelCurationScreen(), settings_);
      case reelStoryboard:
        return _slideRoute(const ReelStoryboardScreen(), settings_);
      case reelAtmosphere:
        return _slideRoute(const ReelAtmosphereScreen(), settings_);
      case reelAnnotation:
        return _slideRoute(const ReelAnnotationScreen(), settings_);
      case reelProduction:
        return _slideRoute(const ReelProductionScreen(), settings_);
      case profile:
        return _slideRoute(const ProfileScreen(), settings_);
      case AppRoutes.settings:
        return _slideRoute(const SettingsScreen(), settings_);
      case discovery:
        final args = settings_.arguments as Map<String, dynamic>?;
        final loc = args?['location'] as String? ?? 'Your World';
        final lat = args?['lat'] as double?;
        final lon = args?['lon'] as double?;
        return _slideRoute(DiscoveryScreen(location: loc, lat: lat, lon: lon), settings_);
      default:
        return _fadeRoute(const HomeScreen(), settings_);
    }
  }

  // ─── Transition helpers ─────────────────────────────────────────────────────

  static PageRoute _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static PageRoute _slideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
