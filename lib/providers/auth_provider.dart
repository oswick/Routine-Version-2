// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const _biometricKey = 'biometric_auth_enabled';
  static const _lastAuthTimeKey = 'last_auth_time';
  static const _authTimeoutKey = 'auth_timeout_minutes';
  static const _immediateTimeoutKey = 'immediate_timeout_enabled';
  static const _appStateKey = 'app_authenticated_state';
  static const _sessionAuthKey = 'session_authenticated'; // NUEVO

  // Valores por defecto
  static const _defaultTimeoutMinutes = 5;
  static const _defaultImmediateTimeout = false;

  bool _isBiometricAuthEnabled = false;
  bool _isCurrentlyAuthenticated = false;
  int _authTimeoutMinutes = _defaultTimeoutMinutes;
  bool _immediateTimeoutEnabled = _defaultImmediateTimeout;
  bool _sessionAuthenticated = false; // NUEVO - para manejar la sesión actual

  bool get isBiometricAuthEnabled => _isBiometricAuthEnabled;
  bool get isCurrentlyAuthenticated => _isCurrentlyAuthenticated;
  int get authTimeoutMinutes => _authTimeoutMinutes;
  bool get immediateTimeoutEnabled => _immediateTimeoutEnabled;

  static const List<int> timeoutOptions = [1, 2, 5, 10, 30];

  static String getTimeoutText(int minutes) {
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  AuthProvider() {
    print('🔐 AuthProvider: Constructor called');
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    print('🔐 AuthProvider: Loading preferences...');
    final prefs = await SharedPreferences.getInstance();

    _isBiometricAuthEnabled = prefs.getBool(_biometricKey) ?? false;
    _authTimeoutMinutes =
        prefs.getInt(_authTimeoutKey) ?? _defaultTimeoutMinutes;
    _immediateTimeoutEnabled =
        prefs.getBool(_immediateTimeoutKey) ?? _defaultImmediateTimeout;
    _sessionAuthenticated = prefs.getBool(_sessionAuthKey) ?? false;

    print('🔐 AuthProvider: Biometric enabled = $_isBiometricAuthEnabled');
    print('🔐 AuthProvider: Timeout minutes = $_authTimeoutMinutes');
    print('🔐 AuthProvider: Immediate timeout = $_immediateTimeoutEnabled');
    print('🔐 AuthProvider: Session authenticated = $_sessionAuthenticated');

    _isCurrentlyAuthenticated = false;
    notifyListeners();
  }

  Future<void> setBiometricAuthEnabled(bool isEnabled) async {
    print('🔐 AuthProvider: Setting biometric enabled = $isEnabled');
    _isBiometricAuthEnabled = isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, isEnabled);

    if (!isEnabled) {
      _isCurrentlyAuthenticated = false;
      _sessionAuthenticated = false;
      await prefs.remove(_lastAuthTimeKey);
      await prefs.remove(_appStateKey);
      await prefs.remove(_sessionAuthKey);
      _authTimeoutMinutes = _defaultTimeoutMinutes;
      _immediateTimeoutEnabled = _defaultImmediateTimeout;
      await prefs.remove(_authTimeoutKey);
      await prefs.remove(_immediateTimeoutKey);
    }
    notifyListeners();
  }

  Future<void> setAuthTimeout(int minutes) async {
    _authTimeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_authTimeoutKey, minutes);
    notifyListeners();
  }

  Future<void> setImmediateTimeout(bool enabled) async {
    _immediateTimeoutEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_immediateTimeoutKey, enabled);
    notifyListeners();
  }

  Future<void> setLastAuthTime() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAuthTimeKey, now.millisecondsSinceEpoch);

    _isCurrentlyAuthenticated = true;
    _sessionAuthenticated = true; // NUEVO - marcar sesión como autenticada
    await prefs.setBool(_appStateKey, true);
    await prefs.setBool(_sessionAuthKey, true);

    print('🔐 AuthProvider: ✅ Marked as authenticated');
    print('🔐 AuthProvider: Session authenticated = true');
    notifyListeners();
  }

  /// ✅ FIX: Verifica si necesita autenticación de nuevo
  Future<bool> needsAuthAgain() async {
    print('🔐 AuthProvider: Checking if auth needed...');

    if (!_isBiometricAuthEnabled) return false;

    // Si ya estamos autenticados en esta sesión, no pedir auth otra vez
    if (_sessionAuthenticated) {
      print('🔐 AuthProvider: ✅ Session already authenticated, no auth needed');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastAuthTime = prefs.getInt(_lastAuthTimeKey);

    if (lastAuthTime == null) {
      print('🔐 AuthProvider: No previous auth time, auth required');
      return true;
    }

    // Caso bloqueo inmediato: solo pedir auth si la sesión no está autenticada
    if (_immediateTimeoutEnabled) {
      print('🔐 AuthProvider: Immediate timeout enabled, checking session');
      return !_sessionAuthenticated;
    }

    // Verificar timeout normal
    final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
    final now = DateTime.now();
    final timeDifference = now.difference(lastAuth);
    final timeoutDuration = Duration(minutes: _authTimeoutMinutes);

    print('🔐 AuthProvider: Time since auth = ${timeDifference.inSeconds}s');
    bool needsAuth = timeDifference >= timeoutDuration;
    
    print('🔐 AuthProvider: Needs auth = $needsAuth');
    return needsAuth;
  }

  Future<void> onAppPaused() async {
    print('🔐 AuthProvider: App paused');
    if (_isBiometricAuthEnabled) {
      // Marcar como no autenticado al salir
      _isCurrentlyAuthenticated = false;
      _sessionAuthenticated = false; // NUEVO - limpiar sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, false);
      await prefs.setBool(_sessionAuthKey, false);
      print('🔐 AuthProvider: Session cleared on pause');
      notifyListeners();
    }
  }

  Future<void> markAsUnauthenticated() async {
    _isCurrentlyAuthenticated = false;
    _sessionAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appStateKey, false);
    await prefs.setBool(_sessionAuthKey, false);
    notifyListeners();
  }

  Future<bool> checkAuthOnResume() async {
    print('🔐 AuthProvider: ===============================================');
    print('🔐 AuthProvider: CHECKING AUTH ON APP RESUME');
    print('🔐 AuthProvider: ===============================================');

    if (!_isBiometricAuthEnabled) {
      _isCurrentlyAuthenticated = true;
      _sessionAuthenticated = true;
      notifyListeners();
      return false;
    }

    final needsAuth = await needsAuthAgain();

    if (needsAuth) {
      _isCurrentlyAuthenticated = false;
      _sessionAuthenticated = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, false);
      await prefs.setBool(_sessionAuthKey, false);
      notifyListeners();
      print('🔐 AuthProvider: ❌ Auth required');
      return true;
    } else {
      _isCurrentlyAuthenticated = true;
      _sessionAuthenticated = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, true);
      await prefs.setBool(_sessionAuthKey, true);
      notifyListeners();
      print('🔐 AuthProvider: ✅ Already authenticated');
      return false;
    }
  }

  Future<void> printDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAuthTime = prefs.getInt(_lastAuthTimeKey);
    final lastAuthDateTime =
        lastAuthTime != null ? DateTime.fromMillisecondsSinceEpoch(lastAuthTime) : null;

    print('🔐 DEBUG INFO:');
    print('  - Biometric enabled: $_isBiometricAuthEnabled');
    print('  - Currently authenticated: $_isCurrentlyAuthenticated');
    print('  - Session authenticated: $_sessionAuthenticated');
    print('  - Auth timeout minutes: $_authTimeoutMinutes');
    print('  - Immediate timeout: $_immediateTimeoutEnabled');
    print('  - Last auth time: $lastAuthDateTime');
    print('  - App state: ${prefs.getBool(_appStateKey)}');

    if (lastAuthDateTime != null) {
      final timeSinceAuth = DateTime.now().difference(lastAuthDateTime);
      print('  - Time since last auth: ${timeSinceAuth.inMinutes} minutes ${timeSinceAuth.inSeconds % 60} seconds');
    }
  }
}