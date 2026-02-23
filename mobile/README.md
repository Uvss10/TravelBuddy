# TravelBuddy Mobile App — Flutter

A complete cross-platform mobile application for the TravelBuddy AI backend.  
Built with Flutter · Provider state management · Dio HTTP client · Clean Architecture.

---

## 📁 Project Structure

```
mobile/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   ├── api_config.dart          # Base URL, endpoints, limits
│   │   └── routes.dart              # Named routes + transition animations
│   ├── theme/
│   │   └── app_theme.dart           # Design system: colours, typography, component themes
│   ├── models/
│   │   └── trip_model.dart          # TripModel, ItineraryDay, ImageAnalysisResult, UserModel
│   ├── providers/
│   │   ├── auth_provider.dart       # Login/logout + SharedPreferences persistence
│   │   ├── trip_provider.dart       # Trip workflow state (itinerary → images → story)
│   │   └── theme_provider.dart      # Dark/light/system theme toggle
│   ├── services/
│   │   └── api_service.dart         # Dio HTTP client with retry, error mapping, upload
│   ├── widgets/
│   │   └── common_widgets.dart      # Reusable UI: buttons, inputs, cards, chips, banners
│   └── screens/
│       ├── splash_screen.dart
│       ├── onboarding_screen.dart
│       ├── auth/
│       │   ├── login_screen.dart
│       │   └── signup_screen.dart
│       ├── home/
│       │   └── home_screen.dart
│       ├── trip/
│       │   ├── create_trip_screen.dart
│       │   ├── photo_upload_screen.dart
│       │   ├── ai_processing_screen.dart
│       │   ├── itinerary_screen.dart
│       │   ├── story_screen.dart
│       │   ├── reel_preview_screen.dart
│       │   └── download_share_screen.dart
│       ├── profile/
│       │   └── profile_screen.dart
│       └── settings/
│           └── settings_screen.dart
├── assets/
│   ├── images/         # App images & illustrations
│   └── fonts/          # Inter font files
├── android/
│   └── app/src/main/AndroidManifest.xml
├── ios/
│   └── Runner/Info.plist
└── pubspec.yaml
```

---

## 🚀 Setup & Run

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0
- Android Studio / VS Code with Flutter extension
- Android emulator or physical device

### 1. Get dependencies
```bash
cd mobile
flutter pub get
```

### 2. Configure backend URL
Edit `lib/config/api_config.dart`:
```dart
// Android emulator → host machine
static const String baseUrl = 'http://10.0.2.2:8000';

// Physical device on same WiFi
static const String baseUrl = 'http://192.168.1.X:8000';
```

### 3. Add Inter font files
Download Inter from https://fonts.google.com/specimen/Inter  
Place in `assets/fonts/`:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

### 4. Run the app
```bash
flutter run
```

### 5. Build for release
```bash
# Android APK
flutter build apk --release

# iOS (Mac only)
flutter build ios --release
```

---

## 📱 Screens

| Screen | Route | Description |
|---|---|---|
| Splash | `/` | Logo animation, routes based on auth state |
| Onboarding | `/onboarding` | 3-slide feature introduction |
| Login | `/login` | Email/name form with validation |
| Signup | `/signup` | Account creation |
| Home | `/home` | Dashboard with pull-to-refresh & history |
| Create Trip | `/create-trip` | Destination, days, budget, mood chips |
| Photo Upload | `/photo-upload` | Multi-image picker with grid preview |
| AI Processing | `/ai-processing` | Animated 3-stage pipeline progress |
| Itinerary | `/itinerary` | Collapsible day-wise activity cards |
| Story | `/story` | Editable narration, captions, hashtags |
| Reel Preview | `/reel-preview` | Video player + caption overlay |
| Download & Share | `/download-share` | Download/share options |
| Profile | `/profile` | User stats + sign out |
| Settings | `/settings` | Theme, language, notifications |

---

## 🏗️ Architecture

- **Screens** — UI only, consume providers
- **Providers** — business logic + state (Provider/ChangeNotifier)
- **Services** — all API calls via Dio (single `ApiService` singleton)
- **Models** — pure Dart data classes with JSON serialisation
- **Widgets** — shared, reusable UI components
- **Config** — routes and API constants

---

## 🔗 Backend
The app connects to the FastAPI backend at `c:\Users\mansi\TravelBuddy\backend`.  
Start it with:
```bash
cd ..
python -m uvicorn backend.main:app --reload
```
