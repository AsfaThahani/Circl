import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class TransactionService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createTransaction({
    required int requestId,
    required String requesterId,
    required String providerId,
    required double amount,
    double? depositAmount,
    required String requestType,
    int durationValue = 1,
    String durationUnit = 'days',
  }) async {
    try {
      final response = await _supabase.from('transactions').insert({
        'request_id': requestId,
        'requester_id': requesterId,
        'provider_id': providerId,
        'amount': amount,
        'agreed_deposit': depositAmount ?? 0,
        'type': requestType,
        'status': 'negotiating',
        'offer_status': 'none',
        'agreed_duration_value': durationValue,
        'agreed_duration_unit': durationUnit,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      await _supabase.from('transaction_timeline').insert({
        'transaction_id': response['id'],
        'status': 'negotiating',
        'notes': 'Transaction created, negotiation started',
        'created_at': DateTime.now().toIso8601String(),
      });

      return response;
    } catch (e) {
      debugPrint('Error creating transaction: $e');
      rethrow;
    }
  }

  Future<void> updatePaymentStatus(int transactionId, String paymentId, String status) async {
    try {
      await _supabase.from('transactions').update({
        'gateway_payment_id': paymentId,
        'payment_status': status,
        'status': 'payment_held', 
        'paid_at': DateTime.now().toIso8601String(),
      }).eq('id', transactionId);

      await _supabase.from('transaction_timeline').insert({
        'transaction_id': transactionId,
        'status': 'payment_held',
        'notes': 'Payment authorized (funds held in escrow)',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      rethrow;
    }
  }

  Future<void> capturePayment(int transactionId, double finalAmount) async {
    try {
      await _supabase.from('transactions').update({
        'status': 'completed',
        'captured_amount': finalAmount,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', transactionId);

      await _supabase.from('transaction_timeline').insert({
        'transaction_id': transactionId,
        'status': 'completed',
        'notes': 'Payment captured and transaction completed',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error capturing payment: $e');
      rethrow;
    }
  }

  Future<void> releasePayment(int transactionId) async {
    try {
      await _supabase.from('transactions').update({
        'status': 'released',
        'released_at': DateTime.now().toIso8601String(),
        'payment_status': 'released',
      }).eq('id', transactionId);

      await _supabase.from('transaction_timeline').insert({
        'transaction_id': transactionId,
        'status': 'released',
        'notes': 'Payment hold released back to requester',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error releasing payment: $e');
      rethrow;
    }
  }

  Future<void> cancelTransaction(int transactionId, String userId) async {
    try {
      final transaction = await _supabase
          .from('transactions')
          .select('status, gateway_payment_id, payment_status')
          .eq('id', transactionId)
          .maybeSingle();

      if (transaction == null) throw Exception('Transaction not found');

      final String currentStatus = transaction['status'] ?? '';
      final String paymentStatus = transaction['payment_status'] ?? '';
      
      // Release held funds if transaction was pre-authorized
      if (paymentStatus == 'payment_held' || currentStatus == 'payment_held') {
        await releasePayment(transactionId);
      }

      await _supabase.from('transactions').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancelled_by': userId,
      }).eq('id', transactionId);

      await _supabase.from('transaction_timeline').insert({
        'transaction_id': transactionId,
        'status': 'cancelled',
        'notes': 'Transaction cancelled by user',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error cancelling transaction: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTransactionDetails(int transactionId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('''
            *,
            requester:profiles!transactions_requester_id_fkey(
              id, username, rating, aura_level, avatar_url
            ),
            provider:profiles!transactions_provider_id_fkey(
              id, username, rating, aura_level, avatar_url
            ),
            request:requests(
              id, title, description, type, 
              min_price, max_price, min_deposit, max_deposit,
              duration_value, duration_unit
            ),
            timeline:transaction_timeline(
              id, status, notes, created_at
            )
          ''')
          .eq('id', transactionId)
          .maybeSingle();
      
      return response ?? {};
    } catch (e) {
      debugPrint('Error getting transaction details: $e');
      return {};
    }
  }

  Future<Map<String, bool>> getConfirmationStatus(int transactionId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('requester_confirmed, provider_confirmed')
          .eq('id', transactionId)
          .maybeSingle();
      
      return {
        'requester_confirmed': response?['requester_confirmed'] ?? false,
        'provider_confirmed': response?['provider_confirmed'] ?? false,
      };
    } catch (e) {
      debugPrint('Error getting confirmation status: $e');
      return {
        'requester_confirmed': false,
        'provider_confirmed': false,
      };
    }
  }

  Future<void> updateTransactionStatus(int transactionId, String status, {String? notes}) async {
    try {
      await _supabase.from('transactions').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', transactionId);

      if (notes != null) {
        await _supabase.from('transaction_timeline').insert({
          'transaction_id': transactionId,
          'status': status,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error updating transaction status: $e');
      rethrow;
    }
  }

  Future<void> updateOfferStatus(int transactionId, String offerStatus, {
    double? offeredPrice,
    double? offeredDeposit,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'offer_status': offerStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (offeredPrice != null) {
        updateData['offered_price'] = offeredPrice;
      }
      if (offeredDeposit != null) {
        updateData['offered_deposit'] = offeredDeposit;
      }

      await _supabase.from('transactions').update(updateData).eq('id', transactionId);
    } catch (e) {
      debugPrint('Error updating offer status: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> confirmCompletion(int transactionId, String userId) async {
    try {
      final transaction = await _supabase
          .from('transactions')
          .select('requester_id, provider_id, requester_confirmed, provider_confirmed')
          .eq('id', transactionId)
          .maybeSingle();

      if (transaction == null) throw Exception('Transaction not found');

      final bool isProvider = transaction['provider_id'] == userId;
      final bool isRequester = transaction['requester_id'] == userId;
      
      if (!isProvider && !isRequester) {
        throw Exception('User is not part of this transaction');
      }

      final updateData = <String, dynamic>{};
      bool isFullyCompleted = false;

      if (isProvider) {
        updateData['provider_confirmed'] = true;
        if (transaction['requester_confirmed'] == true) {
          updateData['status'] = 'completed';
          updateData['completed_at'] = DateTime.now().toIso8601String();
          isFullyCompleted = true;
        }
      } else if (isRequester) {
        updateData['requester_confirmed'] = true;
        if (transaction['provider_confirmed'] == true) {
          updateData['status'] = 'completed';
          updateData['completed_at'] = DateTime.now().toIso8601String();
          isFullyCompleted = true;
        }
      }

      await _supabase.from('transactions').update(updateData).eq('id', transactionId);

      await _supabase.from('transaction_timeline').insert({
        'transaction_id': transactionId,
        'status': isFullyCompleted ? 'completed' : 'confirmed',
        'notes': isFullyCompleted 
            ? 'Both parties confirmed completion' 
            : 'One party confirmed completion',
        'created_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'isFullyCompleted': isFullyCompleted,
        'requesterConfirmed': isRequester ? true : (transaction['requester_confirmed'] ?? false),
        'providerConfirmed': isProvider ? true : (transaction['provider_confirmed'] ?? false),
      };
    } catch (e) {
      debugPrint('Error confirming completion: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserTransactions(String userId, {String? status}) async {
    try {
      var query = _supabase
          .from('transactions')
          .select('''
            *,
            requester:profiles!transactions_requester_id_fkey(username, avatar_url, aura_level),
            provider:profiles!transactions_provider_id_fkey(username, avatar_url, aura_level),
            request:requests(title, type)
          ''')
          .or('requester_id.eq.$userId,provider_id.eq.$userId');
      
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      
      final response = await query.order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting user transactions: $e');
      return [];
    }
  }

  Future<void> addTimelineEntry(int transactionId, String status, String notes) async {
    try {
      await _supabase.from('transaction_timeline').insert({
        'transaction_id': transactionId,
        'status': status,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error adding timeline entry: $e');
      rethrow;
    }
  }
}
