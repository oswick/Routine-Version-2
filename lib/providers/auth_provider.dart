// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const _biometricKey = 'biometric_auth_enabled';
  static const _lastAuthTimeKey = 'last_auth_time';
  static const _authTimeoutSeconds = 30;
  static const _appStateKey = 'app_authenticated_state';

  bool _isBiometricAuthEnabled = false;
  bool _isCurrentlyAuthenticated = false;

  bool get isBiometricAuthEnabled => _isBiometricAuthEnabled;
  bool get isCurrentlyAuthenticated => _isCurrentlyAuthenticated;

  AuthProvider() {
    print('🔐 AuthProvider: Constructor called');
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    print('🔐 AuthProvider: Loading preferences...');
    final prefs = await SharedPreferences.getInstance();
    _isBiometricAuthEnabled = prefs.getBool(_biometricKey) ?? false;
    
    print('🔐 AuthProvider: Biometric enabled = $_isBiometricAuthEnabled');
    
    // Al cargar, siempre requerir autenticación si está habilitada
    _isCurrentlyAuthenticated = false;
    
    // Debug: mostrar valores actuales
    final lastAuthTime = prefs.getInt(_lastAuthTimeKey);
    final appState = prefs.getBool(_appStateKey) ?? false;
    
    print('🔐 AuthProvider: Last auth time = $lastAuthTime');
    print('🔐 AuthProvider: App state = $appState');
    print('🔐 AuthProvider: Currently authenticated = $_isCurrentlyAuthenticated');
    
    notifyListeners();
  }

  Future<void> setBiometricAuthEnabled(bool isEnabled) async {
    print('🔐 AuthProvider: Setting biometric enabled = $isEnabled');
    _isBiometricAuthEnabled = isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, isEnabled);
    
    if (!isEnabled) {
      print('🔐 AuthProvider: Biometric disabled, clearing auth states');
      _isCurrentlyAuthenticated = false;
      await prefs.remove(_lastAuthTimeKey);
      await prefs.remove(_appStateKey);
    }
    
    notifyListeners();
  }

  Future<void> setLastAuthTime() async {
    final now = DateTime.now();
    print('🔐 AuthProvider: Setting last auth time = $now');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastAuthTimeKey,
      now.millisecondsSinceEpoch,
    );
    
    // Marcar como autenticado
    _isCurrentlyAuthenticated = true;
    await prefs.setBool(_appStateKey, true);
    
    print('🔐 AuthProvider: Marked as currently authenticated');
    notifyListeners();
  }

  Future<bool> needsAuthAgain() async {
    print('🔐 AuthProvider: Checking if auth needed...');
    
    // Si no está habilitada la biometría, no necesita auth
    if (!_isBiometricAuthEnabled) {
      print('🔐 AuthProvider: Biometric not enabled, no auth needed');
      return false;
    }
    
    print('🔐 AuthProvider: Biometric IS enabled');
    
    // Si ya está marcado como no autenticado, necesita auth
    if (!_isCurrentlyAuthenticated) {
      print('🔐 AuthProvider: Not currently authenticated, auth needed');
      return true;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(_lastAuthTimeKey);
    final wasAuthenticated = prefs.getBool(_appStateKey) ?? false;

    print('🔐 AuthProvider: Last time = $lastTime, was authenticated = $wasAuthenticated');

    // Si nunca se ha autenticado, necesita auth
    if (lastTime == null || !wasAuthenticated) {
      print('🔐 AuthProvider: Never authenticated or not marked as authenticated, auth needed');
      return true;
    }

    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastTime),
    );

    final needsAuth = diff.inSeconds >= _authTimeoutSeconds;
    
    print('🔐 AuthProvider: Time difference = ${diff.inSeconds} seconds');
    print('🔐 AuthProvider: Needs auth = $needsAuth (timeout = $_authTimeoutSeconds seconds)');
    
    if (needsAuth) {
      _isCurrentlyAuthenticated = false;
      await prefs.setBool(_appStateKey, false);
      print('🔐 AuthProvider: Timeout reached, marked as unauthenticated');
      notifyListeners();
    }

    return needsAuth;
  }

  Future<void> markAsUnauthenticated() async {
    print('🔐 AuthProvider: Marking as unauthenticated');
    _isCurrentlyAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appStateKey, false);
    notifyListeners();
  }

  Future<void> onAppPaused() async {
    print('🔐 AuthProvider: App paused');
    if (_isBiometricAuthEnabled) {
      print('🔐 AuthProvider: Biometric enabled, marking as unauthenticated');
      _isCurrentlyAuthenticated = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, false);
      notifyListeners();
    }
  }

  // Método para debug
  Future<void> printDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    print('🔐 DEBUG INFO:');
    print('  - Biometric enabled: $_isBiometricAuthEnabled');
    print('  - Currently authenticated: $_isCurrentlyAuthenticated');
    print('  - Last auth time: ${prefs.getInt(_lastAuthTimeKey)}');
    print('  - App state: ${prefs.getBool(_appStateKey)}');
  }
}