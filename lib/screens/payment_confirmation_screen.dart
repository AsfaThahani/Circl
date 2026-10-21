import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_detail_screen.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  final int transactionId;
  final double amount;
  final String requestTitle;
  final int? durationValue;
  final String? durationUnit;
  final double? pricePerUnit;

  const PaymentConfirmationScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.requestTitle,
    this.durationValue,
    this.durationUnit,
    this.pricePerUnit,
  });

  Future<Map<String, dynamic>?> _getTransactionDetails() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('transactions')
          .select('''
            *,
            requester:profiles!transactions_requester_id_fkey(
              id,
              username,
              name,
              avatar_url,
              profile_picture_url,
              profile_picture,
              aura_level,
              rating
            ),
            provider:profiles!transactions_provider_id_fkey(
              id,
              username,
              name,
              avatar_url,
              profile_picture_url,
              profile_picture,
              aura_level,
              rating
            ),
            request:requests(
              id,
              title,
              type
            )
          ''')
          .eq('id', transactionId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error getting transaction: $e');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    String? avatarUrl = profile['avatar_url'] ?? 
                        profile['profile_picture_url'] ?? 
                        profile['profile_picture'] ?? 
                        profile['avatar'];
    final username = profile['username'] ?? '';
    final name = profile['name'] ?? username ?? 'User';
    final displayName = name.isNotEmpty ? name : username ?? 'User';

    return {
      'id': profile['id'],
      'username': username,
      'name': name,
      'displayName': displayName,
      'avatar_url': avatarUrl,
      'aura_level': profile['aura_level'] ?? 
                    profile['level'] ?? 
                    'bronze',
      'rating': profile['rating'] ?? 0.0,
    };
  }

  void _navigateToChat(BuildContext context) async {
    try {
      final transaction = await _getTransactionDetails();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      String otherUserName = 'User';
      String otherUserDisplayName = 'User';
      String requestType = 'borrow';
      String? otherUserAvatar;
      String? otherUserAuraLevel;
      double? otherUserRating;

      if (transaction != null) {
        final isRequester = transaction['requester_id'] == currentUserId;
        final otherUser = isRequester ? transaction['provider'] : transaction['requester'];
        final otherUserData = _normalizeProfile(otherUser);
        if (otherUserData != null) {
          otherUserName = otherUserData['username'] ?? 'User';
          otherUserDisplayName = otherUserData['displayName'] ?? otherUserData['name'] ?? otherUserName;
          otherUserAvatar = otherUserData['avatar_url'];
          otherUserAuraLevel = otherUserData['aura_level'];
          otherUserRating = otherUserData['rating'];

          debugPrint('📱 Other user data from payment screen:');
          debugPrint('  👤 Username: $otherUserName');
          debugPrint('  👤 Display Name: $otherUserDisplayName');
          debugPrint('  🖼️ Avatar URL: $otherUserAvatar');
          debugPrint('  💫 Aura Level: $otherUserAuraLevel');
          debugPrint('  ⭐ Rating: $otherUserRating');
        }

        requestType = transaction['request']?['type'] ?? 'borrow';
      } else {
        debugPrint('⚠️ Transaction not found for ID: $transactionId');
      }

      if (context.mounted) {
        final chatKey = ValueKey('chat_${transactionId}_${DateTime.now().millisecondsSinceEpoch}');
        
        debugPrint('🚀 Navigating to chat with:');
        debugPrint('  📝 Name: $otherUserDisplayName');
        debugPrint('  🖼️ Avatar: $otherUserAvatar');
        debugPrint('  💫 Aura: $otherUserAuraLevel');
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              key: chatKey,
              transactionId: transactionId,
              name: otherUserDisplayName,
              username: otherUserName,
              requestTitle: requestTitle,
              requestType: requestType,
              transactionStatus: 'in_progress',
              avatarUrl: otherUserAvatar,
              auraLevel: otherUserAuraLevel,
              rating: otherUserRating,
            ),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      debugPrint('❌ Error navigating to chat: $e');
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              transactionId: transactionId,
              name: 'User',
              requestTitle: requestTitle,
              requestType: 'borrow',
              transactionStatus: 'in_progress',
            ),
          ),
          (route) => route.isFirst,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.green.shade50,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF26A69A).withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 64 * value,
                        color: const Color(0xFF26A69A),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'LKR ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF26A69A),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your payment for "$requestTitle" has been processed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2F1EC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFF26A69A).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Color(0xFF26A69A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The provider has been notified. You can now chat to coordinate the details.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF26A69A),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _navigateToChat(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26A69A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Go to Chat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'You\'ll be redirected to the chat with the provider',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}