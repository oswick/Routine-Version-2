import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const _biometricKey = 'biometric_auth_enabled';
  static const _lastAuthTimeKey = 'last_auth_time';
  static const _authTimeoutSeconds = 30; // Solicitar huella cada 30 segundos

  bool _isBiometricAuthEnabled = false;

  bool get isBiometricAuthEnabled => _isBiometricAuthEnabled;

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isBiometricAuthEnabled = prefs.getBool(_biometricKey) ?? false;
    notifyListeners();
  }

  Future<void> setBiometricAuthEnabled(bool isEnabled) async {
    _isBiometricAuthEnabled = isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, isEnabled);
    notifyListeners();
  }

  Future<void> setLastAuthTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastAuthTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> needsAuthAgain({required int seconds}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(_lastAuthTimeKey);

    if (lastTime == null) return true;

    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastTime),
    );

    return diff.inSeconds >= _authTimeoutSeconds; // <-- cambio aquí
  }
}
