import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static final LocalAuthentication _auth = LocalAuthentication();
  
  static Future<bool> isBiometricsAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (e) {
      debugPrint('Biometrics availability error: $e');
      return false;
    }
  }
  
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }
  
  static Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('appLockEnabled') ?? false;
  }
  
  static Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLockEnabled', enabled);
  }
  
  static Future<bool> authenticate(String reason) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
      );
      return authenticated;
    } catch (e) {
      debugPrint('Authentication error: $e');
      return false;
    }
  }
  
  static Future<bool> authenticateWithPinFallback(String reason) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
      );
      return authenticated;
    } catch (e) {
      debugPrint('Authentication with fallback error: $e');
      return false;
    }
  }
  
  static Future<bool> authenticatePayment(double amount) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Authorize payment of LKR ${amount.toStringAsFixed(2)}',
      );
      return authenticated;
    } catch (e) {
      debugPrint('Payment auth error: $e');
      return false;
    }
  }
  
  static Future<bool> authenticatePaymentWithPinFallback(double amount) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Authorize payment of LKR ${amount.toStringAsFixed(2)}',
      );
      return authenticated;
    } catch (e) {
      debugPrint('Payment auth with fallback error: $e');
      return false;
    }
  }
}
