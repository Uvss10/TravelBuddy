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
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
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
  static const String profile      = '/profile';
  static const String settings     = '/settings';

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
        return _fadeRoute(AiProcessingScreen(tripData: args ?? {}), settings_);
      case itinerary:
        final trip = settings_.arguments as TripModel?;
        return _slideRoute(ItineraryScreen(trip: trip), settings_);
      case story:
        final trip = settings_.arguments as TripModel?;
        return _slideRoute(StoryScreen(trip: trip), settings_);
      case reelPreview:
        return _slideRoute(const ReelPreviewScreen(), settings_);
      case downloadShare:
        return _slideRoute(const DownloadShareScreen(), settings_);
      case profile:
        return _slideRoute(const ProfileScreen(), settings_);
      case AppRoutes.settings:
        return _slideRoute(const SettingsScreen(), settings_);
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
