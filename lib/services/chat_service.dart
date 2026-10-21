import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class ChatService {
  final _supabase = Supabase.instance.client;

  static const String _conversationSelect = '''
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
    ),
    messages:messages(
      id,
      content,
      sender_id,
      read_at,
      created_at
    )
  ''';

  Future<List<Map<String, dynamic>>> fetchConversations(String userId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select(_conversationSelect)
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching conversations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchConversation(int transactionId) async {
    try {
      return await _supabase
          .from('transactions')
          .select(_conversationSelect)
          .eq('id', transactionId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error fetching conversation: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int transactionId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('transaction_id', transactionId)
          .order('created_at', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching messages: $e');
      return [];
    }
  }

  Future<void> sendMessage(int transactionId, String senderId, String content) async {
    try {
      await _supabase.from('messages').insert({
        'transaction_id': transactionId,
        'sender_id': senderId,
        'content': content,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  StreamSubscription<List<Map<String, dynamic>>> subscribeToMessages(
      int transactionId,
      Function(List<Map<String, dynamic>>) onData, {
      Function(Object error)? onError,
  }) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('transaction_id', transactionId)
        .order('created_at', ascending: true)
        .listen(
          (messages) {
            onData(List<Map<String, dynamic>>.from(messages));
          },
          onError: onError,
        );
  }

  void subscribeToTransactionChanges(String userId, VoidCallback onChanged) {
    _supabase
        .channel('transactions_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) {
            final targetRecord = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
            if (targetRecord['requester_id'] == userId || targetRecord['provider_id'] == userId) {
              onChanged();
            }
          },
        )
        .subscribe();
  }

  StreamSubscription<List<Map<String, dynamic>>> subscribeToTransaction(
      int transactionId, Function(List<Map<String, dynamic>>) onData) {
    return _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('id', transactionId)
        .listen((data) {
          onData(List<Map<String, dynamic>>.from(data));
        });
  }

  Future<void> markMessagesAsRead(int transactionId, String userId) async {
    try {
      await _supabase
          .from('messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('transaction_id', transactionId)
          .neq('sender_id', userId)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('id')
          .or('requester_id.eq.$userId,provider_id.eq.$userId');
          
      if (response.isEmpty) return 0;
      
      final transactionIds = response.map((c) => c['id'] as int).toList();

      final unreadResponse = await _supabase
          .from('messages')
          .select('id')
          .inFilter('transaction_id', transactionIds)
          .neq('sender_id', userId)
          .isFilter('read_at', null);
      
      return unreadResponse.length;
    } catch (e) {
      debugPrint('❌ Error calculating unread count: $e');
      return 0;
    }
  }

  Future<int> getUnreadCountForTransaction(int transactionId, String userId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('transaction_id', transactionId)
          .neq('sender_id', userId)
          .isFilter('read_at', null);
      return response.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count for transaction: $e');
      return 0;
    }
  }

  Future<int?> getExistingTransactionForRequest(int requestId, String userId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('id')
          .eq('request_id', requestId)
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .maybeSingle();
      
      if (response != null && response['id'] != null) {
        return response['id'] as int;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error verifying transaction existence: $e');
      return null;
    }
  }

  Future<String?> getOtherUserId(int transactionId, String currentUserId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('requester_id, provider_id')
          .eq('id', transactionId)
          .maybeSingle();
      
      if (response == null) return null;
      if (response['requester_id'] == currentUserId) return response['provider_id'] as String?;
      if (response['provider_id'] == currentUserId) return response['requester_id'] as String?;
      return null;
    } catch (e) {
      debugPrint('❌ Error calculating companion node ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select('username, aura_level, rating, profile_picture_url, verified')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error pulling user profile record: $e');
      return null;
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
    } catch (e) {
      debugPrint('❌ Error erasing database message entry: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionsForRequest(int requestId) async {
    try {
      final response = await _supabase.from('transactions').select('*').eq('request_id', requestId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
