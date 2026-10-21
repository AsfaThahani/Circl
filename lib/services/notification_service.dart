import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  final List<RealtimeChannel> _channels = [];
  Function(Map<String, dynamic>)? onNotificationReceived;
  
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  void listenToNotifications({Function(Map<String, dynamic>)? onNotification}) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('⚠️ No user logged in, cannot listen to notifications');
      return;
    }

    debugPrint('📬 Listening to real-time notifications for user: $userId');

    final channel = _supabase
        .channel('user-$userId')
        .onBroadcast(
          event: 'notification',
          callback: (payload) {
            debugPrint('📬 Received broadcast: $payload');
            
            _showInAppNotification(payload);
            
            if (onNotification != null) {
              onNotification(payload);
            }
            
            _saveNotificationFromPayload(payload);
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  void _showInAppNotification(Map<String, dynamic> payload) {
    debugPrint('📬 Notification: ${payload['title']}');
    debugPrint('Body: ${payload['body']}');
    debugPrint('Data: ${payload['data']}');
  }

  Future<void> _saveNotificationFromPayload(Map<String, dynamic> payload) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': payload['title'] ?? 'Notification',
        'body': payload['body'] ?? '',
        'type': payload['data']?['type'] ?? 'real_time',
        'data': payload['data'] ?? {},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Saved real-time notification to database');
    } catch (e) {
      debugPrint('❌ Error saving real-time notification: $e');
    }
  }

  void dispose() {
    for (var channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
    debugPrint('🔚 Real-time notification listeners disposed');
  }

  Future<List<CirclNotification>> fetchNotifications({int limit = 50}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      debugPrint('📬 Fetching notifications for user: $userId');
      final notifications = <CirclNotification>[];

      final transactionNotifs = await _fetchFromTransactions(userId);
      notifications.addAll(transactionNotifs);

      final tableNotifs = await _fetchFromNotificationsTable(userId);
      notifications.addAll(tableNotifs);

      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final Map<String, CirclNotification> unique = {};
      for (var n in notifications) {
        unique.putIfAbsent(n.id, () => n);
      }

      debugPrint('📬 Total unique notifications: ${unique.values.length}');
      return unique.values.toList();

    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      return [];
    }
  }

  Future<List<CirclNotification>> _fetchFromTransactions(String userId) async {
    final notifications = <CirclNotification>[];

    try {
      final transactions = await _supabase
          .from('transactions')
          .select('''
            *,
            requests:request_id (
              id, 
              title, 
              type, 
              created_at,
              requester_id,
              profiles:requester_id (
                username,
                avatar_url,
                profile_picture_url
              )
            )
          ''')
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .order('updated_at', ascending: false)
          .limit(30);

      debugPrint('📬 Found ${transactions.length} transactions');

      for (var t in transactions) {
        final status = (t['status'] ?? '').toString().toLowerCase();

        if (['completed', 'accepted', 'offer_sent', 'payment_pending', 'in_progress', 'negotiating', 'payment_held'].contains(status)) {
          final requestData = t['requests'] as Map<String, dynamic>?;
          final requestTitle = requestData?['title'] ?? 'a request';
          final requestType = requestData?['type'] ?? 'item';

          final isRequester = t['requester_id'].toString() == userId;
          final partnerId = isRequester ? t['provider_id'] : t['requester_id'];

          String partnerName = 'Someone';
          if (requestData != null) {
            final profiles = requestData['profiles'] as Map<String, dynamic>?;
            if (profiles != null) {
              final username = profiles['username'] as String?;
              if (username != null && username.isNotEmpty) {
                partnerName = username;
              }
            }
          }

          if (partnerName == 'Someone' && partnerId != null) {
            try {
              final partnerProfile = await _supabase
                  .from('profiles')
                  .select('username')
                  .eq('id', partnerId)
                  .maybeSingle();
              if (partnerProfile != null && partnerProfile['username'] != null) {
                partnerName = partnerProfile['username'];
              }
            } catch (e) {
              debugPrint('Error fetching partner name: $e');
            }
          }

          final notif = _createNotificationFromTransaction(
            t,
            status,
            isRequester,
            partnerName,
            requestTitle,
            requestType,
          );

          if (notif != null) {
            notifications.add(notif);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching from transactions: $e');
    }

    return notifications;
  }

  Future<List<CirclNotification>> _fetchFromNotificationsTable(String userId) async {
    final notifications = <CirclNotification>[];

    try {
      final result = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      debugPrint('📬 Found ${result.length} notifications from notifications table');

      for (var data in result) {
        notifications.add(CirclNotification(
          id: 'notif_${data['id']}',
          title: data['title'] ?? 'Notification',
          subtitle: data['body'] ?? '',
          type: _parseNotificationType(data['type'] ?? ''),
          timestamp: data['created_at'] != null
              ? DateTime.parse(data['created_at'] as String)
              : DateTime.now(),
          isRead: data['is_read'] ?? false,
          metadata: data['data'] is Map ? Map<String, dynamic>.from(data['data']) : {},
          icon: _getIconForType(data['type'] ?? ''),
          color: _getColorForType(data['type'] ?? ''),
        ));
      }
    } catch (e) {
      debugPrint('❌ Error fetching from notifications table: $e');
    }

    return notifications;
  }

  CirclNotification? _createNotificationFromTransaction(
    Map<String, dynamic> transaction,
    String status,
    bool isRequester,
    String partnerName,
    String requestTitle,
    String requestType,
  ) {
    if (status == 'completed') {
      final amount = transaction['agreed_price'] ?? transaction['offered_price'] ?? 0;
      final subtitle = isRequester
          ? '$partnerName completed your request "$requestTitle"'
          : 'You completed the request "$requestTitle"';

      return CirclNotification(
        id: 'transaction_${transaction['id']}',
        title: 'Task Completed ✅',
        subtitle: amount > 0 ? '$subtitle (LKR ${amount.toStringAsFixed(0)})' : subtitle,
        type: NotificationType.transactionComplete,
        timestamp: transaction['updated_at'] != null
            ? DateTime.parse(transaction['updated_at'] as String)
            : DateTime.now(),
        isRead: transaction['is_read'] ?? false,
        metadata: {
          'transaction_id': transaction['id'],
          'request_id': transaction['request_id'],
          'status': status,
          'partner_name': partnerName,
          'amount': amount,
        },
        icon: Icons.check_circle_outline,
        color: const Color(0xFF26A69A),
      );
    } else if (status == 'accepted') {
      final amount = transaction['agreed_price'] ?? transaction['offered_price'] ?? 0;
      final subtitle = isRequester
          ? '$partnerName accepted your request "$requestTitle"'
          : 'You accepted the request "$requestTitle"';

      return CirclNotification(
        id: 'transaction_${transaction['id']}',
        title: 'Request Accepted 🎉',
        subtitle: amount > 0 ? '$subtitle (LKR ${amount.toStringAsFixed(0)})' : subtitle,
        type: NotificationType.requestAccepted,
        timestamp: transaction['updated_at'] != null
            ? DateTime.parse(transaction['updated_at'] as String)
            : DateTime.now(),
        isRead: transaction['is_read'] ?? false,
        metadata: {
          'transaction_id': transaction['id'],
          'request_id': transaction['request_id'],
          'status': status,
          'partner_name': partnerName,
          'amount': amount,
        },
        icon: Icons.thumb_up_outlined,
        color: const Color(0xFF26A69A),
      );
    } else if (status == 'offer_sent') {
      final amount = transaction['offered_price'] ?? 0;
      final subtitle = isRequester
          ? 'You sent an offer for "$requestTitle"'
          : '$partnerName sent an offer for "$requestTitle"';

      return CirclNotification(
        id: 'transaction_${transaction['id']}',
        title: 'New Offer 📤',
        subtitle: amount > 0 ? '$subtitle (LKR ${amount.toStringAsFixed(0)})' : subtitle,
        type: NotificationType.offerSent,
        timestamp: transaction['updated_at'] != null
            ? DateTime.parse(transaction['updated_at'] as String)
            : DateTime.now(),
        isRead: transaction['is_read'] ?? false,
        metadata: {
          'transaction_id': transaction['id'],
          'request_id': transaction['request_id'],
          'status': status,
          'partner_name': partnerName,
          'amount': amount,
        },
        icon: Icons.mail_outline,
        color: Colors.blue,
      );
    } else if (status == 'payment_pending') {
      final amount = transaction['agreed_price'] ?? transaction['offered_price'] ?? 0;
      final subtitle = isRequester
          ? 'Payment required for "$requestTitle"'
          : 'Waiting for payment for "$requestTitle"';

      return CirclNotification(
        id: 'transaction_${transaction['id']}',
        title: 'Payment Pending 💳',
        subtitle: amount > 0 ? '$subtitle (LKR ${amount.toStringAsFixed(0)})' : subtitle,
        type: NotificationType.transactionComplete,
        timestamp: transaction['updated_at'] != null
            ? DateTime.parse(transaction['updated_at'] as String)
            : DateTime.now(),
        isRead: transaction['is_read'] ?? false,
        metadata: {
          'transaction_id': transaction['id'],
          'request_id': transaction['request_id'],
          'status': status,
          'amount': amount,
        },
        icon: Icons.payment_rounded,
        color: const Color(0xFFE74C3C),
      );
    } else if (status == 'payment_held') {
      final amount = transaction['agreed_price'] ?? transaction['offered_price'] ?? 0;
      final deposit = transaction['agreed_deposit'] ?? transaction['offered_deposit'] ?? 0;
      final subtitle = isRequester
          ? 'Payment held for "$requestTitle"'
          : 'Payment held for "$requestTitle"';

      return CirclNotification(
        id: 'transaction_${transaction['id']}',
        title: 'Payment Held 💰',
        subtitle: amount > 0 ? '$subtitle (LKR ${amount.toStringAsFixed(0)})' : subtitle,
        type: NotificationType.transactionComplete,
        timestamp: transaction['updated_at'] != null
            ? DateTime.parse(transaction['updated_at'] as String)
            : DateTime.now(),
        isRead: transaction['is_read'] ?? false,
        metadata: {
          'transaction_id': transaction['id'],
          'request_id': transaction['request_id'],
          'status': status,
          'amount': amount,
          'deposit': deposit,
        },
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFFF9800),
      );
    } else if (status == 'in_progress') {
      final subtitle = isRequester
          ? '$partnerName is working on "$requestTitle"'
          : 'You are working on "$requestTitle"';

      return CirclNotification(
        id: 'transaction_${transaction['id']}',
        title: 'In Progress 🔄',
        subtitle: subtitle,
        type: NotificationType.transactionComplete,
        timestamp: transaction['updated_at'] != null
            ? DateTime.parse(transaction['updated_at'] as String)
            : DateTime.now(),
        isRead: transaction['is_read'] ?? false,
        metadata: {
          'transaction_id': transaction['id'],
          'request_id': transaction['request_id'],
          'status': status,
          'partner_name': partnerName,
        },
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFF3498DB),
      );
    } else if (status == 'negotiating') {
      final subtitle = 'Negotiating with $partnerName for "$requestTitle"';

      return CirclNotification(
        id: 'transaction_${transaction['id']}',
        title: 'Negotiating 🤝',
        subtitle: subtitle,
        type: NotificationType.requestAccepted,
        timestamp: transaction['updated_at'] != null
            ? DateTime.parse(transaction['updated_at'] as String)
            : DateTime.now(),
        isRead: transaction['is_read'] ?? false,
        metadata: {
          'transaction_id': transaction['id'],
          'request_id': transaction['request_id'],
          'status': status,
          'partner_name': partnerName,
        },
        icon: Icons.chat_rounded,
        color: const Color(0xFF9B59B6),
      );
    }

    return null;
  }

  Future<bool> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      debugPrint('📬 Marking all notifications as read for user: $userId');

      await _supabase
          .from('transactions')
          .update({'is_read': true})
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .eq('is_read', false);

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      debugPrint('✅ All notifications marked as read');
      return true;

    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      return false;
    }
  }

  Future<bool> clearAllNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      debugPrint('🗑️ Clearing all notifications for user: $userId');

      await _supabase
          .from('transactions')
          .delete()
          .or('requester_id.eq.$userId,provider_id.eq.$userId');

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);

      debugPrint('✅ All notifications cleared');
      return true;

    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
      return false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      if (notificationId.startsWith('transaction_')) {
        final transactionId = notificationId.replaceFirst('transaction_', '');
        await _supabase
            .from('transactions')
            .update({'is_read': true})
            .eq('id', transactionId);
        debugPrint('✅ Marked transaction $transactionId as read');
      }
      else if (notificationId.startsWith('notif_')) {
        final notifId = notificationId.replaceFirst('notif_', '');
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notifId);
        debugPrint('✅ Marked notification $notifId as read');
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      int count = 0;

      final transactionsResult = await _supabase
          .from('transactions')
          .select('id')
          .or('requester_id.eq.$userId,provider_id.eq.$userId')
          .eq('is_read', false);

      count += transactionsResult.length;

      final notificationsResult = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      count += notificationsResult.length;

      debugPrint('📬 Unread notifications: $count');
      return count;

    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('📬 Created notification for user $userId: $title');
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  NotificationType _parseNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'transaction_complete':
        return NotificationType.transactionComplete;
      case 'request_accepted':
        return NotificationType.requestAccepted;
      case 'offer_sent':
        return NotificationType.offerSent;
      default:
        return NotificationType.transactionComplete;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'transaction_complete':
        return Icons.check_circle_outline;
      case 'request_accepted':
        return Icons.thumb_up_outlined;
      case 'offer_sent':
        return Icons.mail_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'transaction_complete':
        return const Color(0xFF26A69A);
      case 'request_accepted':
        return const Color(0xFF26A69A);
      case 'offer_sent':
        return Colors.blue;
      default:
        return const Color(0xFF26A69A);
    }
  }

  @Deprecated('Use clearAllNotifications() instead')
  Future<void> clearAllNotificationsLegacy() async {
    await clearAllNotifications();
  }
}
