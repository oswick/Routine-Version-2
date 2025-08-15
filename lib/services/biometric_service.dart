// lib/services/biometric_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isBiometricAvailable() async {
    try {
      print('🔒 BiometricService: Checking biometric availability...');
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();
      
      print('🔒 BiometricService: canCheckBiometrics = $canCheckBiometrics');
      print('🔒 BiometricService: isDeviceSupported = $isDeviceSupported');
      
      List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      print('🔒 BiometricService: availableBiometrics = $availableBiometrics');
      
      bool result = canCheckBiometrics && isDeviceSupported && availableBiometrics.isNotEmpty;
      print('🔒 BiometricService: Final availability result = $result');
      
      return result;
    } catch (e) {
      print('🔒 BiometricService: Error checking availability: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      List<BiometricType> result = await _auth.getAvailableBiometrics();
      print('🔒 BiometricService: Available biometrics: $result');
      return result;
    } catch (e) {
      print('🔒 BiometricService: Error getting available biometrics: $e');
      return [];
    }
  }

  static Future<AuthResult> authenticateWithResult() async {
    print('🔒 BiometricService: Starting authentication...');
    
    try {
      // Check if biometrics are available
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      print('🔒 BiometricService: canCheckBiometrics = $canCheckBiometrics');
      print('🔒 BiometricService: isDeviceSupported = $isDeviceSupported');

      if (!canCheckBiometrics) {
        print('🔒 BiometricService: Cannot check biometrics');
        return AuthResult(
          success: false, 
          errorMessage: 'Biometric authentication is not available on this device.'
        );
      }

      if (!isDeviceSupported) {
        print('🔒 BiometricService: Device not supported');
        return AuthResult(
          success: false, 
          errorMessage: 'This device does not support biometric authentication.'
        );
      }

      // Check if there are enrolled biometrics
      List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      print('🔒 BiometricService: Available biometrics: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) {
        print('🔒 BiometricService: No biometrics enrolled');
        return AuthResult(
          success: false, 
          errorMessage: 'No biometric methods are enrolled on this device. Please set up fingerprint, face ID, or other biometric authentication in your device settings.'
        );
      }

      print('🔒 BiometricService: Calling authenticate...');
      
      // Perform authentication
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to access the app',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      print('🔒 BiometricService: Authentication result = $authenticated');
      return AuthResult(success: authenticated);
      
    } on PlatformException catch (e) {
      String errorMessage;
      print('🔒 BiometricService: PlatformException: ${e.code} - ${e.message}');
      
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
      
      return AuthResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      print('🔒 BiometricService: Unexpected error: $e');
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

class AuthResult {
  final bool success;
  final String? errorMessage;

  AuthResult({required this.success, this.errorMessage});
}