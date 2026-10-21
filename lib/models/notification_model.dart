import 'package:flutter/material.dart';

enum NotificationType {
  message,
  requestAccepted,
  review,
  requestNear,
  depositReleased,
  nidVerified,
  badgeUnlocked,
  auraEarned,
  offerSent,
  transactionComplete,
}

class CirclNotification {
  final String id;
  final String title;
  final String subtitle;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final IconData icon;
  final Color color;

  CirclNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
    required this.icon,
    required this.color,
  });

  factory CirclNotification.fromTransaction(Map<String, dynamic> transaction) {
    final status = (transaction['status'] ?? '').toString().toLowerCase();
    final isRequester = transaction['is_requester'] ?? false;
    
    late NotificationType type;
    late String title;
    late String subtitle;
    late IconData icon;
    late Color color;

    if (status == 'completed') {
      type = NotificationType.transactionComplete;
      title = "Task Completed";
      subtitle = isRequester 
          ? "Your request has been completed"
          : "You've completed a request";
      icon = Icons.check_circle_outline;
      color = const Color(0xFF26A69A);
    } else if (status == 'accepted') {
      type = NotificationType.requestAccepted;
      title = "Request Accepted";
      subtitle = "${transaction['partner_name'] ?? 'Someone'} accepted your request";
      icon = Icons.thumb_up_outlined;
      color = const Color(0xFF26A69A);
    } else if (status == 'offer_sent') {
      type = NotificationType.offerSent;
      title = "New Offer";
      subtitle = "${transaction['partner_name'] ?? 'Someone'} sent you an offer";
      icon = Icons.mail_outline;
      color = Colors.blue;
    }

    return CirclNotification(
      id: transaction['id']?.toString() ?? '',
      title: title,
      subtitle: subtitle,
      type: type,
      timestamp: DateTime.tryParse(transaction['updated_at'] ?? '') ?? DateTime.now(),
      isRead: false,
      metadata: transaction,
      icon: icon,
      color: color,
    );
  }

  factory CirclNotification.fromRequest(Map<String, dynamic> request) {
    return CirclNotification(
      id: request['id']?.toString() ?? '',
      title: "New Request Nearby",
      subtitle: "${request['title'] ?? 'New item'} posted ${request['distance_km'] ?? '?'} km away",
      type: NotificationType.requestNear,
      timestamp: DateTime.tryParse(request['created_at'] ?? '') ?? DateTime.now(),
      isRead: false,
      metadata: request,
      icon: Icons.location_on_outlined,
      color: Colors.purple,
    );
  }

  factory CirclNotification.review({
    required String rater,
    required double rating,
    required String review,
    required DateTime timestamp,
  }) {
    return CirclNotification(
      id: '${rater}_${timestamp.millisecondsSinceEpoch}',
      title: "You received a ${rating.toStringAsFixed(1)}★ review",
      subtitle: "$rater: ${review.length > 50 ? '${review.substring(0, 50)}...' : review}",
      type: NotificationType.review,
      timestamp: timestamp,
      isRead: false,
      metadata: {'rater': rater, 'rating': rating, 'review': review},
      icon: Icons.star_outline,
      color: Colors.amber,
    );
  }

  factory CirclNotification.message({
    required String senderName,
    required String message,
    required DateTime timestamp,
  }) {
    return CirclNotification(
      id: '${senderName}_${timestamp.millisecondsSinceEpoch}',
      title: "New message from $senderName",
      subtitle: message.length > 60 ? '${message.substring(0, 60)}...' : message,
      type: NotificationType.message,
      timestamp: timestamp,
      isRead: false,
      metadata: {'sender': senderName, 'message': message},
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFF26A69A),
    );
  }

  factory CirclNotification.depositReleased({
    required double amount,
    required DateTime timestamp,
  }) {
    return CirclNotification(
      id: 'deposit_${timestamp.millisecondsSinceEpoch}',
      title: "Deposit Released",
      subtitle: "₹${amount.toStringAsFixed(2)} returned to your wallet",
      type: NotificationType.depositReleased,
      timestamp: timestamp,
      isRead: false,
      metadata: {'amount': amount},
      icon: Icons.wallet_giftcard_outlined,
      color: Colors.green,
    );
  }

  factory CirclNotification.nidVerified() {
    return CirclNotification(
      id: 'nid_${DateTime.now().millisecondsSinceEpoch}',
      title: "NIC Verified",
      subtitle: "Your identity is now verified",
      type: NotificationType.nidVerified,
      timestamp: DateTime.now(),
      isRead: false,
      icon: Icons.verified_user_outlined,
      color: const Color(0xFF26A69A),
    );
  }

  factory CirclNotification.badgeUnlocked({
    required String badgeName,
    required DateTime timestamp,
  }) {
    return CirclNotification(
      id: 'badge_$badgeName${timestamp.millisecondsSinceEpoch}',
      title: "Badge Unlocked",
      subtitle: "You've earned the $badgeName badge",
      type: NotificationType.badgeUnlocked,
      timestamp: timestamp,
      isRead: false,
      metadata: {'badge': badgeName},
      icon: Icons.emoji_events_outlined,
      color: Colors.amber,
    );
  }

  factory CirclNotification.auraEarned({
    required int amount,
    required String reason,
    required DateTime timestamp,
  }) {
    return CirclNotification(
      id: 'aura_${timestamp.millisecondsSinceEpoch}',
      title: "Earned +$amount Aura",
      subtitle: reason,
      type: NotificationType.auraEarned,
      timestamp: timestamp,
      isRead: false,
      metadata: {'amount': amount, 'reason': reason},
      icon: Icons.favorite_outline,
      color: Colors.pink,
    );
  }
}
