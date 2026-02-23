import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';

/// Manages auth state (local — no server auth yet).
class AuthProvider extends ChangeNotifier {
  static const _keyName  = 'user_name';
  static const _keyEmail = 'user_email';
  static const _keyOnboarded = 'onboarded';

  UserModel? _user;
  bool _isLoggedIn = false;
  bool _onboardingDone = false;

  UserModel? get user        => _user;
  bool get isLoggedIn        => _isLoggedIn;
  bool get onboardingDone    => _onboardingDone;

  AuthProvider() {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool(_keyOnboarded) ?? false;
    final name  = prefs.getString(_keyName);
    final email = prefs.getString(_keyEmail);
    if (name != null && email != null) {
      _user = UserModel(name: name, email: email);
      _isLoggedIn = true;
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarded, true);
    notifyListeners();
  }

  /// Login — stores user locally (replace with real API call later).
  Future<void> login(String name, String email) async {
    _user = UserModel(name: name, email: email);
    _isLoggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyEmail, email);
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    notifyListeners();
  }
}
