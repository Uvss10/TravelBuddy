import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';

/// Manages auth state via Supabase Cloud.
class AuthProvider extends ChangeNotifier {
  static const _keyOnboarded  = 'onboarded';
  static const _keyUserId     = 'user_id';
  static const _keyUserName   = 'user_name';
  static const _keyUserEmail  = 'user_email';

  final _supabase = Supabase.instance.client;

  UserModel? _user;
  bool _isLoggedIn    = false;
  bool _onboardingDone = false;
  bool _isLoading     = true;   // true until _restore() completes
  String? _error;

  UserModel? get user          => _user;
  bool get isLoggedIn          => _isLoggedIn;
  bool get onboardingDone      => _onboardingDone;
  bool get isLoading           => _isLoading;   // splash waits on this
  String? get error            => _error;

  AuthProvider() {
    _restore();
    // Keep session alive: re-sync whenever Supabase auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        final u = session.user;
        _user      = UserModel(
          id:    u.id,
          name:  u.userMetadata?['full_name'] ?? _user?.name ?? 'Explorer',
          email: u.email ?? _user?.email ?? '',
        );
        _isLoggedIn = true;
      } else {
        _user       = null;
        _isLoggedIn = false;
      }
      notifyListeners();
    });
  }

  Future<void> _restore() async {
    _isLoading = true;
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool(_keyOnboarded) ?? false;

    // Priority 1: Active Supabase session (handles token refresh automatically)
    final session = _supabase.auth.currentSession;
    if (session != null) {
      final u    = session.user;
      final name = u.userMetadata?['full_name'] ??
                   prefs.getString(_keyUserName) ?? 'Explorer';
      _user       = UserModel(id: u.id, name: name, email: u.email ?? '');
      _isLoggedIn = true;
      // Refresh local cache to keep it in sync
      await prefs.setString(_keyUserId,    u.id);
      await prefs.setString(_keyUserName,  name);
      await prefs.setString(_keyUserEmail, u.email ?? '');
    } else {
      // Priority 2: Offline cache — lets app work without internet on relaunch
      final cachedId = prefs.getString(_keyUserId);
      if (cachedId != null && cachedId.isNotEmpty) {
        _user = UserModel(
          id:    cachedId,
          name:  prefs.getString(_keyUserName)  ?? 'Explorer',
          email: prefs.getString(_keyUserEmail) ?? '',
        );
        _isLoggedIn = true;
      }
    }

    _isLoading = false;
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
        _user       = UserModel(id: res.user!.id, name: name, email: email);
        _isLoggedIn = true;
        await _cacheUser(res.user!.id, name, email);
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
        final name  = res.user!.userMetadata?['full_name'] ?? 'Explorer';
        _user       = UserModel(id: res.user!.id, name: name, email: email);
        _isLoggedIn = true;
        await _cacheUser(res.user!.id, name, email);
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

  /// Writes user details to SharedPreferences for offline session restoration.
  Future<void> _cacheUser(String id, String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId,    id);
    await prefs.setString(_keyUserName,  name);
    await prefs.setString(_keyUserEmail, email);
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user       = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    notifyListeners();
  }
}
