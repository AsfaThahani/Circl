import 'package:flutter/material.dart';
import 'package:circl/services/app_lock_service.dart';

class AppLockProvider extends ChangeNotifier {
  bool _isLocked = false;
  bool _isChecking = true;
  bool _isAuthenticating = false;
  bool _hasAuthenticatedOnce = false;

  bool get isLocked => _isLocked;
  bool get isChecking => _isChecking;
  bool get isAuthenticating => _isAuthenticating;

  AppLockProvider() {
    checkLockStatus();
  }

  Future<void> checkLockStatus() async {
    if (_hasAuthenticatedOnce) {
      _isChecking = false;
      _isLocked = false;
      notifyListeners();
      return;
    }

    _isChecking = true;
    notifyListeners();

    final enabled = await AppLockService.isAppLockEnabled();
    
    if (enabled && !_hasAuthenticatedOnce) {
      _isLocked = true;
      _isChecking = false;
      notifyListeners();
    } else {
      _isLocked = false;
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> authenticateAndUnlock() async {
    if (_hasAuthenticatedOnce) {
      _isLocked = false;
      notifyListeners();
      return true;
    }

    _isAuthenticating = true;
    notifyListeners();

    final authenticated = await AppLockService.authenticate('Unlock Circl');
    
    _isAuthenticating = false;
    notifyListeners();

    if (authenticated) {
      _hasAuthenticatedOnce = true;
      _isLocked = false;
      notifyListeners();
      return true;
    } else {
      _isLocked = true;
      notifyListeners();
      return false;
    }
  }

  void lockApp() {
    if (!_isLocked && _hasAuthenticatedOnce) {
      _hasAuthenticatedOnce = false;
      _isLocked = true;
      notifyListeners();
    }
  }

  void resetLockState() {
    _hasAuthenticatedOnce = false;
    _isLocked = true;
    _isChecking = false;
    notifyListeners();
  }
}
