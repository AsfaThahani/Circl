import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchRequests() async {
    try {
      debugPrint('🔄 fetchRequests: Starting...');
      
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            profiles!requests_requester_id_fkey(
              username, 
              aura_level, 
              rating,
              profile_picture_url,
              verified
            )
          ''')
          .eq('status', 'open')
          .eq('is_available', true)
          .order('created_at', ascending: false);

      debugPrint('📊 fetchRequests returned ${response.length} requests');
      
      if (response.isNotEmpty) {
        debugPrint('📝 First request: ${response.first['title']}');
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllRequestsDebug() async {
    try {
      debugPrint('🔄 fetchAllRequestsDebug: Starting...');
      
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            profiles!requests_requester_id_fkey(
              username, 
              aura_level, 
              rating,
              profile_picture_url,
              verified
            )
          ''')
          .order('created_at', ascending: false);

      debugPrint('📊 fetchAllRequestsDebug returned ${response.length} requests');
      
      if (response.isNotEmpty) {
        for (var i = 0; i < response.length && i < 3; i++) {
          debugPrint('📝 Request ${i+1}: ${response[i]['title']} - status: ${response[i]['status']}, available: ${response[i]['is_available']}');
        }
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching all requests: $e');
      return [];
    }
  }

  Future<void> debugRequestFilters() async {
    try {
      debugPrint('🔍 Debug: Checking request filters...');
      
      final allRequests = await _supabase
          .from('requests')
          .select('id, title, status, is_available, requester_id')
          .order('created_at', ascending: false);
      
      debugPrint('📊 Total requests in DB: ${allRequests.length}');
      
      if (allRequests.isEmpty) {
        debugPrint('⚠️ No requests found in the database at all!');
        return;
      }
      
      for (var request in allRequests) {
        final status = request['status'] ?? 'null';
        final isAvailable = request['is_available'] ?? 'null';
        final title = request['title'] ?? 'Untitled';
        
        final passesFilter = status == 'open' && isAvailable == true;
        debugPrint('📝 "$title" - status: $status, is_available: $isAvailable ${passesFilter ? '✅' : '❌'}');
      }
    } catch (e) {
      debugPrint('❌ Error debugging filters: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchRequestById(int requestId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            profiles!requests_requester_id_fkey(
              username, 
              aura_level, 
              rating,
              profile_picture_url,
              verified
            )
          ''')
          .eq('id', requestId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching request: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableRequestsRPC() async {
    try {
      final response = await _supabase.rpc('get_available_requests');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching RPC requests: $e');
      return [];
    }
  }

  Future<bool> isRequestAvailable(int requestId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('id, status, is_available')
          .eq('id', requestId)
          .maybeSingle();

      if (response == null) return false;
      return response['status'] == 'open' && response['is_available'] == true;
    } catch (e) {
      debugPrint('Error checking availability: $e');
      return false;
    }
  }

  Future<int?> getExistingTransaction(int requestId, String userId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('id')
          .eq('request_id', requestId)
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .maybeSingle();
      
      if (response != null && response['id'] != null) {
        debugPrint('✅ Found existing transaction: ${response['id']}');
        return response['id'] as int;
      }
      
      debugPrint('ℹ️ No existing transaction found for request $requestId');
      return null;
    } catch (e) {
      debugPrint('Error checking existing transaction: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTransactionDetails(int transactionId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('''
            *,
            request:requests(
              id, 
              title, 
              type,
              requester:profiles!requests_requester_id_fkey(
                username, 
                aura_level,
                rating,
                profile_picture_url
              )
            ),
            provider:profiles!transactions_provider_id_fkey(
              username, 
              aura_level,
              rating,
              profile_picture_url
            )
          ''')
          .eq('id', transactionId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching transaction details: $e');
      return null;
    }
  }

  Future<int> acceptRequestAndCreateTransaction(int requestId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final existingTransaction = await getExistingTransaction(requestId, currentUser.id);
    if (existingTransaction != null) {
      debugPrint('✅ Reusing existing transaction: $existingTransaction');
      return existingTransaction;
    }

    final available = await isRequestAvailable(requestId);
    if (!available) {
      throw Exception('Sorry, someone else just accepted this request!');
    }

    try {
      final requestData = await _supabase
          .from('requests')
          .select('requester_id, type, title')
          .eq('id', requestId)
          .single();

      final transactionResponse = await _supabase.from('transactions').insert({
        'request_id': requestId,
        'requester_id': requestData['requester_id'],
        'provider_id': currentUser.id,
        'status': 'negotiating',
        'offer_status': 'none',
        'negotiation_history': [],
        'offered_price': 0,
        'offered_deposit': 0,
        'created_at': DateTime.now().toIso8601String(),
        'accepted_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      // Lock request while in negotiation
      await _supabase.from('requests').update({
        'status': 'negotiating',
        'is_available': false
      }).eq('id', requestId);

      debugPrint('✅ Created new transaction: ${transactionResponse['id']}');
      return transactionResponse['id'] as int;
      
    } catch (e) {
      debugPrint('Error in acceptRequestAndCreateTransaction: $e');
      throw Exception('Failed to accept request: $e');
    }
  }

  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> requestData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Please login to create a request');

      final response = await _supabase
          .from('requests')
          .insert({
            ...requestData,
            'requester_id': user.id,
            'status': 'open',
            'is_available': true,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error creating request: $e');
      rethrow;
    }
  }

  Future<void> updateRequest(int requestId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('requests')
          .update(updates)
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Error updating request: $e');
      rethrow;
    }
  }

  Future<void> deleteRequest(int requestId) async {
    try {
      await _supabase
          .from('requests')
          .delete()
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Error deleting request: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserRequests(String userId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            profiles!requests_requester_id_fkey(
              username,
              aura_level,
              rating,
              profile_picture_url
            )
          ''')
          .eq('requester_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserTransactions(String userId) async {
    try {
      debugPrint('📊 getUserTransactions called for userId: $userId');
      
      final asRequester = await _supabase
          .from('transactions')
          .select('''
            *,
            request:requests(
              id, 
              title, 
              type,
              requester:profiles!requests_requester_id_fkey(
                username, 
                aura_level,
                rating,
                profile_picture_url
              )
            ),
            provider:profiles!transactions_provider_id_fkey(
              username, 
              aura_level,
              rating,
              profile_picture_url
            )
          ''')
          .eq('requester_id', userId);
      
      debugPrint('📊 As requester: ${asRequester.length} transactions');
      
      final asProvider = await _supabase
          .from('transactions')
          .select('''
            *,
            request:requests(
              id, 
              title, 
              type,
              requester:profiles!requests_requester_id_fkey(
                username, 
                aura_level,
                rating,
                profile_picture_url
              )
            ),
            provider:profiles!transactions_provider_id_fkey(
              username, 
              aura_level,
              rating,
              profile_picture_url
            )
          ''')
          .eq('provider_id', userId);
      
      debugPrint('📊 As provider: ${asProvider.length} transactions');
      
      final allTransactions = <Map<String, dynamic>>[];
      final seenIds = <dynamic>{};
      
      for (var t in asRequester) {
        final id = t['id'];
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          allTransactions.add(t);
        }
      }
      
      for (var t in asProvider) {
        final id = t['id'];
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          allTransactions.add(t);
        }
      }
      
      allTransactions.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      
      debugPrint('📊 getUserTransactions returned ${allTransactions.length} transactions');
      
      if (allTransactions.isNotEmpty) {
        debugPrint('📝 First transaction: ${allTransactions.first}');
        for (var i = 0; i < allTransactions.length && i < 3; i++) {
          final t = allTransactions[i];
          debugPrint('  - ID: ${t['id']}, status: ${t['status']}, provider: ${t['provider_id']}, requester: ${t['requester_id']}');
        }
      }
      
      return allTransactions;
      
    } catch (e) {
      debugPrint('❌ Error fetching user transactions: $e');
      
      try {
        debugPrint('📊 Trying fallback query without joins...');
        final asRequesterFallback = await _supabase
            .from('transactions')
            .select('*')
            .eq('requester_id', userId);
        
        final asProviderFallback = await _supabase
            .from('transactions')
            .select('*')
            .eq('provider_id', userId);
        
        final allFallback = [...asRequesterFallback, ...asProviderFallback];
        debugPrint('📊 Fallback returned ${allFallback.length} transactions');
        return List<Map<String, dynamic>>.from(allFallback);
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }
}
