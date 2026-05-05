import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app languages
enum AppLanguage { english, hindi, french, spanish }

/// All UI strings for the app. Add new keys here as needed.
class AppStrings {
  final String appName;
  final String home, trips, reels, profile;
  final String welcomeBack, yourWorld;
  final String planExpedition, globalExplorer, discoverSpots;
  final String myReels, reelStudio, noReelsSaved, deleteReel, keepReel;
  final String settings, appearance, darkMode, useSystemTheme;
  final String language, notifications, pushNotifications;
  final String about, appVersion, privacyPolicy, termsOfService;
  final String searchLocation, searchHint, discover, loading, retry;
  final String itinerary, generateReel, tweakPlan, applyMod;
  final String update, updateAvailable, updateNow, later;
  final String createTrip, destination, days, budget, interests;
  final String generating, pleaseWait, success, error, tryAgain;

  const AppStrings({
    required this.appName,
    required this.home, required this.trips, required this.reels, required this.profile,
    required this.welcomeBack, required this.yourWorld,
    required this.planExpedition, required this.globalExplorer, required this.discoverSpots,
    required this.myReels, required this.reelStudio, required this.noReelsSaved,
    required this.deleteReel, required this.keepReel,
    required this.settings, required this.appearance, required this.darkMode,
    required this.useSystemTheme, required this.language,
    required this.notifications, required this.pushNotifications,
    required this.about, required this.appVersion, required this.privacyPolicy,
    required this.termsOfService,
    required this.searchLocation, required this.searchHint,
    required this.discover, required this.loading, required this.retry,
    required this.itinerary, required this.generateReel,
    required this.tweakPlan, required this.applyMod,
    required this.update, required this.updateAvailable, required this.updateNow,
    required this.later, required this.createTrip, required this.destination,
    required this.days, required this.budget, required this.interests,
    required this.generating, required this.pleaseWait, required this.success,
    required this.error, required this.tryAgain,
  });
}

/// All translations
const _en = AppStrings(
  appName: 'TravelBuddy', home: 'Home', trips: 'Trips', reels: 'Reels', profile: 'Profile',
  welcomeBack: 'WELCOME BACK', yourWorld: 'Your World',
  planExpedition: 'Plan Expedition', globalExplorer: 'Global Explorer',
  discoverSpots: 'Discover Spots',
  myReels: 'MY REELS', reelStudio: 'STUDIO', noReelsSaved: 'No reels saved yet. Create one in Reel Studio!',
  deleteReel: 'Delete', keepReel: 'Keep',
  settings: 'Settings', appearance: 'Appearance', darkMode: 'Dark Mode',
  useSystemTheme: 'Use System Theme', language: 'Language',
  notifications: 'Notifications', pushNotifications: 'Push Notifications',
  about: 'About', appVersion: 'App Version', privacyPolicy: 'Privacy Policy',
  termsOfService: 'Terms of Service',
  searchLocation: 'Explore a destination', searchHint: 'e.g. Jaipur, Paris, Bali...',
  discover: 'Discover', loading: 'Loading...', retry: 'Retry',
  itinerary: 'Itinerary', generateReel: 'Generate Reel Story',
  tweakPlan: 'Tweak this Plan', applyMod: 'Apply Modification',
  update: 'Update', updateAvailable: 'Update Available! 🚀',
  updateNow: 'UPDATE NOW', later: 'LATER',
  createTrip: 'Create Trip', destination: 'Destination', days: 'Days',
  budget: 'Budget', interests: 'Interests',
  generating: 'Generating...', pleaseWait: 'Please wait',
  success: 'Success', error: 'Error', tryAgain: 'Try Again',
);

const _hi = AppStrings(
  appName: 'ट्रैवलबडी', home: 'होम', trips: 'यात्राएं', reels: 'रील्स', profile: 'प्रोफाइल',
  welcomeBack: 'वापसी पर स्वागत', yourWorld: 'आपकी दुनिया',
  planExpedition: 'यात्रा बनाएं', globalExplorer: 'विश्व खोजें',
  discoverSpots: 'जगहें खोजें',
  myReels: 'मेरी रील्स', reelStudio: 'स्टूडियो',
  noReelsSaved: 'अभी कोई रील सहेजी नहीं। रील स्टूडियो में बनाएं!',
  deleteReel: 'हटाएं', keepReel: 'रखें',
  settings: 'सेटिंग्स', appearance: 'रूप', darkMode: 'डार्क मोड',
  useSystemTheme: 'सिस्टम थीम', language: 'भाषा',
  notifications: 'सूचनाएं', pushNotifications: 'पुश सूचनाएं',
  about: 'हमारे बारे में', appVersion: 'ऐप संस्करण',
  privacyPolicy: 'गोपनीयता नीति', termsOfService: 'सेवा की शर्तें',
  searchLocation: 'गंतव्य खोजें', searchHint: 'जैसे जयपुर, पेरिस, बाली...',
  discover: 'खोजें', loading: 'लोड हो रहा है...', retry: 'फिर कोशिश करें',
  itinerary: 'यात्रा कार्यक्रम', generateReel: 'रील कहानी बनाएं',
  tweakPlan: 'योजना बदलें', applyMod: 'बदलाव लागू करें',
  update: 'अपडेट', updateAvailable: 'अपडेट उपलब्ध! 🚀',
  updateNow: 'अभी अपडेट करें', later: 'बाद में',
  createTrip: 'यात्रा बनाएं', destination: 'गंतव्य', days: 'दिन',
  budget: 'बजट', interests: 'रुचियां',
  generating: 'बन रहा है...', pleaseWait: 'कृपया प्रतीक्षा करें',
  success: 'सफलता', error: 'त्रुटि', tryAgain: 'फिर प्रयास करें',
);

