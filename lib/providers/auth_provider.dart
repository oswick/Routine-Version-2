// lib/providers/auth_provider.dart - VERSIÓN CON CONFIGURACIÓN DE FUENTE
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthProvider with ChangeNotifier {
  static const _biometricKey = 'biometric_auth_enabled';
  static const _lastAuthTimeKey = 'last_auth_time';
  static const _authTimeoutKey = 'auth_timeout_minutes';
  static const _immediateTimeoutKey = 'immediate_timeout_enabled';
  static const _appStateKey = 'app_authenticated_state';
  static const _fontFamilyKey = 'selected_font_family';
  
  // Valores por defecto
  static const _defaultTimeoutMinutes = 5;
  static const _defaultImmediateTimeout = false;
  static const _defaultFontFamily = 'System';

  bool _isBiometricAuthEnabled = false;
  bool _isCurrentlyAuthenticated = false;
  int _authTimeoutMinutes = _defaultTimeoutMinutes;
  bool _immediateTimeoutEnabled = _defaultImmediateTimeout;
  String _selectedFontFamily = _defaultFontFamily;

  bool get isBiometricAuthEnabled => _isBiometricAuthEnabled;
  bool get isCurrentlyAuthenticated => _isCurrentlyAuthenticated;
  int get authTimeoutMinutes => _authTimeoutMinutes;
  bool get immediateTimeoutEnabled => _immediateTimeoutEnabled;
  String get selectedFontFamily => _selectedFontFamily;

  // Opciones disponibles para timeout
  static const List<int> timeoutOptions = [1, 2, 5, 10, 30];
  
  // Opciones de fuentes disponibles
  static const List<Map<String, dynamic>> fontOptions = [
    {'name': 'System', 'displayName': 'System Default'},
    {'name': 'Roboto', 'displayName': 'Roboto'},
    {'name': 'RobotoMono', 'displayName': 'Roboto Mono'},
    {'name': 'Poppins', 'displayName': 'Poppins'},
    {'name': 'Orbitron', 'displayName': 'Orbitron'},
  ];
  
  // Obtener texto descriptivo para cada opción de timeout
  static String getTimeoutText(int minutes) {
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  // Obtener el TextTheme para la fuente seleccionada
  TextTheme getTextTheme(TextTheme baseTheme) {
    switch (_selectedFontFamily) {
      case 'Roboto':
        return GoogleFonts.robotoTextTheme(baseTheme);
      case 'RobotoMono':
        return GoogleFonts.robotoMonoTextTheme(baseTheme);
      case 'Poppins':
        return GoogleFonts.poppinsTextTheme(baseTheme);
      case 'Orbitron':
        return GoogleFonts.orbitronTextTheme(baseTheme);
      case 'System':
      default:
        return baseTheme;
    }
  }

  // Obtener el nombre de la fuente para mostrar
  String getFontDisplayName(String fontName) {
    final fontOption = fontOptions.firstWhere(
      (font) => font['name'] == fontName,
      orElse: () => {'displayName': 'System Default'},
    );
    return fontOption['displayName'];
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
    _selectedFontFamily = prefs.getString(_fontFamilyKey) ?? _defaultFontFamily;
    
    print('🔐 AuthProvider: Biometric enabled = $_isBiometricAuthEnabled');
    print('🔐 AuthProvider: Timeout minutes = $_authTimeoutMinutes');
    print('🔐 AuthProvider: Immediate timeout = $_immediateTimeoutEnabled');
    print('🔐 AuthProvider: Selected font = $_selectedFontFamily');
    
    // Al cargar, siempre requerir autenticación si está habilitada
    _isCurrentlyAuthenticated = false;
    
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
    }
    
    notifyListeners();
  }

  Future<void> setAuthTimeout(int minutes) async {
    print('🔐 AuthProvider: Setting auth timeout = $minutes minutes');
    _authTimeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_authTimeoutKey, minutes);
    notifyListeners();
  }

  Future<void> setImmediateTimeout(bool enabled) async {
    print('🔐 AuthProvider: Setting immediate timeout = $enabled');
    _immediateTimeoutEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_immediateTimeoutKey, enabled);
    notifyListeners();
  }

  Future<void> setFontFamily(String fontFamily) async {
    print('🔐 AuthProvider: Setting font family = $fontFamily');
    _selectedFontFamily = fontFamily;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, fontFamily);
    notifyListeners();
  }

  Future<void> setLastAuthTime() async {
    final now = DateTime.now();
    print('🔐 AuthProvider: Setting last auth time = $now');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAuthTimeKey, now.millisecondsSinceEpoch);
    
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

    final prefs = await SharedPreferences.getInstance();
    final lastAuthTime = prefs.getInt(_lastAuthTimeKey);
    
    // Si nunca se ha autenticado, necesita auth
    if (lastAuthTime == null) {
      print('🔐 AuthProvider: Never authenticated, auth needed');
      return true;
    }

    // Si está habilitado el timeout inmediato, siempre necesita auth después de pausa
    if (_immediateTimeoutEnabled) {
      print('🔐 AuthProvider: Immediate timeout enabled, auth needed');
      return true;
    }

    // Para timeout regular, verificar el tiempo transcurrido desde la última autenticación
    final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
    final now = DateTime.now();
    final timeDifference = now.difference(lastAuth);
    final timeoutDuration = Duration(minutes: _authTimeoutMinutes);
    
    print('🔐 AuthProvider: Last auth: $lastAuth');
    print('🔐 AuthProvider: Current time: $now');
    print('🔐 AuthProvider: Time difference: ${timeDifference.inMinutes} minutes ${timeDifference.inSeconds % 60} seconds');
    print('🔐 AuthProvider: Timeout threshold: $_authTimeoutMinutes minutes');
    
    final needsAuth = timeDifference >= timeoutDuration;
    print('🔐 AuthProvider: Needs auth: $needsAuth');
    
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
    if (_isBiometricAuthEnabled && _immediateTimeoutEnabled) {
      print('🔐 AuthProvider: Immediate timeout enabled, marking as unauthenticated');
      _isCurrentlyAuthenticated = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, false);
      notifyListeners();
    }
  }

  Future<bool> checkAuthOnResume() async {
    print('🔐 AuthProvider: ===============================================');
    print('🔐 AuthProvider: CHECKING AUTH ON APP RESUME');
    print('🔐 AuthProvider: ===============================================');
    
    if (!_isBiometricAuthEnabled) {
      print('🔐 AuthProvider: Biometric not enabled, no auth needed');
      _isCurrentlyAuthenticated = true;
      notifyListeners();
      return false; // No necesita auth
    }
    
    print('🔐 AuthProvider: Biometric IS enabled, checking timeout...');
    
    final needsAuth = await needsAuthAgain();
    
    if (needsAuth) {
      print('🔐 AuthProvider: ✋ AUTH REQUIRED - User needs to authenticate');
      _isCurrentlyAuthenticated = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appStateKey, false);
      notifyListeners();
      return true;
    } else {
      print('🔐 AuthProvider: ✅ NO AUTH NEEDED - User can continue');
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
    final lastAuthDateTime = lastAuthTime != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastAuthTime)
        : null;
    
    print('🔐 DEBUG INFO:');
    print('  - Biometric enabled: $_isBiometricAuthEnabled');
    print('  - Currently authenticated: $_isCurrentlyAuthenticated');
    print('  - Auth timeout minutes: $_authTimeoutMinutes');
    print('  - Immediate timeout: $_immediateTimeoutEnabled');
    print('  - Selected font: $_selectedFontFamily');
    print('  - Last auth time: $lastAuthDateTime');
    print('  - App state: ${prefs.getBool(_appStateKey)}');
    
    if (lastAuthDateTime != null) {
      final timeSinceAuth = DateTime.now().difference(lastAuthDateTime);
      print('  - Time since last auth: ${timeSinceAuth.inMinutes} minutes ${timeSinceAuth.inSeconds % 60} seconds');
    }
  }
}