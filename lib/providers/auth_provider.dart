// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const _biometricKey = 'biometric_auth_enabled';
  static const _lastAuthTimeKey = 'last_auth_time';
  static const _authTimeoutKey = 'auth_timeout_minutes';
  static const _immediateTimeoutKey = 'immediate_timeout_enabled';
  static const _appStateKey = 'app_authenticated_state';
  static const _appPausedTimeKey = 'app_paused_time';
  
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

  // Opciones disponibles para timeout
  static const List<int> timeoutOptions = [1, 2, 5, 10, 30];
  
  // Obtener texto descriptivo para cada opción
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
    _authTimeoutMinutes = prefs.getInt(_authTimeoutKey) ?? _defaultTimeoutMinutes;
    _immediateTimeoutEnabled = prefs.getBool(_immediateTimeoutKey) ?? _defaultImmediateTimeout;
    
    print('🔐 AuthProvider: Biometric enabled = $_isBiometricAuthEnabled');
    print('🔐 AuthProvider: Timeout minutes = $_authTimeoutMinutes');
    print('🔐 AuthProvider: Immediate timeout = $_immediateTimeoutEnabled');
    
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
      // Resetear configuraciones a valores por defecto
      _authTimeoutMinutes = _defaultTimeoutMinutes;
      _immediateTimeoutEnabled = _defaultImmediateTimeout;
      await prefs.remove(_authTimeoutKey);
      await prefs.remove(_immediateTimeoutKey);
      await prefs.remove(_appPausedTimeKey);
    }
    
    notifyListeners();
  }

  Future<void> setAuthTimeout(int minutes) async {
    print('🔐 AuthProvider: Setting auth timeout = $minutes minutes');
    _authTimeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_authTimeoutKey, minutes);
    
    // Si hay una sesión activa, podría necesitar re-autenticación
    // dependiendo del nuevo timeout
    if (_isCurrentlyAuthenticated && _immediateTimeoutEnabled) {
      final needsAuth = await needsAuthAgain();
      if (needsAuth) {
        _isCurrentlyAuthenticated = false;
        await prefs.setBool(_appStateKey, false);
      }
    }
    
    notifyListeners();
  }

  Future<void> setImmediateTimeout(bool enabled) async {
    print('🔐 AuthProvider: Setting immediate timeout = $enabled');
    _immediateTimeoutEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_immediateTimeoutKey, enabled);
    
    // NO cambiar el estado de autenticación actual cuando se configura
    // Solo afecta el comportamiento futuro cuando la app se pause/resume
    
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
    
    final prefs = await SharedPreferences.getInstance();
    
    // Si está habilitado el timeout inmediato, verificar si la app fue pausada
    if (_immediateTimeoutEnabled) {
      final appState = prefs.getBool(_appStateKey) ?? false;
      if (!appState) {
        print('🔐 AuthProvider: Immediate timeout enabled and app was paused, auth needed');
        return true;
      } else {
        print('🔐 AuthProvider: Immediate timeout enabled but app not paused, no auth needed yet');
        return false;
      }
    }
    
    // Para timeout regular, verificar el tiempo transcurrido
    final pausedTime = prefs.getInt(_appPausedTimeKey);
    final lastAuthTime = prefs.getInt(_lastAuthTimeKey);
    final wasAuthenticated = prefs.getBool(_appStateKey) ?? false;
    
    print('🔐 AuthProvider: Paused time = $pausedTime');
    print('🔐 AuthProvider: Last auth time = $lastAuthTime');
    print('🔐 AuthProvider: Was authenticated = $wasAuthenticated');
    print('🔐 AuthProvider: Current time = ${DateTime.now().millisecondsSinceEpoch}');

    // Si nunca se ha autenticado, necesita auth
    if (lastAuthTime == null || !wasAuthenticated) {
      print('🔐 AuthProvider: Never authenticated or not marked as authenticated, auth needed');
      return true;
    }

    // Calcular el tiempo transcurrido
    DateTime timeReference;
    
    if (pausedTime != null) {
      // Si hay tiempo de pausa, calcular desde cuando se pausó hasta cuando se autenticó
      timeReference = DateTime.fromMillisecondsSinceEpoch(pausedTime);
      print('🔐 AuthProvider: Using paused time as reference: $timeReference');
    } else {
      // Si no hay tiempo de pausa, usar tiempo actual (fallback)
      timeReference = DateTime.now();
      print('🔐 AuthProvider: No paused time found, using current time: $timeReference');
    }
    
    final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
    final diff = timeReference.difference(lastAuth);
    final timeoutSeconds = _authTimeoutMinutes * 60;
    final needsAuth = diff.inSeconds >= timeoutSeconds;
    
    print('🔐 AuthProvider: Time reference: $timeReference');
    print('🔐 AuthProvider: Last auth: $lastAuth');
    print('🔐 AuthProvider: Time difference: ${diff.inSeconds} seconds');
    print('🔐 AuthProvider: Timeout threshold: $timeoutSeconds seconds ($_authTimeoutMinutes minutes)');
    print('🔐 AuthProvider: Needs auth: $needsAuth');
    
    if (needsAuth) {
      _isCurrentlyAuthenticated = false;
      await prefs.setBool(_appStateKey, false);
      await prefs.remove(_appPausedTimeKey); // Limpiar tiempo de pausa
      print('🔐 AuthProvider: Timeout reached, marked as unauthenticated');
      notifyListeners();
    } else {
      // Si no necesita auth, marcar como autenticado y limpiar tiempo de pausa
      _isCurrentlyAuthenticated = true;
      await prefs.setBool(_appStateKey, true);
      await prefs.remove(_appPausedTimeKey);
      print('🔐 AuthProvider: Still within timeout, marked as authenticated');
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
      final prefs = await SharedPreferences.getInstance();
      
      if (_immediateTimeoutEnabled) {
        print('🔐 AuthProvider: Immediate timeout enabled, marking as unauthenticated');
        _isCurrentlyAuthenticated = false;
        await prefs.setBool(_appStateKey, false);
        notifyListeners();
      } else {
        print('🔐 AuthProvider: Regular timeout mode - recording pause time');
        // Guardar el tiempo cuando se pausó la app para calcular después
        await prefs.setInt(_appPausedTimeKey, DateTime.now().millisecondsSinceEpoch);
      }
    }
  }

  Future<bool> checkAuthOnResume() async {
    print('🔐 AuthProvider: ===============================================');
    print('🔐 AuthProvider: CHECKING AUTH ON APP RESUME');
    print('🔐 AuthProvider: ===============================================');
    
    if (!_isBiometricAuthEnabled) {
      print('🔐 AuthProvider: Biometric not enabled, no auth needed');
      return false; // No necesita auth
    }
    
    print('🔐 AuthProvider: Biometric IS enabled, checking timeout...');
    
    // Imprimir estado actual antes de verificar
    print('🔐 AuthProvider: Current state before check:');
    print('  - Currently authenticated: $_isCurrentlyAuthenticated');
    print('  - Immediate timeout: $_immediateTimeoutEnabled');
    print('  - Timeout minutes: $_authTimeoutMinutes');
    
    final needsAuth = await needsAuthAgain();
    
    if (needsAuth) {
      print('🔐 AuthProvider: ✋ AUTH REQUIRED - User needs to authenticate');
      _isCurrentlyAuthenticated = false;
      notifyListeners();
      return true;
    } else {
      print('🔐 AuthProvider: ✅ NO AUTH NEEDED - User can continue');
      _isCurrentlyAuthenticated = true;
      notifyListeners();
      return false;
    }
  }
  Future<void> printDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    print('🔐 DEBUG INFO:');
    print('  - Biometric enabled: $_isBiometricAuthEnabled');
    print('  - Currently authenticated: $_isCurrentlyAuthenticated');
    print('  - Auth timeout minutes: $_authTimeoutMinutes');
    print('  - Immediate timeout: $_immediateTimeoutEnabled');
    print('  - Last auth time: ${prefs.getInt(_lastAuthTimeKey)}');
    print('  - App paused time: ${prefs.getInt(_appPausedTimeKey)}');
    print('  - App state: ${prefs.getBool(_appStateKey)}');
  }
}