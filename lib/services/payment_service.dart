import 'package:flutter/material.dart';
import 'package:circl/services/app_lock_service.dart';

class PaymentService {
  static Future<bool> authorizePayment(double amount) async {
    try {
      final available = await AppLockService.isBiometricsAvailable();
      if (!available) {
        debugPrint('❌ Biometrics not available for payment');
        return false;
      }

      final authenticated = await AppLockService.authenticatePayment(amount);
      
      if (authenticated) {
        debugPrint('✅ Payment authorized: LKR ${amount.toStringAsFixed(2)}');
        return true;
      } else {
        debugPrint('❌ Payment authorization failed');
        return false;
      }
    } catch (e) {
      debugPrint('Payment authorization error: $e');
      return false;
    }
  }

  static Future<bool> processPayment({
    required double amount,
    required String requestId,
    required String description,
  }) async {
    try {
      final authorized = await authorizePayment(amount);
      
      if (!authorized) {
        debugPrint('❌ Payment authorization failed');
        return false;
      }
      
      debugPrint('✅ Payment processed: $description - LKR ${amount.toStringAsFixed(2)}');
      return true;
    } catch (e) {
      debugPrint('❌ Payment processing error: $e');
      return false;
    }
  }

  static Future<bool> topUpWallet({
    required double amount,
    required String userId,
  }) async {
    try {
      final authorized = await authorizePayment(amount);
      
      if (!authorized) {
        return false;
      }
      
      debugPrint('✅ Wallet topped up: LKR ${amount.toStringAsFixed(2)}');
      return true;
    } catch (e) {
      debugPrint('❌ Wallet top-up error: $e');
      return false;
    }
  }
}
