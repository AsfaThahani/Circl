import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/chat_detail_screen.dart';
import '../services/transaction_service.dart';

class RequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onTap;
  final bool isExpanded;
  final VoidCallback? onAccept;

  const RequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.isExpanded = false,
    this.onAccept,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _isAccepting = false;
  final TransactionService _transactionService = TransactionService();

  bool _isOwnRequest() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return widget.request['requester_id'] == currentUserId;
  }
  String _getDurationDisplay() {
    if (widget.request['duration'] != null && widget.request['duration'].toString().isNotEmpty) {
      return widget.request['duration'].toString();
    }
    final durationValue = widget.request['duration_value'];
    final durationUnit = widget.request['duration_unit'];
    
    if (durationValue != null && durationUnit != null) {
      final value = durationValue is int ? durationValue : int.tryParse(durationValue.toString()) ?? 0;
      final unit = durationUnit.toString();
      
      if (value == 1) {
        String singularUnit = unit.substring(0, unit.length - 1);
        return '$value $singularUnit';
      }
      return '$value $unit';
    }
    
    return '';
  }

  Future<void> _acceptRequest(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      _showSnackBar('You must be logged in to accept requests');
      return;
    }

    setState(() => _isAccepting = true);

    try {
      final isAvailable = await _checkRequestAvailability();
      if (!isAvailable) {
        _showSnackBar('This request is no longer available');
        widget.onAccept?.call();
        return;
      }

      final requestType = widget.request['type'] ?? 'borrow';
      final durationValue = widget.request['duration_value'];
      final durationUnit = widget.request['duration_unit'];
      final minPrice = widget.request['min_price']?.toString() ?? '?';
      final maxPrice = widget.request['max_price']?.toString() ?? '?';
      final minDeposit = widget.request['min_deposit']?.toString() ?? '?';
      final maxDeposit = widget.request['max_deposit']?.toString() ?? '?';
      final transaction = await _transactionService.createTransaction(
        requestId: widget.request['id'],
        requesterId: widget.request['requester_id'],
        providerId: currentUser.id,
        amount: 0, // Will be set during negotiation
        depositAmount: null,
        requestType: requestType,
        durationValue: durationValue is int ? durationValue : (durationValue as int?) ?? 1,
        durationUnit: durationUnit?.toString() ?? 'days',
      );
      await supabase.from('requests').update({
        'status': 'negotiating',
        'is_available': false,
      }).eq('id', widget.request['id']);

      widget.onAccept?.call();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            transactionId: transaction['id'],
            name: widget.request['user'] ?? 'User',
            requestTitle: widget.request['title'] ?? 'Request',
            requestType: requestType,
            transactionStatus: 'negotiating',
            requestData: widget.request, // Pass ranges for negotiation
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to accept request: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  Future<bool> _checkRequestAvailability() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('requests')
        .select('id, status, is_available')
        .eq('id', widget.request['id'])
        .maybeSingle();

    if (response == null) return false;
    return response['status'] == 'open' && response['is_available'] == true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color bgColor;
    Color textColor;
    String label;
    switch (type) {
      case 'borrow':
        bgColor = const Color(0xFFE1F5EE);
        textColor = const Color(0xFF085041);
        label = 'Free Borrow';
        break;
      case 'rent':
        bgColor = const Color(0xFFFAEEDA);
        textColor = const Color(0xFF633806);
        label = 'Paid Rent';
        break;
      case 'favour':
        bgColor = const Color(0xFFEEEDFE);
        textColor = const Color(0xFF26215C);
        label = 'Free Favour';
        break;
      case 'paid':
        bgColor = const Color(0xFFFAECE7);
        textColor = const Color(0xFF4A1B0C);
        label = 'Paid Task';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey;
        label = type;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.request['type'] ?? 'borrow';
    final title = widget.request['title'] ?? 'Untitled';
    final description = widget.request['description'] ?? '';
    final distance = widget.request['distance'] ?? '? km';
    final rating = widget.request['rating'] ?? 4.0;
    final user = widget.request['user'] ?? 'Unknown';
    final isBest = widget.request['isBest'] ?? false;
    final isExpanded = widget.isExpanded;
    final durationText = _getDurationDisplay();
    
    final minPrice = widget.request['min_price']?.toString() ?? '';
    final maxPrice = widget.request['max_price']?.toString() ?? '';
    final minDeposit = widget.request['min_deposit']?.toString() ?? '';
    final maxDeposit = widget.request['max_deposit']?.toString() ?? '';

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded
                ? const Color(0xFF1D9E75)
                : isBest
                    ? const Color(0xFFEF9F27)
                    : const Color(0xFFE8E6DF),
            width: isExpanded ? 2.0 : (isBest ? 1.5 : 0.5),
          ),
          boxShadow: isExpanded
              ? [BoxShadow(color: const Color(0xFF1D9E75).withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBest)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF9F27),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('⭐ Best Match', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                _buildTypeBadge(type),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(user, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(width: 8),
                ...List.generate(5, (i) => Icon(
                    i < (rating.floor()) ? Icons.star : Icons.star_border,
                    size: 10,
                    color: const Color(0xFFEF9F27))),
                const SizedBox(width: 4),
                Text(rating.toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                Text(distance, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
              ],
            ),
            if (durationText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 10, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    durationText,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            
            if (type == 'rent' && minPrice.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.currency_rupee, size: 12, color: Color(0xFFD85A30)),
                      const SizedBox(width: 2),
                      Text('LKR $minPrice - $maxPrice/day', 
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFD85A30))),
                    ],
                  ),
                  if (minDeposit.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 2),
                        Text('Deposit LKR $minDeposit - $maxDeposit',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                ],
              ),
            ],
            
            if (type == 'paid' && maxPrice.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 12, color: Color(0xFFD85A30)),
                  const SizedBox(width: 2),
                  Text('Up to LKR $maxPrice total', 
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFD85A30))),
                ],
              ),
            ],
            
            if (type == 'borrow' && maxDeposit.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.security_rounded, size: 12, color: Color(0xFFD85A30)),
                  const SizedBox(width: 2),
                  Text('Deposit up to LKR $maxDeposit',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFD85A30))),
                ],
              ),
            ],
            
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        if (description.isNotEmpty) ...[
                          Text(
                            description,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _isOwnRequest()
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D9E75).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text(
                                    '📌 This is your request',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75)),
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isAccepting ? null : () => _acceptRequest(context),
                                  icon: _isAccepting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.chat_rounded, size: 16),
                                  label: Text(
                                    _isAccepting ? 'Accepting...' : 'Accept & Chat',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1D9E75),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}