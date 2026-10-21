import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/aura_avatar.dart';

class RequestDetailScreen extends StatefulWidget {
  final int requestId;
  
  const RequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isOwner = false;
  String? _userId;
  
  List<Map<String, dynamic>> _interestedUsers = [];
  List<Map<String, dynamic>> _reviews = [];
  final Color _primaryAccent = const Color(0xFF26A69A); 

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  Future<void> _loadRequestDetails() async {
    try {
      setState(() => _isLoading = true);
      _userId = _supabase.auth.currentUser?.id;
      
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            profiles:requester_id (
              id,
              username,
              profile_picture_url,
              rating,
              aura_level,
              verified,
              location
            )
          ''')
          .eq('id', widget.requestId)
          .maybeSingle();
      
      if (response == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Request not found'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.red.shade700 
                  : Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      setState(() {
        _request = response;
        _profile = response['profiles'] as Map<String, dynamic>?;
        _isOwner = _userId == response['requester_id'];
      });
      await Future.wait([
        if (_isOwner) _loadInterestedUsers(),
        _loadRequesterReviews(response['requester_id']),
      ]);
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      debugPrint('Error loading request details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInterestedUsers() async {
    try {
      final response = await _supabase
          .from('transactions')
          .select('''
            *,
            requester:profiles!transactions_requester_id_fkey (id, username, profile_picture_url, rating, aura_level),
            provider:profiles!transactions_provider_id_fkey (id, username, profile_picture_url, rating, aura_level)
          ''')
          .eq('request_id', widget.requestId)
          .eq('status', 'pending');
      
      setState(() {
        _interestedUsers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading interested users: $e');
    }
  }

  Future<void> _loadRequesterReviews(String requesterId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            rating, 
            comment, 
            created_at,
            reviewer:profiles!reviewer_id (
              id,
              username, 
              profile_picture_url, 
              aura_level,
              profile_picture_url
            )
          ''')
          .eq('reviewee_id', requesterId)
          .order('created_at', ascending: false)
          .limit(5); // Increased limit to give providers better context

      setState(() {
        _reviews = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    }
  }
  Future<void> _updateRequestStatus(String newStatus) async {
     await _supabase.from('requests').update({'status': newStatus}).eq('id', widget.requestId);
     setState(() => _request?['status'] = newStatus);
  }

  Future<void> _deleteRequest() async {
     await _supabase.from('requests').delete().eq('id', widget.requestId);
     if (mounted) Navigator.pop(context, true);
  }

  Future<void> _updateTransactionStatus(int transactionId, String newStatus) async {
     await _supabase.from('transactions').update({'status': newStatus}).eq('id', transactionId);
     await _loadInterestedUsers();
  }
  String _getPriceDisplay() {
    if (_request == null) return 'Free';
    final max = _request?['max_price'];
    if (max == null || max == 0) return 'Free';
    return 'LKR $max';
  }

  String _getDurationDisplay() {
    final value = _request?['duration_value'];
    final unit = _request?['duration_unit']?.toString().toLowerCase() ?? '';
    
    if (value == null) return 'Flexible';
    String unitDisplay = unit;
    if (value == 1) {
      if (unit.endsWith('s')) {
        unitDisplay = unit.substring(0, unit.length - 1);
      }
    }
    
    return '$value $unitDisplay';
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'borrow': return isDark ? const Color(0xFF065F46) : const Color(0xFF22C55E);
      case 'rent': return isDark ? const Color(0xFF1E3A5F) : const Color(0xFF3B82F6);
      case 'favour': return isDark ? const Color(0xFF7C2D12) : const Color(0xFFF97316);
      case 'task':
      case 'paid': return isDark ? const Color(0xFF4C1D95) : const Color(0xFF8B5CF6);
      default: return isDark ? const Color(0xFF334155) : Colors.grey.shade100;
    }
  }

  Color _getTypeTextColor(String type) {
    switch (type.toLowerCase()) {
      case 'borrow':
      case 'rent':
      case 'favour':
      case 'task':
      case 'paid':
        return Colors.white;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'borrow': return 'Borrow';
      case 'rent': return 'Rent';
      case 'favour': return 'Favour';
      case 'task':
      case 'paid': return 'Task';
      default: return type;
    }
  }

