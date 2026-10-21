import 'dart:async';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import 'package:flutter/material.dart';

class PayHereService {
  final _supabase = Supabase.instance.client;
  
  static const String MERCHANT_ID = EnvConfig.payhereMerchantId;
  static const String SECRET = EnvConfig.payhereSecret;
  static const String NOTIFY_URL = EnvConfig.payhereNotifyUrl;

  Future<bool> initiatePayment({
    required double amount,
    required String orderId,
    required String itemTitle,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String address,
  }) async {
    final completer = Completer<bool>();
    
    // Authorize funds in escrow rather than immediate capture
    Map<String, dynamic> paymentObject = {
      "sandbox": true, 
      "merchant_id": MERCHANT_ID,
      "secret": SECRET,
      "notify_url": NOTIFY_URL, 
      "order_id": orderId,
      "items": itemTitle,
      "amount": amount.toStringAsFixed(2),
      "currency": "LKR",
      "first_name": firstName,
      "last_name": lastName,
      "email": email,
      "phone": phone,
      "address": address,
      "city": "Colombo",
      "country": "Sri Lanka",
      "action": "https://sandbox.payhere.lk/pay/authorize",
    };
    
    try {
      PayHere.startPayment(
        paymentObject,
        (paymentId) async {
          debugPrint("✅ Payment Held/Authorized: $paymentId");
          await _savePaymentRecord(orderId, paymentId, amount, 'payment_held');
          if (!completer.isCompleted) completer.complete(true);
        },
        (error) {
          debugPrint("❌ Payment Failed: $error");
          _savePaymentRecord(orderId, '', amount, 'failed');
          if (!completer.isCompleted) completer.complete(false);
        },
        () {
          debugPrint("Payment Dismissed by user");
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      
      Future.delayed(const Duration(seconds: 60), () {
        if (!completer.isCompleted) completer.complete(false);
      });
      
    } catch (e) {
      debugPrint("Error starting payment: $e");
      if (!completer.isCompleted) completer.complete(false);
    }
    
    return completer.future;
  }
  
  Future<void> _savePaymentRecord(String orderId, String paymentId, double amount, String status) async {
    try {
      await _supabase.from('payments').insert({
        'order_id': orderId,
        'payment_id': paymentId,
        'amount': amount,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error saving payment record: $e");
    }
  }
}
