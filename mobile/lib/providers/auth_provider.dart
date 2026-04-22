import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';

/// Manages auth state via Supabase Cloud.
class AuthProvider extends ChangeNotifier {
  static const _keyOnboarded = 'onboarded';
  
  final _supabase = Supabase.instance.client;

  UserModel? _user;
  bool _isLoggedIn = false;
  bool _onboardingDone = false;
  String? _error;

  UserModel? get user        => _user;
  bool get isLoggedIn        => _isLoggedIn;
  bool get onboardingDone    => _onboardingDone;
  String? get error          => _error;

  AuthProvider() {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool(_keyOnboarded) ?? false;
    
    // Check if session exists in Supabase
    final session = _supabase.auth.currentSession;
    if (session != null) {
      final user = session.user;
      final name = user.userMetadata?['full_name'] ?? 'Explorer';
      _user = UserModel(id: user.id, name: name, email: user.email ?? '');
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

  Future<bool> register(String name, String email, String password) async {
    _error = null;
    notifyListeners();
    
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      
      if (res.user != null) {
        _user = UserModel(id: res.user!.id, name: name, email: email);
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = "An unexpected error occurred.";
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    notifyListeners();
    
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (res.user != null) {
        final name = res.user!.userMetadata?['full_name'] ?? 'Explorer';
        _user = UserModel(id: res.user!.id, name: name, email: email);
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = "Invalid email or password.";
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
