// lib/services/biometric_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Authenticate with detailed error handling
  static Future<AuthResult> authenticateWithResult() async {
    try {
      // Check if biometrics are available
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics) {
        return AuthResult(
          success: false, 
          errorMessage: 'Biometric authentication is not available on this device.'
        );
      }

      if (!isDeviceSupported) {
        return AuthResult(
          success: false, 
          errorMessage: 'This device does not support biometric authentication.'
        );
      }

      // Check if there are enrolled biometrics
      List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return AuthResult(
          success: false, 
          errorMessage: 'No biometric methods are enrolled on this device. Please set up fingerprint, face ID, or other biometric authentication in your device settings.'
        );
      }

      // Perform authentication
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to enable biometric security',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          biometricOnly: false, // Permite PIN además de biometría
          stickyAuth: true,
        ),
      );

      return AuthResult(success: authenticated);
    } on PlatformException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'NotAvailable':
          errorMessage = 'Biometric authentication is not available.';
          break;
        case 'NotEnrolled':
          errorMessage = 'No biometric credentials are enrolled. Please set up biometric authentication in Settings.';
          break;
        case 'LockedOut':
          errorMessage = 'Biometric authentication is temporarily locked. Please try again later.';
          break;
        case 'PermanentlyLockedOut':
          errorMessage = 'Biometric authentication is permanently locked. Please use your device passcode.';
          break;
        case 'UserCancel':
          errorMessage = 'Authentication was cancelled by the user.';
          break;
        case 'InvalidContext':
          errorMessage = 'Authentication context is invalid.';
          break;
        default:
          errorMessage = 'Authentication failed: ${e.message ?? 'Unknown error'}';
      }
      
      print('Biometric authentication error: ${e.code} - ${e.message}');
      return AuthResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      print('Unexpected authentication error: $e');
      return AuthResult(
        success: false, 
        errorMessage: 'An unexpected error occurred during authentication.'
      );
    }
  }

  // Legacy method for backward compatibility
  static Future<bool> authenticate() async {
    AuthResult result = await authenticateWithResult();
    return result.success;
  }
}

// Result class for detailed authentication feedback
class AuthResult {
  final bool success;
  final String? errorMessage;

  AuthResult({required this.success, this.errorMessage});
}