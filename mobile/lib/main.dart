import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/routes.dart';
import 'config/app_navigator.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/video_generation_provider.dart';
import 'providers/reel_draft_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/global_generation_overlay.dart';
import 'services/config_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from assets
  try {
    await dotenv.load(fileName: "assets/config.txt");
  } catch (e) {
    debugPrint("Warning: Could not load .env file from assets.");
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL', fallback: ''),
    anonKey: dotenv.get('SUPABASE_KEY', fallback: ''),
  );

  // ── Dynamic Backend URL (Strictly Google Drive) ──────────────────────────
  // Fetches backend_url and update info from your Google Drive version.json.
  await ConfigService().initialize();
  await ConfigService().refreshFromGoogleDrive('19MoogiD9DYQ5Fnb_lHBcTAFxdy-nKQ6o');
  ApiService().reinitialize(); // Rebuild Dio with the fresh URL

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // TripProvider listens to AuthProvider so userId is always in sync
        ChangeNotifierProxyProvider<AuthProvider, TripProvider>(
          create: (_) => TripProvider(),
          update: (_, auth, trip) {
            trip!.setUserId(auth.user?.id);
            return trip;
          },
        ),
        ChangeNotifierProvider(create: (_) => VideoGenerationProvider()),
        ChangeNotifierProvider(create: (_) => ReelDraftProvider()),
      ],
      child: const TravelBuddyApp(),
    ),
  );
}

class TravelBuddyApp extends StatelessWidget {
  const TravelBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: AppNavigator.key,
      title: 'TravelBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (context, child) {
        return GlobalGenerationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