const _fr = AppStrings(
  appName: 'TravelBuddy', home: 'Accueil', trips: 'Voyages', reels: 'Reels', profile: 'Profil',
  welcomeBack: 'BIENVENUE', yourWorld: 'Votre Monde',
  planExpedition: 'Planifier', globalExplorer: 'Explorateur',
  discoverSpots: 'Découvrir',
  myReels: 'MES REELS', reelStudio: 'STUDIO',
  noReelsSaved: 'Aucun reel sauvegardé. Créez-en un dans Reel Studio!',
  deleteReel: 'Supprimer', keepReel: 'Garder',
  settings: 'Paramètres', appearance: 'Apparence', darkMode: 'Mode Sombre',
  useSystemTheme: 'Thème Système', language: 'Langue',
  notifications: 'Notifications', pushNotifications: 'Notifications Push',
  about: 'À Propos', appVersion: 'Version', privacyPolicy: 'Politique de Confidentialité',
  termsOfService: "Conditions d'Utilisation",
  searchLocation: 'Explorer une destination', searchHint: 'ex. Jaipur, Paris, Bali...',
  discover: 'Découvrir', loading: 'Chargement...', retry: 'Réessayer',
  itinerary: 'Itinéraire', generateReel: 'Créer un Reel',
  tweakPlan: 'Modifier le Plan', applyMod: 'Appliquer',
  update: 'Mise à Jour', updateAvailable: 'Mise à Jour Disponible! 🚀',
  updateNow: 'METTRE À JOUR', later: 'PLUS TARD',
  createTrip: 'Créer un Voyage', destination: 'Destination', days: 'Jours',
  budget: 'Budget', interests: 'Intérêts',
  generating: 'Génération...', pleaseWait: 'Veuillez patienter',
  success: 'Succès', error: 'Erreur', tryAgain: 'Réessayer',
);

const _es = AppStrings(
  appName: 'TravelBuddy', home: 'Inicio', trips: 'Viajes', reels: 'Reels', profile: 'Perfil',
  welcomeBack: 'BIENVENIDO', yourWorld: 'Tu Mundo',
  planExpedition: 'Planificar', globalExplorer: 'Explorador',
  discoverSpots: 'Descubrir',
  myReels: 'MIS REELS', reelStudio: 'ESTUDIO',
  noReelsSaved: '¡Sin reels guardados. Crea uno en Reel Studio!',
  deleteReel: 'Eliminar', keepReel: 'Guardar',
  settings: 'Configuración', appearance: 'Apariencia', darkMode: 'Modo Oscuro',
  useSystemTheme: 'Tema del Sistema', language: 'Idioma',
  notifications: 'Notificaciones', pushNotifications: 'Notificaciones Push',
  about: 'Acerca de', appVersion: 'Versión', privacyPolicy: 'Política de Privacidad',
  termsOfService: 'Términos de Servicio',
  searchLocation: 'Explorar un destino', searchHint: 'ej. Jaipur, París, Bali...',
  discover: 'Descubrir', loading: 'Cargando...', retry: 'Reintentar',
  itinerary: 'Itinerario', generateReel: 'Generar Reel',
  tweakPlan: 'Ajustar Plan', applyMod: 'Aplicar',
  update: 'Actualizar', updateAvailable: '¡Actualización Disponible! 🚀',
  updateNow: 'ACTUALIZAR', later: 'DESPUÉS',
  createTrip: 'Crear Viaje', destination: 'Destino', days: 'Días',
  budget: 'Presupuesto', interests: 'Intereses',
  generating: 'Generando...', pleaseWait: 'Por favor espere',
  success: 'Éxito', error: 'Error', tryAgain: 'Intentar de nuevo',
);

/// Language provider — persists across restarts
class LanguageProvider extends ChangeNotifier {
  static const _key = 'app_language';
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  AppStrings get strings => _stringsFor(_language);

  String get languageName => switch (_language) {
    AppLanguage.english => 'English',
    AppLanguage.hindi   => 'Hindi',
    AppLanguage.french  => 'French',
    AppLanguage.spanish => 'Spanish',
  };

  LanguageProvider() { _load(); }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.name);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'english';
    _language = AppLanguage.values.firstWhere(
      (l) => l.name == saved,
      orElse: () => AppLanguage.english,
    );
    notifyListeners();
  }

  AppStrings _stringsFor(AppLanguage lang) => switch (lang) {
    AppLanguage.english => _en,
    AppLanguage.hindi   => _hi,
    AppLanguage.french  => _fr,
    AppLanguage.spanish => _es,
  };
}

/// Extension for easy access from BuildContext
extension LanguageContextExt on BuildContext {
  AppStrings get str => _LanguageProviderHelper.of(this);
}

class _LanguageProviderHelper {
  static AppStrings of(BuildContext context) {
    try {
      return (context.findAncestorWidgetOfExactType<_LangInheritedWidget>()?.strings) ?? _en;
    } catch (_) { return _en; }
  }
}

class _LangInheritedWidget extends InheritedWidget {
  final AppStrings strings;
  const _LangInheritedWidget({required this.strings, required super.child});
  @override
  bool updateShouldNotify(_LangInheritedWidget old) => strings != old.strings;
}
