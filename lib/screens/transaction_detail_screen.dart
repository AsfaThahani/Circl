import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/transaction_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final int transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final TransactionService _transactionService = TransactionService();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _transaction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    try {
      final transaction = await _transactionService.getTransactionDetails(widget.transactionId);
      if (mounted) {
        setState(() {
          _transaction = transaction;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transaction: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'negotiating': return '💬';
      case 'offer_sent': return '📝';
      case 'payment_pending': return '⏳';
      case 'in_progress': return '🔄';
      case 'completed': return '✅';
      case 'disputed': return '⚠️';
      case 'cancelled': return '❌';
      default: return '📋';
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'negotiating': return 'Negotiating';
      case 'offer_sent': return 'Offer Sent';
      case 'payment_pending': return 'Awaiting Payment';
      case 'in_progress': return 'Transaction in Progress';
      case 'completed': return 'Transaction Completed';
      case 'disputed': return 'Under Review';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'negotiating': return Colors.orange;
      case 'offer_sent': return Colors.blue;
      case 'payment_pending': return Colors.orange;
      case 'in_progress': return const Color(0xFF1D9E75);
      case 'completed': return Colors.green;
      case 'disputed': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1D9E75))),
      );
    }
    
    if (_transaction == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Transaction Details'),
          backgroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('Transaction not found'),
            ],
          ),
        ),
      );
    }
    
    final isRequester = _transaction!['requester_id'] == currentUserId;
    final otherUser = isRequester ? _transaction!['provider'] : _transaction!['requester'];
    final otherUserName = otherUser?['username'] ?? 'User';
    final request = _transaction!['request'];
    final status = _transaction!['status'] ?? 'pending';
    final timeline = _transaction!['timeline'] as List? ?? [];
    final requesterConfirmed = _transaction!['requester_confirmed'] ?? false;
    final providerConfirmed = _transaction!['provider_confirmed'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Transaction Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getStatusColor(status).withValues(alpha: 0.1),
                    const Color(0xFF090133).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    _getStatusIcon(status),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getStatusMessage(status),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transaction #${widget.transactionId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            if (status == 'in_progress')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completion Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildConfirmationRow('Requester', requesterConfirmed),
                    const SizedBox(height: 8),
                    _buildConfirmationRow('Provider', providerConfirmed),
                    if (requesterConfirmed && providerConfirmed)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Both parties have confirmed completion!',
                                style: TextStyle(fontSize: 12, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Title', request?['title'] ?? 'N/A'),
                  _buildDetailRow('Type', _getTypeLabel(request?['type'] ?? 'borrow')),
                  _buildDetailRow('Description', request?['description'] ?? 'No description'),
                  if (_transaction!['agreed_price'] != null && _transaction!['agreed_price'] > 0)
                    _buildDetailRow('Agreed Price', 'LKR ${(_transaction!['agreed_price'] as num).toStringAsFixed(2)}'),
                  if (_transaction!['agreed_deposit'] != null && _transaction!['agreed_deposit'] > 0)
                    _buildDetailRow('Deposit', 'LKR ${(_transaction!['agreed_deposit'] as num).toStringAsFixed(2)} (Refundable)'),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Participants',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildUserRow('Requester', _transaction!['requester']),
                  const SizedBox(height: 12),
                  _buildUserRow('Provider', _transaction!['provider']),
                ],
              ),
            ),

            const SizedBox(height: 20),
            if (timeline.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timeline',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...timeline.map((entry) => _buildTimelineEntry(entry)),
                  ],
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationRow(String role, bool confirmed) {
    return Row(
      children: [
        Icon(
          confirmed ? Icons.check_circle : Icons.pending_outlined,
          size: 18,
          color: confirmed ? Colors.green : Colors.grey.shade400,
        ),
        const SizedBox(width: 12),
        Text(
          role,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          confirmed ? 'Confirmed' : 'Pending',
          style: TextStyle(
            fontSize: 12,
            color: confirmed ? Colors.green : Colors.grey.shade500,
            fontWeight: confirmed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(String role, Map<String, dynamic>? user) {
    final username = user?['username'] ?? 'Unknown';
    final auraLevel = user?['aura_level'] ?? 'Bronze';
    final rating = (user?['rating'] as num?)?.toDouble() ?? 0.0;
    
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1D9E75).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D9E75)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Icon(Icons.star, size: 10, color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            auraLevel,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineEntry(Map<String, dynamic> entry) {
    final date = DateTime.tryParse(entry['created_at'] ?? '');
    final formattedDate = date != null
        ? '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'Unknown date';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1D9E75),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusLabel(entry['status']),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (entry['notes'] != null)
                  Text(
                    entry['notes'],
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'negotiating': return 'Negotiation Started';
      case 'offer_sent': return 'Offer Sent';
      case 'offer_accepted': return 'Offer Accepted';
      case 'payment_pending': return 'Payment Pending';
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'disputed': return 'Dispute Raised';
      case 'deposit_refunded': return 'Deposit Refunded';
      case 'return_confirmed': return 'Return Confirmed';
      case 'requester_confirmed': return 'Requester Confirmed';
      case 'provider_confirmed': return 'Provider Confirmed';
      case 'cancelled': return 'Cancelled';
      default: return status ?? 'Update';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'borrow': return 'Free Borrow';
      case 'rent': return 'Paid Rent';
      case 'favour': return 'Free Favour';
      case 'paid': return 'Paid Task';
      default: return type;
    }
  }
}