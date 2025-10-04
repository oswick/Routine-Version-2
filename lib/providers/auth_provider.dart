// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const _biometricKey = 'biometric_auth_enabled';
  static const _lastAuthTimeKey = 'last_auth_time';
  static const _authTimeoutKey = 'auth_timeout_minutes';
  static const _immediateTimeoutKey = 'immediate_timeout_enabled';
  static const _appStateKey = 'app_authenticated_state';

  // Valores por defecto
  static const _defaultTimeoutMinutes = 5;
  static const _defaultImmediateTimeout = false;

  bool _isBiometricAuthEnabled = false;
  bool _isCurrentlyAuthenticated = false;
  int _authTimeoutMinutes = _defaultTimeoutMinutes;
  bool _immediateTimeoutEnabled = _defaultImmediateTimeout;

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

    print('🔐 AuthProvider: Biometric enabled = $_isBiometricAuthEnabled');
    print('🔐 AuthProvider: Timeout minutes = $_authTimeoutMinutes');
    print('🔐 AuthProvider: Immediate timeout = $_immediateTimeoutEnabled');

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
      await prefs.remove(_lastAuthTimeKey);
      await prefs.remove(_appStateKey);
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
    await prefs.setBool(_appStateKey, true);

    print('🔐 AuthProvider: Marked as currently authenticated');
    notifyListeners();
  }

  /// ✅ FIX: ya no entra en bucle cuando immediateTimeout está activado
/// ✅ Ahora respeta el timeout configurado
Future<bool> needsAuthAgain() async {
  print('🔐 AuthProvider: Checking if auth needed...');

  if (!_isBiometricAuthEnabled) return false;

  final prefs = await SharedPreferences.getInstance();
  final lastAuthTime = prefs.getInt(_lastAuthTimeKey);

  if (lastAuthTime == null) return true;

  // Caso bloqueo inmediato: siempre pedir auth al volver
  if (_immediateTimeoutEnabled) {
    print('🔐 AuthProvider: Immediate timeout enabled, auth required');
    return true;
  }

  final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
  final now = DateTime.now();
  final timeDifference = now.difference(lastAuth);
  final timeoutDuration = Duration(minutes: _authTimeoutMinutes);

  print('🔐 AuthProvider: Time since auth = ${timeDifference.inSeconds}s');
  return timeDifference >= timeoutDuration;
}

Future<void> onAppPaused() async {
  print('🔐 AuthProvider: App paused');
  if (_isBiometricAuthEnabled) {
    // Siempre marcar como no autenticado al salir
    _isCurrentlyAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appStateKey, false);
    notifyListeners();
  }
}


  Future<void> markAsUnauthenticated() async {
    _isCurrentlyAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appStateKey, false);
    notifyListeners();
  }


  Future<bool> checkAuthOnResume() async {
    print('🔐 AuthProvider: ===============================================');
    print('🔐 AuthProvider: CHECKING AUTH ON APP RESUME');
    print('🔐 AuthProvider: ===============================================');

    if (!_isBiometricAuthEnabled) {
      _isCurrentlyAuthenticated = true;
      notifyListeners();
      return false;
    }

    final needsAuth = await needsAuthAgain();

    if (needsAuth) {
      _isCurrentlyAuthenticated = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, false);
      notifyListeners();
      return true;
    } else {
      _isCurrentlyAuthenticated = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, true);
      notifyListeners();
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
