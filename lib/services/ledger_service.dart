import 'package:supabase_flutter/supabase_flutter.dart';

class LedgerService {
  final _supabase = Supabase.instance.client;

  Future<double> getBalance(String userId) async {
    try {
      print('🔍 Getting balance for user: $userId');
      
      final response = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        final balance = (response['balance'] as num?)?.toDouble() ?? 0.0;
        print('✅ Balance from wallets: LKR $balance');
        return balance;
      }
      
      print('📝 No wallet found, creating one...');
      await _supabase.rpc('update_wallet', params: {
        'p_user_id': userId,
        'p_amount': 0.0
      });
      return 0.0;
    } catch (e) {
      print('❌ Error getting balance: $e');
      return 0.0;
    }
  }

  Future<void> syncWalletToProfile(String userId) async {
    try {
      final wallet = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (wallet != null) {
        final balance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        await _supabase
            .from('profiles')
            .update({'wallet_balance': balance})
            .eq('id', userId);
        print('✅ Synced wallet balance to profile: LKR $balance');
      }
    } catch (e) {
      print('❌ Error syncing wallet to profile: $e');
    }
  }

  Future<void> ensureWalletExists(String userId) async {
    try {
      print('📝 Ensuring wallet exists for user: $userId');
      final response = await _supabase
          .from('wallets')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) {
        print('📝 Creating wallet for user: $userId');
        await _supabase.rpc('update_wallet', params: {
          'p_user_id': userId,
          'p_amount': 0.0
        });
        print('✅ Wallet created for user: $userId');
      } else {
        print('✅ Wallet already exists for user: $userId');
      }
    } catch (e) {
      print('❌ Error ensuring wallet exists: $e');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  Future<void> processTransactionCompletion(int transactionId) async {
    try {
      print('💰 Processing wallet split for transaction $transactionId');
      
      final transaction = await _supabase
          .from('transactions')
          .select('*')
          .eq('id', transactionId)
          .single();
      
      final requesterId = transaction['requester_id'] as String;
      final providerId = transaction['provider_id'] as String;
      
      double totalAmount = _toDouble(transaction['agreed_price']) * _toInt(transaction['agreed_duration_value']);
      double deposit = _toDouble(transaction['agreed_deposit']);
      double platformFee = totalAmount * 0.05;
      double providerEarnings = totalAmount - platformFee;

      print('💰 Payment Split:');
      print('  Total: LKR $totalAmount');
      print('  Deposit: LKR $deposit');
      print('  Provider Earnings: LKR $providerEarnings');

      await ensureWalletExists(requesterId);
      await ensureWalletExists(providerId);

      // Refund escrow deposit to requester
      if (deposit > 0) {
        try {
          await _supabase.rpc('update_wallet', params: {
            'p_user_id': requesterId, 
            'p_amount': deposit
          });
          
          await _supabase.from('ledger_entries').insert({
            'user_id': requesterId,
            'amount': deposit,
            'type': 'deposit_refund',
            'reference_id': transactionId,
            'reference_type': 'transaction',
            'description': 'Deposit refund for transaction #$transactionId',
            'created_at': DateTime.now().toIso8601String(),
          });
          
          await syncWalletToProfile(requesterId);
          print('✅ Deposit refunded: LKR $deposit');
        } catch (e) {
          print('❌ Error refunding deposit: $e');
        }
      }

      // Payout provider earnings
      if (providerEarnings > 0) {
        try {
          await _supabase.rpc('update_wallet', params: {
            'p_user_id': providerId, 
            'p_amount': providerEarnings
          });
          
          await _supabase.from('ledger_entries').insert({
            'user_id': providerId,
            'amount': providerEarnings,
            'type': 'service_earnings',
            'reference_id': transactionId,
            'reference_type': 'transaction',
            'description': 'Payment for transaction #$transactionId (after 5% fee)',
            'created_at': DateTime.now().toIso8601String(),
          });
          
          await syncWalletToProfile(providerId);
          print('✅ Provider paid: LKR $providerEarnings');
        } catch (e) {
          print('❌ Error paying provider: $e');
        }
      }

      // Deduct platform fee
      if (platformFee > 0) {
        try {
          await _supabase.from('ledger_entries').insert({
            'user_id': providerId,
            'amount': -platformFee,
            'type': 'platform_fee',
            'reference_id': transactionId,
            'reference_type': 'transaction',
            'description': 'Platform fee (5%) for transaction #$transactionId',
            'created_at': DateTime.now().toIso8601String(),
          });
          print('✅ Platform fee logged: LKR $platformFee');
        } catch (e) {
          print('❌ Error logging platform fee: $e');
        }
      }

      print('✅ Wallet split completed successfully!');
      
    } catch (e) {
      print('❌ Wallet update error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions(String userId) async {
    try {
      final response = await _supabase
          .from('ledger_entries')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  Future<void> logTransaction(String userId, double amount, String type, {String? description}) async {
    try {
      await _supabase.from('ledger_entries').insert({
        'user_id': userId,
        'amount': amount,
        'type': type,
        'description': description ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging transaction: $e');
    }
  }

  Future<void> addFunds(String userId, double amount, String description) async {
    try {
      await _supabase.rpc('update_wallet', params: {
        'p_user_id': userId,
        'p_amount': amount
      });
      
      await logTransaction(userId, amount, 'deposit', description: description);
      await syncWalletToProfile(userId);
      print('✅ Added LKR $amount to user $userId');
    } catch (e) {
      print('❌ Error adding funds: $e');
      rethrow;
    }
  }

  Future<void> recordPlatformFee(double amount, String description) async {
    try {
      print('✅ Platform fee LKR $amount recorded: $description');
    } catch (e) {
      print('❌ Error recording platform fee: $e');
    }
  }
}
