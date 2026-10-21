import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _languageCode = 'en';
  bool _faceIdEnabled = false;
  bool _isLoading = false;
  
  final LocalAuthentication _auth = LocalAuthentication();

  bool get isDarkMode => _isDarkMode;
  String get languageCode => _languageCode;
  bool get faceIdEnabled => _faceIdEnabled;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _languageCode = prefs.getString('languageCode') ?? 'en';
      _faceIdEnabled = prefs.getBool('faceIdEnabled') ?? false;
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> changeLanguage(String newLang) async {
    _languageCode = newLang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', newLang);
    notifyListeners();
  }

  Future<bool> toggleBiometrics(bool value) async {
    if (value) {
      try {
        final bool isDeviceSupported = await _auth.isDeviceSupported();
        if (!isDeviceSupported) {
          debugPrint('❌ Device does not support biometrics');
          return false;
        }

        final bool canCheckBiometrics = await _auth.canCheckBiometrics;
        if (!canCheckBiometrics) {
          debugPrint('❌ No biometrics enrolled on this device');
          return false;
        }

        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: 'Enable biometric security for payments',
        );
        
        if (didAuthenticate) {
          _faceIdEnabled = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('faceIdEnabled', true);
          notifyListeners();
          debugPrint('✅ Biometrics enabled successfully');
          return true;
        } else {
          debugPrint('❌ Biometrics authentication failed');
          return false;
        }
      } catch (e) {
        debugPrint('❌ Biometrics error: $e');
        return false;
      }
    } else {
      _faceIdEnabled = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('faceIdEnabled', false);
      notifyListeners();
      debugPrint('✅ Biometrics disabled');
      return true;
    }
  }

  Future<bool> isBiometricsAvailable() async {
    try {
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      if (!isDeviceSupported) return false;
      
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      return canCheckBiometrics;
    } catch (e) {
      debugPrint('Error checking biometrics availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<void> resetPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isDarkMode = false;
    _languageCode = 'en';
    _faceIdEnabled = false;
    notifyListeners();
    debugPrint('✅ All preferences reset');
  }
}