  String _resolveAvatarUrl(dynamic value) {
    if (value == null) return '';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    
    try {
      return _supabase.storage.from('avatars').getPublicUrl(raw);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    if (_isLoading || _request == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Center(
          child: CircularProgressIndicator(color: _primaryAccent),
        ),
      );
    }

    final type = _request?['type']?.toString() ?? 'request';
    final status = _request?['status']?.toString() ?? 'open';
    final isClosedOrDone = status != 'open';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Request Details',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        scrolledUnderElevation: 0,
        actions: [
          if (_isOwner && !isClosedOrDone)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteRequest(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeBadge(type, isDark),
            const SizedBox(height: 20),
            Text(
              _request?['title'] ?? 'Untitled',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileCard(isDark),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    Icons.payments_outlined,
                    'Price',
                    _getPriceDisplay(),
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    Icons.timer_outlined,
                    'Duration',
                    _getDurationDisplay(),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              Icons.location_on_outlined,
              'Location',
              _getLocationDisplay(isDark),
              isDark,
              isFullWidth: true,
            ),
            const SizedBox(height: 32),
            Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _request?['description'] ?? 'No description provided.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            if (_reviews.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.reviews_outlined,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Requester Reputation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._reviews.map((review) => _buildReviewCard(review, isDark)),
              const SizedBox(height: 32),
            ] else if (!_isOwner) ...[
              Text(
                'Requester Reputation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'No reviews yet for this user.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (_isOwner && _interestedUsers.isNotEmpty) ...[
              Text(
                'Interested People (${_interestedUsers.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              ..._interestedUsers.map((t) => _buildInterestedUser(t, isDark)),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
      bottomNavigationBar: (_isOwner && !isClosedOrDone) 
          ? _buildBottomBar(isDark) 
          : null,
    );
  }

  Widget _buildTypeBadge(String type, bool isDark) {
    final bgColor = _getTypeColor(type, isDark);
    final textColor = _getTypeTextColor(type);
    final label = _getTypeLabel(type);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getLocationDisplay(bool isDark) {
    final address = _request?['address']?.toString() ?? '';
    final radius = _request?['radius_km']?.toString() ?? '';
    String cleanAddress = address;
    if (address.isNotEmpty) {
      final parts = address.split(',');
      if (parts.length > 1) {
        final firstPart = parts[0].trim();
        final secondPart = parts[1].trim();
        if (firstPart.toLowerCase() == secondPart.toLowerCase()) {
          cleanAddress = parts.skip(1).join(',').trim();
        }
      }
    }
    
    if (cleanAddress.isEmpty && radius.isEmpty) return 'Location not specified';
    if (cleanAddress.isEmpty) return 'Within $radius km';
    if (radius.isEmpty) return cleanAddress;
    return '$cleanAddress (Within $radius km)';
  }

  Widget _buildProfileCard(bool isDark) {
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          AuraAvatar(
            imageUrl: _resolveAvatarUrl(_profile?['profile_picture_url']),
            radius: 24,
            auraColor: getAuraColor(_profile?['aura_level']?.toString()),
            backgroundColor: surfaceColor,
            fallbackChild: Text(
              _profile?['username']?.substring(0, 1).toUpperCase() ?? 'U',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _profile?['username'] ?? 'User',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_profile?['verified'] == true)
                      const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _profile?['rating']?.toStringAsFixed(1) ?? 'New',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    IconData icon,
    String title,
    String value,
    bool isDark, {
    bool isFullWidth = false,
  }) {
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final reviewer = review['reviewer'] as Map<String, dynamic>?;
    final reviewerName = reviewer?['username'] ?? 'User';
    final reviewerAvatar = _resolveAvatarUrl(reviewer?['profile_picture_url'] ?? reviewer?['profile_picture_url']);
    final reviewerAura = reviewer?['aura_level']?.toString();
    final rating = (review['rating'] ?? 0) as int;
    final comment = review['comment'] ?? '';
    
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuraAvatar(
                imageUrl: reviewerAvatar,
                radius: 18,
                auraColor: getAuraColor(reviewerAura),
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                fallbackChild: Text(
                  reviewerName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    if (reviewerAura != null && reviewerAura.isNotEmpty)
                      Text(
                        'Aura: ${reviewerAura[0].toUpperCase()}${reviewerAura.substring(1).toLowerCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtitleColor,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInterestedUser(Map<String, dynamic> transaction, bool isDark) {
    final user = transaction['provider'];
    if (user == null) return const SizedBox.shrink();

    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          AuraAvatar(
            imageUrl: _resolveAvatarUrl(user['profile_picture_url']),
            radius: 20,
            auraColor: getAuraColor(user['aura_level']?.toString()),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            fallbackChild: Text(
              user['username']?.substring(0, 1).toUpperCase() ?? 'U',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                Text(
                  '⭐ ${user['rating']?.toStringAsFixed(1) ?? 'New'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Color(0xFF26A69A), size: 28),
            onPressed: () => _updateTransactionStatus(transaction['id'], 'accepted'),
          ),
          IconButton(
            icon: Icon(
              Icons.cancel,
              color: isDark ? Colors.red.shade400 : Colors.redAccent,
              size: 28,
            ),
            onPressed: () => _updateTransactionStatus(transaction['id'], 'rejected'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => _updateRequestStatus('completed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Mark Complete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}