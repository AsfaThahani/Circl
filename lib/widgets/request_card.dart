import 'package:flutter/material.dart' hide Text;
import 'tamil_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/chat_detail_screen.dart' as chat_detail_screen;
import '../services/request_service.dart';
import '../screens/request_detail_screen.dart';
import 'aura_avatar.dart' as aura_avatar;

class RequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final bool isOwn;

  const RequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.onAccept,
    this.isOwn = false,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _isAccepting = false;
  final RequestService _requestService = RequestService();

  Future<void> _acceptRequest(BuildContext context) async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      _showSnackBar('You must be logged in to chat');
      return;
    }

    setState(() => _isAccepting = true);

    try {
      final dynamic rawId = widget.request['id'];
      if (rawId == null) throw Exception("Error: Request ID is missing.");
      
      final int requestId = rawId is int ? rawId : int.parse(rawId.toString());
      debugPrint("Starting Chat for Request ID: $requestId");

      int? existingTransactionId = await _requestService.getExistingTransaction(
        requestId, 
        currentUser.id
      );
      
      int transactionId;
      
      if (existingTransactionId != null) {
        transactionId = existingTransactionId;
        debugPrint('✅ Using existing transaction: $transactionId');
      } else {
        transactionId = await _requestService.acceptRequestAndCreateTransaction(requestId);
        debugPrint('✅ Created new transaction: $transactionId');
      }
      
      widget.onAccept?.call();

      if (!mounted) return;

      final transaction = await Supabase.instance.client
          .from('transactions')
          .select('status, requester_id, provider_id')
          .eq('id', transactionId)
          .maybeSingle();
      
      if (transaction == null) {
        throw Exception('Transaction creation failed. Please try again.');
      }
      
      String status = transaction['status'] ?? 'negotiating';
      
      final isProvider = transaction['provider_id'] == currentUser.id;
      final otherUserId = isProvider 
          ? transaction['requester_id'] 
          : transaction['provider_id'];
      
      String otherUserName = 'User';
      String otherUserAvatarUrl = '';
      String otherUserAuraLevel = 'bronze';
      
      if (otherUserId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('username, profile_picture_url, aura_level')
            .eq('id', otherUserId)
            .maybeSingle();
        if (profile != null) {
          if (profile['username'] != null) {
            otherUserName = profile['username'];
          }
          if (profile['profile_picture_url'] != null) {
            otherUserAvatarUrl = profile['profile_picture_url'];
          }
          if (profile['aura_level'] != null) {
            otherUserAuraLevel = profile['aura_level']?.toString() ?? 'bronze';
          }
        }
      }

      if (!mounted) return;

      final navigator = Navigator.of(context);
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => chat_detail_screen.ChatDetailScreen(
            transactionId: transactionId,
            name: otherUserName,
            requestTitle: widget.request['title'] ?? 'Request',
            requestType: widget.request['type'] ?? 'borrow',
            transactionStatus: status,
            requestData: widget.request,
            avatarUrl: otherUserAvatarUrl, 
            auraLevel: otherUserAuraLevel, 
          ),
        ),
      );
    } catch (e) {
      debugPrint("Chat Error: $e");
      if (mounted) _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _normalizeAuraLevel(dynamic value) {
    final rawValue = (value ?? '').toString().trim();
    if (rawValue.isEmpty) return 'bronze';

    final normalized = rawValue.toLowerCase();
    if (normalized.contains('platinum')) return 'platinum';
    if (normalized.contains('gold')) return 'gold';
    if (normalized.contains('silver')) return 'silver';
    if (normalized.contains('bronze')) return 'bronze';
    return normalized;
  }

  String _extractAuraLevel(Map<String, dynamic> request) {
    final profileData = request['profiles'];
    final profileMap = profileData is Map ? Map<String, dynamic>.from(profileData) : null;

    return _normalizeAuraLevel(
      profileMap?['aura_level'] ??
      profileMap?['auraLevel'] ??
      request['aura_level'] ??
      request['auraLevel'] ??
      request['aura'] ??
      request['tier'],
    );
  }

  Color _getAuraColor(String auraLevel) {
    switch (auraLevel.toLowerCase()) {
      case 'gold': return const Color(0xFFF59E0B);
      case 'silver': return const Color(0xFF94A3B8);
      case 'platinum': return const Color(0xFF8B5CF6);
      case 'bronze': return const Color(0xFFCD7F32);
      default: return Colors.transparent;
    }
  }

  Widget _buildTypeBadge(String type, bool isDark) {
    Color bgColor, textColor;
    String label;
    
    switch (type.toLowerCase()) {
      case 'borrow':
        bgColor = isDark ? const Color(0xFF065F46) : const Color(0xFF22C55E);
        textColor = Colors.white;
        label = 'Borrow';
        break;
      case 'rent':
        bgColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFF3B82F6);
        textColor = Colors.white;
        label = 'Rent';
        break;
      case 'favour':
        bgColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFF97316);
        textColor = Colors.white;
        label = 'Favour';
        break;
      case 'task':
      case 'paid':
        bgColor = isDark ? const Color(0xFF4C1D95) : const Color(0xFF8B5CF6);
        textColor = Colors.white;
        label = 'Task';
        break;
      default:
        bgColor = isDark ? const Color(0xFF334155) : Colors.grey.shade100;
        textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
        label = type;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getPricingText() {
    final type = widget.request['type']?.toString().toLowerCase() ?? '';
    final maxPrice = widget.request['max_price'];
    final maxDeposit = widget.request['max_deposit'];

    if (type == 'favour') {
      return 'Free';
    } else if (type == 'borrow') {
      return maxDeposit != null && maxDeposit.toString() != '0' 
          ? 'Dep: Rs. ${double.parse(maxDeposit.toString()).toStringAsFixed(0)}' 
          : 'Free';
    } else if (type == 'rent') {
      String priceText = maxPrice != null 
          ? 'Rs. ${double.parse(maxPrice.toString()).toStringAsFixed(0)}' 
          : '';
          
      String depositText = maxDeposit != null && maxDeposit.toString() != '0' 
          ? 'Dep: Rs. ${double.parse(maxDeposit.toString()).toStringAsFixed(0)}' 
          : '';
          
      return [priceText, depositText].where((e) => e.isNotEmpty).join(' | ');
    } else if (type == 'task' || type == 'paid') {
      return maxPrice != null 
          ? 'Max Rs. ${double.parse(maxPrice.toString()).toStringAsFixed(0)}' 
          : 'Paid';
    }
    return '';
  }

  String _getDurationText() {
    final value = widget.request['duration_value'];
    final unit = widget.request['duration_unit']?.toString() ?? '';

    if (value == null || unit.isEmpty) return '';

    final int val = value is int ? value : int.tryParse(value.toString()) ?? 0;
    if (val == 0) return '';
    
    if (val == 1 && unit.endsWith('s')) {
      return '$val ${unit.substring(0, unit.length - 1)}';
    }
    return '$val $unit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    
    final cardBackgroundColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFEFEFC);

    final type = widget.request['type'] ?? 'borrow';
    final title = widget.request['title'] ?? 'Untitled';
    final description = widget.request['description'] ?? '';
    final distance = widget.request['distance'] ?? '? km';
    final profileData = widget.request['profiles'];
    final profileMap = profileData is Map ? Map<String, dynamic>.from(profileData) : null;
    final user = profileMap?['username']?.toString() ?? widget.request['user'] ?? 'Unknown';
    
    String avatarUrl = '';
    final profilePicUrl = profileMap?['profile_picture_url'] ?? 
                         profileMap?['profile_picture_url'] ?? 
                         widget.request['profile_picture_url'] ?? 
                         widget.request['profile_picture_url'];
    
    if (profilePicUrl != null && profilePicUrl.toString().isNotEmpty) {
      avatarUrl = aura_avatar.resolveAvatarUrl(profilePicUrl);
    }
    
    debugPrint('Avatar URL for $user: $avatarUrl');
    
    final isBest = widget.request['isBest'] ?? false;
    final isVerified = profileMap?['verified'] ?? widget.request['isVerified'] ?? true;
    final timeAgo = widget.request['timeAgo'] ?? 'Just now';
    final rating = profileMap?['rating']?.toString() ?? widget.request['rating']?.toString() ?? '5.0';
    final auraLevel = _extractAuraLevel(widget.request);
    final auraColor = _getAuraColor(auraLevel);
    
    final pricingText = _getPricingText();
    final durationText = _getDurationText();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBest 
                ? const Color(0xFFF59E0B) 
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isBest ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeBadge(type, isDark),
                if (isBest) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? const Color(0xFF451A03) 
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "BEST MATCH",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pricingText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: type == 'favour' 
                            ? const Color(0xFF26A69A) 
                            : (isDark ? Colors.grey.shade300 : const Color(0xFF64748B)),
                      ),
                    ),
                    if (durationText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'For $durationText',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                height: 1,
              ),
            ),
            Row(
              children: [
                aura_avatar.AuraAvatar(
                  imageUrl: avatarUrl,
                  radius: 18,
                  auraColor: auraColor,
                  backgroundColor: cardBackgroundColor,
                  fallbackChild: Text(
                    user.isNotEmpty ? user[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  borderWidth: 1.0,
                  glowOpacity: 0.2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF26A69A),
                              size: 14,
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                              ),
                            ),
                            Text(
                              ' • $distance',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                              ),
                            ),
                            Text(
                              ' • $timeAgo',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(width: 8), // Padding buffer so text never overlaps buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 30,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final rawId = widget.request['id'];
                          if (rawId == null) return;
                          
                          final int reqId = rawId is int ? rawId : int.parse(rawId.toString());
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RequestDetailScreen(requestId: reqId),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.visibility_outlined, 
                          size: 14,
                          color: isDark ? Colors.grey.shade300 : Colors.white,
                        ),
                        label: Text(
                          'View',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade300 : Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26A69A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    
                    if (!widget.isOwn) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 90,
                        height: 30,
                        child: ElevatedButton.icon(
                          onPressed: _isAccepting ? null : () => _acceptRequest(context),
                          icon: _isAccepting 
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? Colors.grey.shade300 : Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 13,
                                  color: isDark ? Colors.grey.shade300 : Colors.white,
                                ),
                          label: Text(
                            _isAccepting ? '...' : 'Chat',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade300 : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                            foregroundColor: isDark ? Colors.grey.shade300 : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                          ),
                        ),
                      )
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}