import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../widgets/aura_avatar.dart';
import '../services/transaction_service.dart';
import '../screens/payment_screen.dart';
import '../services/ledger_service.dart';
import '../widgets/negotiation_sheet.dart';

const Color kTealColor = Color(0xFF26A69A);

DateTime _parseSupabaseTimestamp(dynamic timestamp) {
  if (timestamp == null) return DateTime.now();
  final dateString = timestamp.toString();
  if (dateString.isEmpty) return DateTime.now();
  try {
    return DateTime.parse(dateString).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

Color getAuraColor(String? level) {
  final normalized = (level ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'platinum':
      return const Color(0xFFE5E4E2);
    case 'gold':
      return const Color(0xFFFFD700);
    case 'silver':
      return const Color(0xFFC0C0C0);
    case 'bronze':
      return const Color(0xFFCD7F32);
    default:
      return const Color(0xFFCD7F32);
  }
}

String resolveAvatarUrl(dynamic value, {String fallback = ''}) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return fallback;
  
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }
  
  try {
    final supabase = Supabase.instance.client;
    if (raw.startsWith('storage/') || raw.startsWith('/storage/')) {
      final path = raw.replaceFirst('storage/', '').replaceFirst('/storage/', '');
      return supabase.storage.from('avatars').getPublicUrl(path);
    }
    
    if (!raw.contains('/')) {
      return supabase.storage.from('avatars').getPublicUrl(raw);
    }
    
    return supabase.storage.from('avatars').getPublicUrl(raw);
  } catch (_) {
    return raw;
  }
}

class ChatDetailScreen extends StatefulWidget {
  final int transactionId;
  final String name;
  final String? username;
  final String requestTitle;
  final String requestType;
  final String transactionStatus;
  final Map<String, dynamic>? requestData;
  final String? avatarUrl;
  final String? auraLevel;
  final double? rating;

  const ChatDetailScreen({
    super.key,
    required this.transactionId,
    required this.name,
    this.username,
    required this.requestTitle,
    this.requestType = 'borrow',
    this.transactionStatus = 'active',
    this.requestData,
    this.avatarUrl,
    this.auraLevel,
    this.rating,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final TransactionService _transactionService = TransactionService();
  final LedgerService _ledgerService = LedgerService();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isAttaching = false;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  StreamSubscription<List<Map<String, dynamic>>>? _transactionSubscription;

  bool _isProvider = false;
  double _offeredTotalPrice = 0;
  double _offeredDeposit = 0;
  String _offerStatus = 'none';
  String _transactionStatus = 'negotiating';

  bool _requesterConfirmed = false;
  bool _providerConfirmed = false;

  double _maxTotalBudget = 0;
  double _minDeposit = 0;
  double _maxDeposit = 0;
  
  List<Map<String, dynamic>> _negotiationHistory = [];
  
  int _agreedDurationValue = 1;
  String _agreedDurationUnit = 'days';
  
  DateTime? _paymentTime;
  Timer? _gracePeriodTimer;
  bool _showGracePeriodWarning = false;
  int _gracePeriodSecondsRemaining = 3600;

  bool _isPaymentDone = false;
  String _paymentStatus = '';

  bool _isOfferCardMinimized = false;
  String _otherUserName = '';
  Color _otherUserAuraColor = kTealColor;
  String _otherUserAuraLevel = 'bronze';
  String? _otherUserAvatarUrl;
  double? _otherUserRating;

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

  List<Map<String, dynamic>> _parseHistory(dynamic data) {
    if (data == null) return [];
    try {
      if (data is List) {
        return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (e) {
      debugPrint('Error parsing negotiation history: $e');
    }
    return [];
  }

  String _getDurationDisplay(int value, String unit) {
    if (value == 1) {
      String singularUnit = unit.substring(0, unit.length - 1);
      return '$value $singularUnit';
    }
    return '$value $unit';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTimeAgoDetail(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final date = _parseSupabaseTimestamp(timestamp);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _getDateHeader(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final date = _parseSupabaseTimestamp(timestamp);
      final now = DateTime.now();
      
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Today';
      }
      
      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
        return 'Yesterday';
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  bool _isDateChanged(String? prevTimestamp, String? currTimestamp) {
    if (prevTimestamp == null || currTimestamp == null) return true;
    try {
      final prevDate = _parseSupabaseTimestamp(prevTimestamp);
      final currDate = _parseSupabaseTimestamp(currTimestamp);
      return prevDate.year != currDate.year || prevDate.month != currDate.month || prevDate.day != currDate.day;
    } catch (_) {
      return true;
    }
  }

  bool _isCounterOffer(Map<String, dynamic> proposal) {
    final history = _negotiationHistory;
    final proposalId = proposal['id']?.toString() ?? '';
    
    if (history.length >= 2) {
      final index = history.indexWhere((p) => p['id'] == proposalId);
      if (index > 0) {
        final previousProposal = history[index - 1];
        if (previousProposal['sender_id'] != proposal['sender_id']) {
          return true;
        }
      }
    }
    
    return proposal['counter_to'] != null;
  }

  Future<bool> _hasUserReviewed(String userId) async {
    try {
      final result = await _supabase
          .from('reviews')
          .select('id')
          .eq('transaction_id', widget.transactionId)
          .eq('reviewer_id', userId)
          .maybeSingle();
      
      return result != null;
    } catch (e) {
      debugPrint('Error checking review status: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _transactionStatus = widget.transactionStatus;
    _otherUserName = widget.name.isNotEmpty ? widget.name : 'User';
    _otherUserAuraLevel = widget.auraLevel ?? 'bronze';
    _otherUserAuraColor = getAuraColor(_otherUserAuraLevel);
    _otherUserAvatarUrl = widget.avatarUrl;
    _otherUserRating = widget.rating;
    
    debugPrint('📱 ChatDetailScreen INIT - Data received:');
    debugPrint('  👤 Name: ${widget.name}');
    debugPrint('  👤 Username: ${widget.username ?? 'not provided'}');
    debugPrint('  🖼️ Avatar URL: ${widget.avatarUrl}');
    debugPrint('  💫 Aura Level: ${widget.auraLevel}');
    debugPrint('  ⭐ Rating: ${widget.rating}');
    debugPrint('  📝 Stored Avatar URL: $_otherUserAvatarUrl');
    if (_otherUserAvatarUrl == null || _otherUserAvatarUrl!.isEmpty) {
      debugPrint('⚠️ Avatar URL is empty, will try to load from transaction');
      _loadOtherUserDataFromTransaction();
    }
    
    _loadRanges();
    _checkUserRole();
    _loadOfferStatus();
    _loadConfirmationStatus();
    _loadNegotiationHistory();
    _loadPaymentTime();
    _checkPaymentStatus();
    _subscribeToMessages();
    _subscribeToTransactionChanges();
    _checkIfRatingNeededOnLoad();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _transactionSubscription?.cancel();
    _gracePeriodTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherUserDataFromTransaction() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;
      
      final transaction = await _supabase
          .from('transactions')
          .select('''
            requester:profiles!transactions_requester_id_fkey(
              id, username, name, avatar_url, profile_picture_url, aura_level, rating
            ),
            provider:profiles!transactions_provider_id_fkey(
              id, username, name, avatar_url, profile_picture_url, aura_level, rating
            )
          ''')
          .eq('id', widget.transactionId)
          .maybeSingle();
      
      if (transaction != null && mounted) {
        final isRequester = transaction['requester_id'] == currentUserId;
        final otherUser = isRequester ? transaction['provider'] : transaction['requester'];
        
        if (otherUser != null) {
          final avatarUrl = otherUser['avatar_url'] ?? 
                           otherUser['profile_picture_url'];
          final auraLevel = otherUser['aura_level'] ?? 'bronze';
          
          debugPrint('📱 Loaded user data from transaction:');
          debugPrint('  🖼️ Avatar URL: $avatarUrl');
          debugPrint('  💫 Aura Level: $auraLevel');
          
          setState(() {
            if (_otherUserAvatarUrl == null || _otherUserAvatarUrl!.isEmpty) {
              _otherUserAvatarUrl = avatarUrl;
            }
            if (_otherUserAuraLevel.isEmpty || _otherUserAuraLevel == 'bronze') {
              _otherUserAuraLevel = auraLevel;
              _otherUserAuraColor = getAuraColor(auraLevel);
            }
            if (_otherUserName.isEmpty || _otherUserName == 'User') {
              _otherUserName = otherUser['username'] ?? otherUser['name'] ?? 'User';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user data from transaction: $e');
    }
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final transaction = await _supabase
          .from('transactions')
          .select('status, paid_at, payment_status')
          .eq('id', widget.transactionId)
          .maybeSingle();
      
      if (transaction != null && mounted) {
        final status = transaction['status']?.toString() ?? '';
        final paymentStatus = transaction['payment_status']?.toString() ?? '';
        final bool hasPaid = transaction['paid_at'] != null;
        
        setState(() {
          _isPaymentDone = (status == 'payment_held' || status == 'in_progress' || status == 'completed') || hasPaid;
          _paymentStatus = paymentStatus;
          
          if (paymentStatus == 'completed' || paymentStatus == 'payment_held') {
            _isPaymentDone = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
    }
  }

  Future<void> _sendSystemEvent(String text) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    final messageContent = jsonEncode({
      'type': 'system_event',
      'text': text,
    });
    
    try {
      await _chatService.sendMessage(widget.transactionId, currentUserId, messageContent);
    } catch (e) {
      debugPrint('Error sending system event: $e');
    }
  }

  Future<void> _acceptPostedTerms() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final data = widget.requestData ?? {};
      final totalBudget = _toDouble(data['max_price'] ?? data['price']);
      final durationValue = _toInt(data['duration_value']);
      final durationUnit = data['duration_unit']?.toString() ?? 'days';
      final deposit = _toDouble(data['max_deposit'] ?? data['deposit']);

      await _sendNegotiationProposal(
        totalBudget,
        deposit,
        durationValue,
        durationUnit,
        "I agree to your posted terms. Let me know if you'd like to proceed with me!",
      );

    } catch (e) {
      if (mounted) _showSnackBar("Error accepting terms: $e");
    }
  }

  void _showWalletAudit() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view wallet')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: _loadWalletData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: kTealColor),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          }

          final data = snapshot.data!;
          final balance = data['balance'] as double? ?? 0.0;
          final transactions = data['transactions'] as List<Map<String, dynamic>>? ?? [];
          final income = data['income'] as double? ?? 0.0;
          final spent = data['spent'] as double? ?? 0.0;

          return Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: kTealColor),
                    const SizedBox(width: 12),
                    Text(
                      'Wallet Audit',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.fromARGB(255, 90, 239, 192), Color(0xFF0F766E)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Available Balance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'LKR ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.trending_up, color: Colors.green, size: 20),
                            const SizedBox(height: 4),
                            const Text('Income',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Text('LKR ${income.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.trending_down, color: Colors.red, size: 20),
                            const SizedBox(height: 4),
                            const Text('Spent',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Text('LKR ${spent.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600, 
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: transactions.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions yet',
                            style: TextStyle(color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: transactions.length > 10 ? 10 : transactions.length,
                          separatorBuilder: (_, _) => Divider(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
                          ),
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            final isIncome = t['provider_id'] == userId;
                            final rawAmount = t['agreed_price'] ?? t['offered_price'] ?? t['deposit_amount'] ?? 0.0;
                            final amount = double.tryParse(rawAmount.toString()) ?? 0.0;
                            final date = t['created_at'] != null
                                ? _parseSupabaseTimestamp(t['created_at'])
                                : DateTime.now();
                            
                            final statusStr = t['status']?.toString() ?? 'Unknown';
                            final formattedStatus = statusStr.toString().replaceAll('_', ' ');
                            final capitalizedStatus = formattedStatus.isNotEmpty 
                                ? '${formattedStatus[0].toUpperCase()}${formattedStatus.substring(1)}'
                                : '';
                            
                            final description = isIncome ? 'Earnings ($capitalizedStatus)' : 'Payment ($capitalizedStatus)';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isIncome
                                          ? (isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4))
                                          : (isDark ? const Color(0xFF2C0A0A) : const Color(0xFFFEF2F2)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 16,
                                      color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600, 
                                            fontSize: 13, 
                                            color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 11, 
                                            color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? '+' : '-'}LKR ${amount.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Close', 
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF475569), 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadWalletData(String userId) async {
    final balance = await _ledgerService.getBalance(userId);
    
    final transactionsResult = await _supabase
        .from('transactions')
        .select()
        .or('requester_id.eq.$userId,provider_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(50);
    
    final transactions = List<Map<String, dynamic>>.from(transactionsResult);
    
    double income = 0.0;
    double spent = 0.0;
    
    for (var t in transactions) {
      final isIncome = t['provider_id'] == userId;
      final rawAmount = t['agreed_price'] ?? t['offered_price'] ?? t['deposit_amount'] ?? 0.0;
      final amount = double.tryParse(rawAmount.toString()) ?? 0.0;
      
      final status = t['status']?.toString() ?? '';
      if (status == 'completed' || status == 'accepted' || status == 'payment_pending') {
        if (isIncome) {
          income += amount;
        } else {
          spent += amount;
        }
      }
    }
    
    return {
      'balance': balance,
      'transactions': transactions,
      'income': income,
      'spent': spent,
    };
  }

  Future<void> _loadRanges() async {
    if (widget.requestData != null) {
      setState(() {
        _maxTotalBudget = _toDouble(widget.requestData!['max_price'] ?? widget.requestData!['price']);
        _minDeposit = _toDouble(widget.requestData!['min_deposit'] ?? widget.requestData!['deposit']);
        _maxDeposit = _toDouble(widget.requestData!['max_deposit']);
        
        if (widget.requestType == 'paid' && _maxTotalBudget == 0) {
          _maxTotalBudget = 1000;
        }
        if (widget.requestType == 'rent' && _minDeposit == 0 && _maxDeposit == 0) {
          _minDeposit = 0;
          _maxDeposit = 5000;
        }
      });
    }
  }

  Future<void> _checkUserRole() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final transaction = await _supabase
        .from('transactions')
        .select('provider_id, requester_id')
        .eq('id', widget.transactionId)
        .single();
    
    if (mounted) {
      setState(() {
        _isProvider = transaction['provider_id'] == currentUserId;
      });
    }
  }

  Future<void> _loadOfferStatus() async {
    final transaction = await _supabase
        .from('transactions')
        .select('offer_status, offered_price, offered_deposit, status')
        .eq('id', widget.transactionId)
        .maybeSingle();
    
    if (transaction != null && mounted) {
      setState(() {
        _offerStatus = transaction['offer_status'] ?? 'none';
        _offeredTotalPrice = _toDouble(transaction['offered_price']);
        _offeredDeposit = _toDouble(transaction['offered_deposit']);
        _transactionStatus = transaction['status'] ?? 'negotiating';
      });
    }
  }

  Future<void> _loadConfirmationStatus() async {
    final status = await _transactionService.getConfirmationStatus(widget.transactionId);
    if (mounted) {
      setState(() {
        _requesterConfirmed = status['requester_confirmed'] ?? false;
        _providerConfirmed = status['provider_confirmed'] ?? false;
      });
    }
  }

  Future<void> _loadNegotiationHistory() async {
    try {
      final transaction = await _supabase
          .from('transactions')
          .select('negotiation_history, agreed_duration_value, agreed_duration_unit')
          .eq('id', widget.transactionId)
          .maybeSingle();
      
      if (transaction != null && mounted) {
        setState(() {
          _negotiationHistory = _parseHistory(transaction['negotiation_history']);
          
          if (transaction['agreed_duration_value'] != null) {
            _agreedDurationValue = transaction['agreed_duration_value'];
          }
          if (transaction['agreed_duration_unit'] != null) {
            _agreedDurationUnit = transaction['agreed_duration_unit'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading negotiation history: $e');
    }
  }

  void _subscribeToTransactionChanges() {
    _transactionSubscription = _supabase
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('id', widget.transactionId)
        .listen((List<Map<String, dynamic>> data) async {
          if (data.isNotEmpty && mounted) {
            final transaction = data.first;
            final oldStatus = _transactionStatus;
            
            setState(() {
              _offerStatus = transaction['offer_status'] ?? 'none';
              _transactionStatus = transaction['status'] ?? 'negotiating';
              _offeredTotalPrice = _toDouble(transaction['offered_price']);
              _offeredDeposit = _toDouble(transaction['offered_deposit']);
              _requesterConfirmed = transaction['requester_confirmed'] ?? false;
              _providerConfirmed = transaction['provider_confirmed'] ?? false;
              
              final String status = transaction['status'] ?? '';
              final paymentStatus = transaction['payment_status']?.toString() ?? '';
              _isPaymentDone = (status == 'payment_held' || status == 'in_progress' || status == 'completed') || 
                               transaction['paid_at'] != null ||
                               paymentStatus == 'completed' ||
                               paymentStatus == 'payment_held';
              _paymentStatus = paymentStatus;
              
              if (transaction['agreed_duration_value'] != null) {
                _agreedDurationValue = transaction['agreed_duration_value'];
              }
              if (transaction['agreed_duration_unit'] != null) {
                _agreedDurationUnit = transaction['agreed_duration_unit'];
              }

              _negotiationHistory = _parseHistory(transaction['negotiation_history']);
            });
            if (_transactionStatus == 'completed' && oldStatus != 'completed') {
              final currentUserId = _supabase.auth.currentUser?.id;
              if (currentUserId != null) {
                final hasReviewed = await _hasUserReviewed(currentUserId);
                if (!hasReviewed && mounted) {
                  Future.delayed(const Duration(milliseconds: 600), () {
                    if (mounted) _showRatingDialog();
                  });
                }
              }
            }
          }
        });
  }

  Future<void> _checkIfRatingNeededOnLoad() async {
    if (_transactionStatus == 'completed') {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        final hasReviewed = await _hasUserReviewed(currentUserId);
        if (!hasReviewed && mounted) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _showRatingDialog();
          });
        }
      }
    }
  }

  void _subscribeToMessages() {
    _subscription?.cancel();
    _subscription = _chatService.subscribeToMessages(
      widget.transactionId,
      (messages) {
        if (!mounted) return;

        final currentUserId = _supabase.auth.currentUser?.id;
        final hasUnread = currentUserId != null && messages.any((msg) {
          final senderId = msg['sender_id']?.toString();
          final readAt = msg['read_at'];
          return senderId != currentUserId && (readAt == null || readAt.toString().isEmpty);
        });

        final bool shouldUpdateState = _isLoading || !_areMessageListsEqual(_messages, messages);

        if (shouldUpdateState) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
        } else if (_isLoading) {
          setState(() {
            _isLoading = false;
          });
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToBottom();
          }
        });

        if (hasUnread) {
          _markMessagesAsRead();
        }
      },
      onError: (error) {
        debugPrint('❌ Error streaming chat messages: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _markMessagesAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _chatService.markMessagesAsRead(widget.transactionId, user.id);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _scrollToBottom() {
    if (!mounted) return; 
    
    try {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {}
  }

  bool _areMessageListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> current,
  ) {
    if (previous.length != current.length) return false;

    for (var i = 0; i < previous.length; i++) {
      final a = previous[i];
      final b = current[i];
      if (a['id'] != b['id'] ||
          a['created_at'] != b['created_at'] ||
          a['read_at'] != b['read_at'] ||
          a['content'] != b['content'] ||
          a['sender_id']?.toString() != b['sender_id']?.toString()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _messageController.clear();

    try {
      await _chatService.sendMessage(widget.transactionId, user.id, content);
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showSnackBar('Failed to send message: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatGracePeriodTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPaymentTime() async {
    try {
      final transaction = await _supabase
          .from('transactions')
          .select('paid_at, agreed_duration_value, agreed_duration_unit')
          .eq('id', widget.transactionId)
          .maybeSingle();
      
      if (transaction != null && transaction['paid_at'] != null && mounted) {
        setState(() {
          _paymentTime = _parseSupabaseTimestamp(transaction['paid_at']);
          _isPaymentDone = true;
          if (transaction['agreed_duration_value'] != null) {
            _agreedDurationValue = transaction['agreed_duration_value'];
          }
          if (transaction['agreed_duration_unit'] != null) {
            _agreedDurationUnit = transaction['agreed_duration_unit'];
          }
        });
        _startGracePeriodTimer();
      }
    } catch (e) {
      debugPrint('Error loading payment time: $e');
    }
  }

  void _startGracePeriodTimer() {
    if (_paymentTime == null) return;
    
    final elapsed = DateTime.now().difference(_paymentTime!).inSeconds;
    final remaining = 3600 - elapsed;
    
    if (remaining > 0 && _transactionStatus == 'payment_pending') {
      setState(() {
        _gracePeriodSecondsRemaining = remaining;
        _showGracePeriodWarning = true;
      });
      
      _gracePeriodTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        final newRemaining = 3600 - DateTime.now().difference(_paymentTime!).inSeconds;
        
        if (newRemaining <= 0) {
          timer.cancel();
          setState(() {
            _showGracePeriodWarning = false;
            _gracePeriodSecondsRemaining = 0;
          });
        } else {
          setState(() {
            _gracePeriodSecondsRemaining = newRemaining;
          });
        }
      });
    }
  }

  Future<void> _handleModifyWithPendingProposal() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Modify Your Proposal?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You already have a pending proposal waiting for the other party\'s response.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF475569)
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What would you like to do?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: kTealColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Withdraw your current proposal and create a new one with modified terms',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B)
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cancel and keep your current proposal as-is',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B)
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, {'action': 'cancel'}),
            child: Text(
              'Keep Current',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                fontWeight: FontWeight.w600
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {'action': 'modify'}),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Modify & Withdraw', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != null && result['action'] == 'modify') {
      final userId = _supabase.auth.currentUser?.id;
      final myProposal = _negotiationHistory.firstWhere(
        (p) => p['sender_id'] == userId && p['status'] == 'pending',
      );
      
      if (mounted) {
        _showSnackBar('Withdrawing your current proposal...');
      }
      
      await _withdrawProposal(myProposal['id'], showSnackBar: false);
      _openNegotiationSheet(mode: 'modify', existingProposal: myProposal);
    }
  }

  void _openNegotiationSheet({String mode = 'propose', Map<String, dynamic>? existingProposal}) {
    String sheetTitle = 'Propose New Terms';
    String actionButtonText = 'Send Proposal';
    
    double refBudget = _maxTotalBudget;
    String budgetLabel = "Requester's Budget";
    
    double refDeposit = _maxDeposit;
    String depositLabel = "Requester's Limit";
    
    int refDurVal = widget.requestData != null ? _toInt(widget.requestData!['duration_value']) : 1;
    String refDurUnit = widget.requestData?['duration_unit']?.toString() ?? 'days';
    String durHelperLabel = "Requested";

    bool isModify = mode == 'modify';
    bool isCounter = mode == 'counter';
    
    bool shouldHideDeposit = _isPaymentDone;

    if (isCounter && existingProposal != null) {
       sheetTitle = 'Counter Offer';
       actionButtonText = 'Send Counter';
       
       refBudget = _toDouble(existingProposal['price']);
       budgetLabel = _isProvider ? "Requester's Offer" : "Provider's Expectation";
       
       refDeposit = _toDouble(existingProposal['deposit']);
       depositLabel = _isProvider ? "Requester's Offer" : "Provider's Expectation";
       
       refDurVal = _toInt(existingProposal['duration_value']);
       refDurUnit = existingProposal['duration_unit']?.toString() ?? 'days';
       durHelperLabel = _isProvider ? "Requester Offered" : "Provider Offered";
       
    } else if (isModify) {
       sheetTitle = 'Modify Terms';
       actionButtonText = 'Update Terms';
       
       if (existingProposal != null) {
         refBudget = _toDouble(existingProposal['price']);
         budgetLabel = "Current Price";
         
         refDeposit = _toDouble(existingProposal['deposit']);
         depositLabel = "Current Deposit";
         
         refDurVal = _toInt(existingProposal['duration_value']);
         refDurUnit = existingProposal['duration_unit']?.toString() ?? 'days';
         durHelperLabel = "Current Duration";
       } else {
         refBudget = _offeredTotalPrice;
         budgetLabel = "Agreed Price";
         
         refDeposit = _offeredDeposit;
         depositLabel = "Agreed Deposit";
         
         refDurVal = _agreedDurationValue;
         refDurUnit = _agreedDurationUnit;
         durHelperLabel = "Agreed Duration";
       }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NegotiationSheet(
        requestType: widget.requestType,
        initialPrice: existingProposal != null 
            ? _toDouble(existingProposal['price']) 
            : _offeredTotalPrice,
        initialDeposit: existingProposal != null 
            ? _toDouble(existingProposal['deposit']) 
            : _offeredDeposit,
        initialDurationValue: existingProposal != null 
            ? _toInt(existingProposal['duration_value']) 
            : _agreedDurationValue,
        initialDurationUnit: existingProposal != null 
            ? existingProposal['duration_unit']?.toString() ?? 'days' 
            : _agreedDurationUnit,
        
        hideDeposit: shouldHideDeposit,
        
        sheetTitle: sheetTitle,
        actionButtonText: actionButtonText,
        budgetLabel: budgetLabel,
        referenceBudget: refBudget,
        depositLabel: depositLabel,
        referenceDeposit: refDeposit,
        durationHelperLabel: durHelperLabel,
        referenceDurationValue: refDurVal,
        referenceDurationUnit: refDurUnit,
        
        onProposalSent: (price, deposit, durationValue, durationUnit, notes) {
          Navigator.pop(ctx);
          _sendNegotiationProposal(price, deposit, durationValue, durationUnit, notes);
        },
      ),
    );
  }

  Future<void> _withdrawProposal(String proposalId, {bool showSnackBar = true}) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final updatedHistory = _negotiationHistory.map((p) {
      if (p['id'] == proposalId && p['status'] == 'pending') {
        return {
          ...p,
          'status': 'withdrawn',
          'withdrawn_at': DateTime.now().toUtc().toIso8601String(),
          'withdrawn_by': currentUserId,
        };
      }
      return p;
    }).toList();

    setState(() {
      _negotiationHistory = updatedHistory;
      _offerStatus = 'none';
    });

    try {
      await _supabase.from('transactions').update({
        'negotiation_history': updatedHistory,
        'offer_status': 'none',
      }).eq('id', widget.transactionId);

      await _sendSystemEvent('You have withdrawn your proposal.');
      
      if (showSnackBar && mounted) _showSnackBar('Proposal withdrawn successfully');
    } catch (e) {
      debugPrint('Error withdrawing proposal: $e');
      if (showSnackBar && mounted) _showSnackBar('Error withdrawing proposal: $e');
    }
  }

  Future<void> _sendNegotiationProposal(double totalPrice, double deposit, int durationValue, String durationUnit, String notes) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    final List<Map<String, dynamic>> updatedHistory = _negotiationHistory.map((p) {
      if (p['status'] == 'pending') {
        return {
          ...p, 
          'status': 'superseded',
          'superseded_at': DateTime.now().toUtc().toIso8601String(),
          'superseded_by': currentUserId,
        };
      }
      return p;
    }).toList();

    final proposal = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender_id': currentUserId,
      'sender_role': _isProvider ? 'provider' : 'requester',
      'price': totalPrice,
      'deposit': deposit,
      'duration_value': durationValue,
      'duration_unit': durationUnit,
      'notes': notes,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    };
    
    final newHistory = [...updatedHistory, proposal];

    setState(() {
      _offeredTotalPrice = totalPrice;
      _offeredDeposit = deposit;
      _agreedDurationValue = durationValue;
      _agreedDurationUnit = durationUnit;
      _offerStatus = 'pending';
      if (_transactionStatus != 'in_progress' && _transactionStatus != 'payment_held') {
        _transactionStatus = 'offer_sent';
      }
      _negotiationHistory = newHistory;
    });

    final supersededProposal = _negotiationHistory.firstWhere(
      (p) => p['status'] == 'superseded' && p['sender_id'] == currentUserId,
      orElse: () => {},
    );
    
    if (supersededProposal.isNotEmpty) {
      await _sendSystemEvent('You have sent a new proposal');
    }

    final messageContent = jsonEncode({
      'type': 'negotiation_proposal',
      'proposal_id': proposal['id'],
      'price': totalPrice,
      'deposit': deposit,
      'duration_value': durationValue,
      'duration_unit': durationUnit,
      'notes': notes,
    });
    
    try {
      await _chatService.sendMessage(widget.transactionId, currentUserId, messageContent);
    } catch (e) {
      debugPrint('Message send error: $e');
    }

    try {
      final updateData = {
        'offered_price': totalPrice,
        'offered_deposit': deposit,
        'offer_status': 'pending',
      };
      if (_transactionStatus != 'in_progress' && _transactionStatus != 'payment_held') {
        updateData['status'] = 'offer_sent';
      }
      await _supabase.from('transactions').update(updateData).eq('id', widget.transactionId);
    } catch (e) {
      debugPrint('Error updating transaction: $e');
    }

    try {
      await _supabase.from('transactions').update({
        'agreed_duration_value': durationValue,
        'agreed_duration_unit': durationUnit,
      }).eq('id', widget.transactionId);
    } catch (e) {
      debugPrint('Error updating duration: $e');
    }

    try {
      await _supabase.from('transactions').update({
        'negotiation_history': newHistory,
      }).eq('id', widget.transactionId);
    } catch (e) {
      debugPrint('Error updating negotiation history: $e');
    }

    if (mounted) {
      _showSnackBar('Proposal sent! Waiting for response.');
    }
  }

  Future<void> _respondToProposal(String proposalId, bool accept, Map<String, dynamic> proposal) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    final double acceptedTotalPrice = _toDouble(proposal['price'] ?? _offeredTotalPrice);
    final double acceptedDeposit = _toDouble(proposal['deposit'] ?? _offeredDeposit);
    final int acceptedDurationValue = _toInt(proposal['duration_value'] ?? _agreedDurationValue);
    final String acceptedDurationUnit = proposal['duration_unit']?.toString() ?? _agreedDurationUnit;

    final updatedHistory = _negotiationHistory.map((p) {
      if (p['id'] == proposalId) {
        return {
          ...p,
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
          'responded_by': currentUserId,
        };
      } else if (p['status'] == 'pending') {
        return {
          ...p,
          'status': 'superseded',
        };
      }
      return p;
    }).toList();

    if (accept) {
      String statusToSet;
      
      final double requesterFeeRate = 0.04;
      final double totalPayable = acceptedTotalPrice + (acceptedTotalPrice * requesterFeeRate) + acceptedDeposit;
      
      if (totalPayable > 0) {
        statusToSet = 'payment_pending';
        if (mounted) setState(() => _transactionStatus = 'payment_pending');
      } else {
        statusToSet = 'in_progress';
        if (mounted) setState(() => _transactionStatus = 'in_progress');
      }
      
      setState(() {
        _offeredTotalPrice = acceptedTotalPrice;
        _offeredDeposit = acceptedDeposit;
        _agreedDurationValue = acceptedDurationValue;
        _agreedDurationUnit = acceptedDurationUnit;
        _offerStatus = 'accepted';
        _negotiationHistory = updatedHistory;
      });

      String systemMessage = 'Terms accepted! Total amount to be paid LKR ${totalPayable.toStringAsFixed(2)}.';
      await _sendSystemEvent(systemMessage);

      try {
        final updateData = {
          'offered_price': acceptedTotalPrice,
          'offered_deposit': acceptedDeposit,
          'agreed_price': acceptedTotalPrice,
          'agreed_deposit': acceptedDeposit,
          'offer_status': 'accepted',
          'status': statusToSet, 
          'terms_agreed_at': DateTime.now().toUtc().toIso8601String(),
          'agreed_duration_value': acceptedDurationValue,
          'agreed_duration_unit': acceptedDurationUnit,
        };
        
        await _supabase.from('transactions').update(updateData).eq('id', widget.transactionId);
      } catch (e) {
        debugPrint('❌ Error updating accepted terms: $e');
        if (mounted) _showSnackBar('Error saving terms: ${e.toString()}');
      }

      try {
        await _supabase.from('transactions').update({
          'negotiation_history': updatedHistory,
        }).eq('id', widget.transactionId);
      } catch (e) {
        debugPrint('Error updating negotiation history: $e');
      }

      if (mounted) _showSnackBar('Terms accepted!');
      
    } else {
      setState(() {
        _negotiationHistory = updatedHistory;
        _offerStatus = 'declined';
      });

      await _sendSystemEvent('You have declined the proposal. Let\'s continue negotiating.');

      try {
        await _supabase.from('transactions').update({
          'negotiation_history': updatedHistory,
          'offer_status': 'declined',
        }).eq('id', widget.transactionId);
      } catch (e) {
        debugPrint('Error declining proposal: $e');
      }

      if (mounted) _showSnackBar('Proposal declined');
    }
  }

  Future<void> _acceptOffer() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    final pendingProposals = _negotiationHistory.where((p) => p['status'] == 'pending').toList();
    
    if (pendingProposals.isNotEmpty) {
      await _respondToProposal(
        pendingProposals.last['id'], 
        true, 
        pendingProposals.last
      );
      return; 
    } 
    
    final double requesterFeeRate = 0.04;
    final double totalPayable = _offeredTotalPrice + (_offeredTotalPrice * requesterFeeRate) + _offeredDeposit;
    
    try {
      String newStatus = _transactionStatus;
      
      if (_transactionStatus != 'in_progress' && _transactionStatus != 'payment_held') {
        newStatus = totalPayable > 0 ? 'payment_pending' : 'in_progress';
      }
      
      final updateData = {
        'agreed_price': _offeredTotalPrice,
        'agreed_deposit': _offeredDeposit,
        'agreed_duration_value': _agreedDurationValue,
        'agreed_duration_unit': _agreedDurationUnit,
        'offer_status': 'accepted',
        'status': newStatus,
        'terms_agreed_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      await _supabase
          .from('transactions')
          .update(updateData)
          .eq('id', widget.transactionId);
      
      if (mounted) {
        setState(() {
          _offerStatus = 'accepted';
          _transactionStatus = newStatus;
        });
      }
    } catch (e) {
      debugPrint('❌ Error accepting offer: $e');
      if (mounted) _showSnackBar('Error accepting offer: $e');
      return;
    }
  }
  
  Future<void> _declineOffer() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Decline Offer', 
          style: TextStyle(color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A))
        ),
        content: Text(
          'Are you sure you want to decline this offer?',
          style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: Text(
              'Cancel', 
              style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B))
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final pendingProposals = _negotiationHistory.where((p) => p['status'] == 'pending').toList();
      if (pendingProposals.isNotEmpty) {
        _respondToProposal(pendingProposals.last['id'], false, pendingProposals.last);
      } else {
        setState(() {
          _offerStatus = 'declined';
        });
        
        await _sendSystemEvent('You have declined the offer. You can continue negotiating.');
        
        try {
          await _supabase.from('transactions').update({
            'offer_status': 'declined',
          }).eq('id', widget.transactionId);
        } catch (e) {
          debugPrint('Error declining offer: $e');
        }
        
        if (mounted) _showSnackBar('Offer declined');
      }
    }
  }

  void _proceedToPayment() {
    final double requesterFeeRate = 0.04;
    double totalAmount = _offeredTotalPrice + (_offeredTotalPrice * requesterFeeRate) + _offeredDeposit;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => PaymentScreen(
          requestId: widget.requestData?['id'] ?? widget.transactionId,
          transactionId: widget.transactionId,
          amount: totalAmount,
          requestTitle: widget.requestTitle,
          paymentType: widget.requestType,
          durationValue: _agreedDurationValue,
          durationUnit: _agreedDurationUnit,
          pricePerUnit: _offeredTotalPrice, 
        ),
      ),
    ).then((_) async {
      await _loadOfferStatus();
      await _checkPaymentStatus();
      
      if (_transactionStatus == 'payment_held' || _transactionStatus == 'in_progress') {
        await _sendSystemEvent('Payment completed. Proceed with the request.');
        setState(() {
          _isPaymentDone = true;
        });
      }
    });
  }

  void _cancelWithinGracePeriod() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order?', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are within the 1-hour grace period. You will receive a 100% refund including deposit.\n\nThis cannot be undone.',
              style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Go Back', 
              style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B))
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel & Refund', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _transactionService.cancelTransaction(widget.transactionId, _supabase.auth.currentUser!.id);
        await _sendSystemEvent('You have cancelled the transaction within grace period. Full refund processed.');
        if (mounted) {
          _showSnackBar('Cancelled! Full refund will be processed.');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error cancelling: $e');
        }
      }
    }
  }

  void _requestCancellation() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? reason;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        String selectedReason = 'Changed my mind';
        final List<String> reasons = [
          'Changed my mind',
          'Found another provider',
          'No longer need this',
          'Other',
        ];
        
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancel Order', 
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your request will be sent to the provider for approval.',
                    style: TextStyle(
                      fontSize: 13, 
                      color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B)
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReason,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded, 
                          color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)
                        ),
                        items: reasons.map((r) => DropdownMenuItem(
                          value: r, 
                          child: Text(
                            r, 
                            style: TextStyle(
                              fontSize: 15, 
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                            )
                          )
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => selectedReason = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            ),
                          ),
                          child: Text(
                            'Go Back', 
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), 
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            reason = selectedReason;
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            ),
                          ),
                          child: const Text('Send Request', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
    
    if (reason != null) {
      final currentUserId = _supabase.auth.currentUser?.id;
      final messageContent = jsonEncode({
        'type': 'cancellation_request',
        'reason': reason,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      
      await _chatService.sendMessage(widget.transactionId, currentUserId!, messageContent);
      
      if (mounted) _showSnackBar('Cancellation request sent.');
    }
  }

  void _providerCancelWithPenalty() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Transaction?', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancelling after payment will result in:',
              style: TextStyle(color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A))
            ),
            const SizedBox(height: 12),
            Text('• Full refund to requester', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))),
            const Text('• LKR 500 penalty deducted from your account', style: TextStyle(fontSize: 13, color: Colors.red)),
            Text('• Your cancellation rate will increase', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))),
            Text('• This affects your Trust Score', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Go Back', 
              style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B))
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Anyway (Pay Penalty)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _transactionService.cancelTransaction(widget.transactionId, _supabase.auth.currentUser!.id);
        await _sendSystemEvent('You have cancelled the transaction. Full refund issued to requester. Penalty applied.');
        if (mounted) {
          _showSnackBar('Transaction cancelled. Penalty will be charged.');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error cancelling: $e');
        }
      }
    }
  }

  void _markAsPickedUp() async {
    await _sendSystemEvent('You have marked the item as picked up.');
    if (mounted) _showSnackBar('Marked as picked up');
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attach File',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what you want to share',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_rounded,
                    label: 'Photo',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _handleAttachImage();
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildAttachmentOption(
                    icon: Icons.file_present_rounded,
                    label: 'Document',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _handleAttachDocument();
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildAttachmentOption(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _handleAttachLocation();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAttachImage() async {
    try {
      setState(() => _isAttaching = true);
      
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image == null) {
        setState(() => _isAttaching = false);
        return;
      }
      
      final File file = File(image.path);
      final String fileName = image.name;
      
      final String base64Image = await _convertFileToBase64(file);
      
      final messageContent = jsonEncode({
        'type': 'attachment',
        'attachment_type': 'image',
        'file_name': fileName,
        'file_size': await file.length(),
        'data': base64Image,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        await _chatService.sendMessage(
          widget.transactionId, 
          currentUserId, 
          messageContent
        );
        _showSnackBar('Image sent successfully');
      }
      
      setState(() => _isAttaching = false);
    } catch (e) {
      setState(() => _isAttaching = false);
      _showSnackBar('Failed to send image: $e');
      debugPrint('Error sending image: $e');
    }
  }

  Future<void> _handleAttachDocument() async {
    try {
      setState(() => _isAttaching = true);
      
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx'],
      );
      
      if (result == null) {
        setState(() => _isAttaching = false);
        return;
      }
      
      final PlatformFile file = result.files.first;
      final String fileName = file.name;
      final int fileSize = file.size;
      
      final File fileObj = File(file.path!);
      final List<int> fileBytes = await fileObj.readAsBytes();
      final String base64File = base64Encode(fileBytes);
      
      final messageContent = jsonEncode({
        'type': 'attachment',
        'attachment_type': 'document',
        'file_name': fileName,
        'file_size': fileSize,
        'file_extension': file.extension ?? 'unknown',
        'data': base64File,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        await _chatService.sendMessage(
          widget.transactionId, 
          currentUserId, 
          messageContent
        );
        _showSnackBar('Document sent successfully');
      }
      
      setState(() => _isAttaching = false);
    } catch (e) {
      setState(() => _isAttaching = false);
      _showSnackBar('Failed to send document: $e');
      debugPrint('Error sending document: $e');
    }
  }

  Future<void> _handleAttachLocation() async {
    try {
      setState(() => _isAttaching = true);
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isAttaching = false);
        _showSnackBar('Please enable location services');
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isAttaching = false);
          _showSnackBar('Location permission denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isAttaching = false);
        _showSnackBar('Location permission permanently denied');
        return;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      final messageContent = jsonEncode({
        'type': 'attachment',
        'attachment_type': 'location',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        await _chatService.sendMessage(
          widget.transactionId, 
          currentUserId, 
          messageContent
        );
        _showSnackBar('Location shared successfully');
      }
      
      setState(() => _isAttaching = false);
    } catch (e) {
      setState(() => _isAttaching = false);
      _showSnackBar('Failed to share location: $e');
      debugPrint('Error sharing location: $e');
    }
  }

  Future<String> _convertFileToBase64(File file) async {
    List<int> fileBytes = await file.readAsBytes();
    return base64Encode(fileBytes);
  }

  PreferredSizeWidget _buildAppBar() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? resolvedAvatarUrl;
    if (_otherUserAvatarUrl != null && _otherUserAvatarUrl!.isNotEmpty) {
      resolvedAvatarUrl = resolveAvatarUrl(_otherUserAvatarUrl);
      debugPrint('📱 Building AppBar with avatar: $resolvedAvatarUrl');
    } else {
      debugPrint('⚠️ No avatar URL available in AppBar');
    }
    
    return AppBar(
      title: Row(
        children: [
          AuraAvatar(
            imageUrl: resolvedAvatarUrl,
            radius: 18,
            auraColor: _otherUserAuraColor,
            backgroundColor: scaffoldBgColor,
            fallbackChild: Text(
              _otherUserName.isNotEmpty ? _otherUserName.substring(0, 1).toUpperCase() : 'U',
              style: TextStyle(
                color: _otherUserAuraColor,
                fontWeight: FontWeight.bold, 
                fontSize: 16
              ),
            ),
            borderWidth: 1.0,
            glowOpacity: 0.16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherUserName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700, 
                    fontSize: 16, 
                    color: textColor
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.requestTitle,
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey.shade500 
                        : const Color(0xFF64748B), 
                    fontWeight: FontWeight.w500
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: textColor,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.account_balance_wallet_rounded, color: kTealColor),
          tooltip: 'View Wallet Audit',
          onPressed: _showWalletAudit,
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
          ),
          onSelected: (value) {
            if (value == 'report') {
              _showReportDialog();
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Report',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          offset: const Offset(0, 40),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          elevation: 4,
        ),
      ],
    );
  }

  Widget _buildDecisionHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingProposals = _negotiationHistory.where((p) => p['status'] == 'pending').toList();
    if (pendingProposals.isNotEmpty) return const SizedBox.shrink();

    if (_isProvider && (_transactionStatus == 'negotiating' || _transactionStatus == 'offer_sent' || _transactionStatus == 'active' || _transactionStatus == 'interested') && _offerStatus != 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200
            )
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Determine the terms of this request:", 
              style: TextStyle(
                fontSize: 12, 
                color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B), 
                fontWeight: FontWeight.w600
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openNegotiationSheet(),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text("Propose Terms", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: kTealColor),
                      foregroundColor: kTealColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acceptPostedTerms,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text("Accept Terms", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTealColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (!_isProvider && _transactionStatus == 'interested') {
      return Container(
        padding: const EdgeInsets.all(12),
        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
        child: Center(
          child: Text(
            "Waiting for provider to propose or accept terms.", 
            style: TextStyle(
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E), 
              fontSize: 13, 
              fontWeight: FontWeight.w600
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), 
            width: 1
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), 
              blurRadius: 12, 
              offset: const Offset(0, 4)
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _isAttaching ? null : _showAttachmentOptions,
              icon: _isAttaching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kTealColor,
                      ),
                    )
                  : Icon(
                      Icons.attach_file_rounded, 
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, 
                      size: 20
                    ),
              splashRadius: 20,
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: _transactionStatus != 'completed' && !_isAttaching,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: _transactionStatus == 'completed' 
                        ? 'Chat is closed' 
                        : (_isAttaching ? 'Attaching...' : 'Type a message...'),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8), 
                      fontSize: 14
                    ),
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Material(
              color: _transactionStatus == 'completed' || _isAttaching
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)) 
                  : kTealColor,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: (_transactionStatus == 'completed' || _isAttaching) ? null : _sendMessage,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    color: (_transactionStatus == 'completed' || _isAttaching)
                        ? (isDark ? Colors.grey.shade600 : Colors.grey.shade500) 
                        : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionableOfferCard({
    required double price,
    required double deposit,
    required int durationValue,
    required String durationUnit,
    required String notes,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    required VoidCallback onCounter,
    required String proposalId,
    required bool isMyProposal,
    bool isCounterOffer = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationDisplay = _getDurationDisplay(durationValue, durationUnit);
    
    final double requesterFeeRate = 0.04;
    final double serviceFee = price * requesterFeeRate;
    final double calculatedTotal = price + serviceFee + deposit;

    bool showDeposit = !_isPaymentDone && deposit > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMyProposal ? Colors.orange.withValues(alpha: 0.1) : _otherUserAuraColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMyProposal ? Icons.hourglass_empty_rounded : Icons.local_offer_rounded,
                    color: isMyProposal ? Colors.orange : _otherUserAuraColor,
                    size: 20
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMyProposal 
                        ? (isCounterOffer ? 'Your Counter Offer (Pending)' : 'Your Pending Proposal')
                        : (isCounterOffer 
                            ? 'Counter Offer from ${widget.name}' 
                            : (_isPaymentDone ? 'Modification Offer' : 'Action Required: New Offer')),
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15, 
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCounterOffer ? Colors.purple.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCounterOffer ? Colors.purple.shade200 : Colors.orange.shade200
                    ),
                  ),
                  child: Text(
                    isCounterOffer ? 'Counter' : (isMyProposal ? 'Waiting...' : 'Pending'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCounterOffer ? Colors.purple.shade700 : Colors.orange.shade700
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isCounterOffer && !isMyProposal) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : Colors.purple.shade200,
                      ),
                    ),
                    child: Text(
                      '↩️ Counter Offer to your proposal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
                
                if (widget.requestType == 'paid' || widget.requestType == 'rent')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Service Price',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B)
                          ),
                        ),
                        Text(
                          'LKR ${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.requestType == 'paid' || widget.requestType == 'rent')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Circl Fee (4%)',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B)
                          ),
                        ),
                        Text(
                          'LKR ${serviceFee.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showDeposit && (widget.requestType == 'borrow' || widget.requestType == 'rent'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Security Deposit',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B)
                          ),
                        ),
                        Text(
                          'LKR ${deposit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                          ),
                        ),
                      ],
                    ),
                  ),
                if (durationValue > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B)
                          ),
                        ),
                        Text(
                          durationDisplay,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                          ),
                        ),
                      ],
                    ),
                  ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
                      ),
                    ),
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                        fontStyle: FontStyle.italic
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Divider(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      !_isPaymentDone && (widget.requestType == 'paid' || widget.requestType == 'rent') ? 'Total Due Today' : 'Total Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                      ),
                    ),
                    Text(
                      'LKR ${calculatedTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: kTealColor
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                if (isMyProposal) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _withdrawProposal(proposalId),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Withdraw',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleModifyWithPendingProposal(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTealColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Modify', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDecline,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              width: 1.5
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTealColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Accept Terms', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: onCounter,
                      style: TextButton.styleFrom(foregroundColor: kTealColor),
                      child: Text(
                        _isPaymentDone ? 'Modify Duration/Price' : 'Make Counter Offer',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageContent(String rawContent, {bool isMe = false}) {
    if (!rawContent.trim().startsWith('{')) return rawContent;

    try {
      final data = jsonDecode(rawContent);
      if (data is Map<String, dynamic>) {
        final type = data['type'];
        
        if (type == 'system_event') {
          return "ℹ️ ${data['text']}";
        } else if (type == 'system_event_dynamic') {
          return "ℹ️ ${isMe ? data['text_me'] : data['text_other']}";
        } else if (type == 'negotiation_proposal') {
          final double price = _toDouble(data['price']);
          final double deposit = _toDouble(data['deposit']);
          final int durationValue = _toInt(data['duration_value']);
          final String durationUnit = data['duration_unit']?.toString() ?? 'days';
          final String notes = data['notes']?.toString() ?? '';

          final String durationDisplay = _getDurationDisplay(durationValue, durationUnit);

          String text = '📝 Negotiation Proposal\n';
          
          if (widget.requestType == 'paid' || widget.requestType == 'rent') {
            text += 'Price: LKR ${price.toStringAsFixed(2)}\n';
          }
          
          text += 'Duration: $durationDisplay';
          
          if (!_isPaymentDone && (widget.requestType == 'borrow' || widget.requestType == 'rent') && deposit > 0) {
            text += '\nSecurity Deposit: LKR ${deposit.toStringAsFixed(2)}';
          }
          
          if (notes.isNotEmpty) text += '\nNotes: $notes';
          
          return text;
        } else if (type == 'cancellation_request') {
          return '🚫 Cancellation Request\nReason: ${data['reason']}';
        } else if (type == 'attachment') {
          final attachmentType = data['attachment_type'] ?? 'file';
          final fileName = data['file_name'] ?? 'Attachment';
          final fileSize = data['file_size'] ?? 0;
          
          switch (attachmentType) {
            case 'image':
              return '📷 Image: $fileName\nSize: ${_formatFileSize(fileSize)}';
            case 'document':
              return '📄 Document: $fileName\nSize: ${_formatFileSize(fileSize)}';
            case 'location':
              final lat = data['latitude']?.toStringAsFixed(4) ?? '0';
              final lng = data['longitude']?.toStringAsFixed(4) ?? '0';
              final address = data['address'] ?? '';
              return '📍 Location Shared\n$address\n($lat, $lng)';
            default:
              return '📎 Attachment: $fileName';
          }
        }
      }
    } catch (_) {}
    return rawContent;
  }

  Widget _buildPostAgreementActions() {
   final isDark = Theme.of(context).brightness == Brightness.dark;
   
   final userId = _supabase.auth.currentUser?.id;
   
   final hasMyPendingProposal = _negotiationHistory.any(
     (p) => p['sender_id'] == userId && p['status'] == 'pending'
   );
   
   if (_transactionStatus != 'in_progress' && 
       _transactionStatus != 'payment_held' && 
       !hasMyPendingProposal) {
     return const SizedBox.shrink();
   }

   final bool bothConfirmed = _requesterConfirmed && _providerConfirmed;
   final bool userConfirmed = _isProvider ? _providerConfirmed : _requesterConfirmed;

   List<Widget> children = [];

   if (!hasMyPendingProposal && (_transactionStatus == 'in_progress' || _transactionStatus == 'payment_held')) {
     children.add(
       ActionChip(
         avatar: Icon(
           Icons.edit_document, 
           size: 14, 
           color: isDark ? Colors.grey.shade400 : const Color(0xFF0F172A)
         ),
         label: Text(
           "Modify Terms",
           style: TextStyle(
             fontSize: 12, 
             fontWeight: FontWeight.w600,
             color: isDark ? Colors.grey.shade400 : const Color(0xFF0F172A)
           )
         ),
         backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
         side: BorderSide.none,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         onPressed: () => _openNegotiationSheet(mode: 'modify'),
       ),
     );
     children.add(const SizedBox(width: 8));
   }

   if (_transactionStatus == 'in_progress' || _transactionStatus == 'payment_held') {
     if (!bothConfirmed) {
       children.add(
         ActionChip(
           avatar: Icon(
             userConfirmed ? Icons.check_circle : Icons.check_circle_outline,
             size: 14,
             color: userConfirmed ? Colors.green : kTealColor,
           ),
           label: Text(
             userConfirmed ? 'Confirmed ✓' : 'Confirm Completion',
             style: TextStyle(
               fontSize: 12,
               fontWeight: FontWeight.w600,
               color: userConfirmed ? Colors.green : kTealColor
             ),
           ),
           backgroundColor: userConfirmed 
               ? Colors.green.withValues(alpha: 0.1)
               : kTealColor.withValues(alpha: 0.1),
           side: BorderSide.none,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           onPressed: userConfirmed ? null : _confirmCompletion,
         ),
       );
       children.add(const SizedBox(width: 8));
     } else {
       children.add(
         ActionChip(
           avatar: const Icon(Icons.check_circle, size: 14, color: Colors.green),
           label: const Text(
             'Completed ✓',
             style: TextStyle(
               fontSize: 12,
               fontWeight: FontWeight.w600,
               color: Colors.green
             ),
           ),
           backgroundColor: Colors.green.withValues(alpha: 0.1),
           side: BorderSide.none,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           onPressed: null,
         ),
       );
       children.add(const SizedBox(width: 8));
     }
   }

   if (_transactionStatus == 'in_progress' || _transactionStatus == 'payment_held') {
     if (!_isProvider) {
       children.add(
         ActionChip(
           avatar: const Icon(Icons.cancel_outlined, size: 14, color: Colors.deepOrange),
           label: Text(
             "Cancel Order",
             style: TextStyle(
               fontSize: 12,
               fontWeight: FontWeight.w600,
               color: isDark ? Colors.deepOrange.shade400 : Colors.deepOrange
             ),
           ),
           backgroundColor: isDark ? const Color(0xFF2C0A0A) : Colors.orange.shade50,
           side: BorderSide.none,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           onPressed: _requestCancellation,
         ),
       );
       children.add(const SizedBox(width: 8));
     }
   }

   if (_isProvider && (_transactionStatus == 'in_progress' || _transactionStatus == 'payment_held')) {
     children.add(
       ActionChip(
         avatar: const Icon(Icons.inventory_2_outlined, size: 14, color: kTealColor),
         label: const Text(
           "Mark Picked Up",
           style: TextStyle(
             fontSize: 12,
             fontWeight: FontWeight.w600,
             color: kTealColor
           ),
         ),
         backgroundColor: kTealColor.withValues(alpha: 0.1),
         side: BorderSide.none,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         onPressed: _markAsPickedUp,
       ),
     );
     children.add(const SizedBox(width: 8));
     children.add(
       ActionChip(
         avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
         label: Text(
           "Cancel (Penalty)",
           style: TextStyle(
             fontSize: 12,
             fontWeight: FontWeight.w600,
             color: isDark ? Colors.red.shade400 : Colors.red
           ),
         ),
         backgroundColor: isDark ? const Color(0xFF2C0A0A) : const Color(0xFFFEF2F2),
         side: BorderSide.none,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         onPressed: _providerCancelWithPenalty,
       ),
     );
     children.add(const SizedBox(width: 8));
   }

   if (children.isNotEmpty && children.last is SizedBox) {
     children.removeLast();
   }

   return Container(
     width: double.infinity,
     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
     color: isDark ? const Color(0xFF0F172A) : Colors.white,
     child: SingleChildScrollView(
       scrollDirection: Axis.horizontal,
       physics: const BouncingScrollPhysics(),
       child: Row(
         children: children,
       ),
     ),
   );
  }

  Future<void> _confirmCompletion() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    bool isFullyCompleted = false;
    String currentUserName = widget.name;
    String myName = 'You';

    try {
      final userProfile = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', currentUserId)
          .maybeSingle();
      
      if (userProfile != null && userProfile['username'] != null) {
        myName = userProfile['username'].toString();
      }

      final updateData = <String, dynamic>{};

      if (_isProvider) {
        updateData['provider_confirmed'] = true;
        if (_requesterConfirmed) {
          updateData['status'] = 'completed';
          updateData['completed_at'] = DateTime.now().toUtc().toIso8601String();
          isFullyCompleted = true;
        }
      } else {
        updateData['requester_confirmed'] = true;
        if (_providerConfirmed) {
          updateData['status'] = 'completed';
          updateData['completed_at'] = DateTime.now().toUtc().toIso8601String();
          isFullyCompleted = true;
        }
      }

      await _supabase
          .from('transactions')
          .update(updateData)
          .eq('id', widget.transactionId);
     

      setState(() {
        if (_isProvider) {
          _providerConfirmed = true;
        } else {
          _requesterConfirmed = true;
        }
        if (isFullyCompleted) {
          _transactionStatus = 'completed';
        }
      });

      if (isFullyCompleted) {
        await _sendSystemEvent('🎉 Both parties have confirmed! The transaction is now complete.');
        
        final transaction = await _supabase
            .from('transactions')
            .select('provider_id')
            .eq('id', widget.transactionId)
            .single();
            
        final providerId = transaction['provider_id'];
        final bool isFreeFavour = (widget.requestType == 'borrow' || widget.requestType == 'favour') && _offeredTotalPrice == 0;
        
        await onTaskCompleted(
          userId: providerId, 
          isFreeFavour: isFreeFavour
        );
        
      } else {
        final dynamicEvent = jsonEncode({
          'type': 'system_event_dynamic',
          'text_me': '✅ You have confirmed completion. Waiting for the other party.',
          'text_other': '✅ $myName has confirmed completion. Please confirm to complete the transaction.',
        });
        await _chatService.sendMessage(widget.transactionId, currentUserId, dynamicEvent);
      }

      if (mounted) {
        _showSnackBar(isFullyCompleted ? 'Transaction marked as completed!' : 'Confirmation submitted.');
        
        if (isFullyCompleted) {
          final hasReviewed = await _hasUserReviewed(currentUserId);
          
          if (!hasReviewed) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                _showRatingDialog();
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error confirming completion: $e');
      if (mounted) _showSnackBar('Error saving confirmation: $e');
    }
  }

  void _showRatingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    double rating = 0;
    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kTealColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            color: kTealColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Rate Your Experience',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'How was your experience with ${widget.name}?',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setDialogState(() {
                              rating = starIndex.toDouble();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: Icon(
                              starIndex <= rating ? Icons.star : Icons.star_border,
                              color: starIndex <= rating 
                                  ? const Color(0xFFF59E0B) 
                                  : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                              size: 38, 
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rating > 0 ? '${rating.toStringAsFixed(0)} ★' : 'Tap a star to rate',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: rating > 0 
                            ? const Color(0xFFF59E0B) 
                            : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Share your experience (optional)',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kTealColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _submitRating(0, '');
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: rating == 0 ? null : () {
                              Navigator.pop(context);
                              _submitRating(rating, reviewController.text.trim());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: rating > 0 ? kTealColor : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                              foregroundColor: rating > 0 ? Colors.white : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Submit',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _submitRating(double rating, String review) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final existingReview = await _supabase
          .from('reviews')
          .select('id')
          .eq('transaction_id', widget.transactionId)
          .eq('reviewer_id', user.id)
          .maybeSingle();

      if (existingReview != null) {
        if (mounted) {
          _showSnackBar('You have already reviewed this transaction.');
        }
        return;
      }

      final transaction = await _supabase
          .from('transactions')
          .select('requester_id, provider_id')
          .eq('id', widget.transactionId)
          .single();

      final otherUserId = transaction['requester_id'] == user.id 
          ? transaction['provider_id'] 
          : transaction['requester_id'];

      if (rating > 0) {
        final intRating = rating.round();
        
        await _supabase.from('reviews').insert({
          'reviewer_id': user.id,
          'reviewee_id': otherUserId,
          'transaction_id': widget.transactionId,
          'rating': intRating,
          'comment': review,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          final allReviews = await _supabase
              .from('reviews')
              .select('reviewer_id')
              .eq('transaction_id', widget.transactionId);
          
          if (allReviews.length >= 2) {
            _showSnackBar('🎉 Both parties have reviewed! Thank you!');
          } else {
            _showSnackBar('Thank you for your review! ⭐');
          }
        }
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      if (mounted) {
        _showSnackBar('Failed to submit review: $e');
      }
    }
  }

  void _showReportDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? selectedReason;
    final TextEditingController descriptionController = TextEditingController();
    
    final List<String> reportReasons = [
      'Spam or Scam',
      'Harassment or Abuse',
      'Inappropriate Content',
      'Fake Profile',
      'Suspicious Activity',
      'Other',
    ];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            color: Colors.red.shade400,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Report User',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reporting @${widget.name}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      'Reason for Report',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          isExpanded: true,
                          hint: Text(
                            'Select a reason',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                            ),
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                          ),
                          items: reportReasons.map((reason) {
                            return DropdownMenuItem<String>(
                              value: reason,
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setSheetState(() {
                              selectedReason = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      'Additional Details (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Provide more context about your report...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C0A0A) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.red.shade400,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Reports are reviewed by our team. False reports may result in action against your account.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.red.shade300 : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedReason == null ? null : () {
                              Navigator.pop(context);
                              _submitReport(selectedReason!, descriptionController.text.trim());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedReason == null 
                                  ? (isDark ? const Color(0xFF334155) : Colors.grey.shade300)
                                  : Colors.red,
                              foregroundColor: selectedReason == null 
                                  ? (isDark ? Colors.grey.shade500 : Colors.grey.shade600)
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Submit Report',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitReport(String reason, String description) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showSnackBar('Please log in to report');
        return;
      }

      final transaction = await _supabase
          .from('transactions')
          .select('requester_id, provider_id')
          .eq('id', widget.transactionId)
          .single();

      final otherUserId = transaction['requester_id'] == user.id 
          ? transaction['provider_id'] 
          : transaction['requester_id'];

      await _supabase.from('reports').insert({
        'reporter_id': user.id,
        'reported_user_id': otherUserId,
        'transaction_id': widget.transactionId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnackBar('Report submitted successfully. We\'ll review it shortly.');
      }
    } catch (e) {
      debugPrint('Error submitting report: $e');
      if (mounted) {
        _showSnackBar('Failed to submit report: $e');
      }
    }
  }
  Future<void> onTaskCompleted({required String userId, required bool isFreeFavour}) async {
    try {
      final response = await _supabase.rpc(
        'complete_request',
        params: {
          'target_user_id': userId,
          'is_free_favour': isFreeFavour,
        },
      );

      final newPoints = response['new_points'];
      final newTier = response['new_tier'];
      final earned = response['earned'];

      debugPrint('Task complete! Earned $earned points. Total: $newPoints ($newTier)');
    } catch (e) {
      debugPrint('Error completing request points RPC: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBgColor = theme.scaffoldBackgroundColor;

    final userId = _supabase.auth.currentUser?.id;
    final pendingProposals = _negotiationHistory.where((p) => p['status'] == 'pending').toList();
    final hasPendingNegotiation = pendingProposals.isNotEmpty;

    Map<String, dynamic>? latestProposal;
    if (hasPendingNegotiation) {
      latestProposal = pendingProposals.last;
    }

    double getProposalCardHeight() {
      if (_isOfferCardMinimized) return 60;
      
      final isCounter = latestProposal != null && _isCounterOffer(latestProposal);
      final hasNotes = latestProposal != null && 
          (latestProposal['notes']?.toString() ?? '').isNotEmpty;
      
      double height = 400;
      
      if (isCounter) {
        height += 100;
      }
      
      if (hasNotes) {
        height += 50;
      }
      
      if (widget.requestType == 'borrow' || widget.requestType == 'rent') {
        height += 40;
      }
      
      return height;
    }

    final double cardHeight = getProposalCardHeight();
    final double topOffset = 5.0;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              if (!_isProvider && _showGracePeriodWarning && _transactionStatus == 'payment_pending')
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFD97706)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grace period: ${_formatGracePeriodTime(_gracePeriodSecondsRemaining)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14, 
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cancel within 1 hour for 100% refund', 
                              style: TextStyle(
                                fontSize: 12, 
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _cancelWithinGracePeriod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel & Refund', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              
              _buildDecisionHeader(),
              
              if (!_isProvider && (_transactionStatus == 'terms_agreed' || _transactionStatus == 'payment_pending'))
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBFDBFE)
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payment_rounded, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 12),
                          Text(
                            'Payment Required', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16, 
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Terms agreed! Please complete the payment to continue.', 
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF475569)
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _proceedToPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTealColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Proceed to Payment', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: kTealColor))
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: hasPendingNegotiation ? 60 : 16,
                          bottom: 100,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          final message = _messages[index];
                          final isMe = message['sender_id'] == _supabase.auth.currentUser?.id;
                          
                          bool showDateHeader = false;
                          if (index == 0) {
                            showDateHeader = true;
                          } else {
                            final prevMessage = _messages[index - 1];
                            showDateHeader = _isDateChanged(prevMessage['created_at']?.toString(), message['created_at']?.toString());
                          }
                          
                          final formattedText = _formatMessageContent(message['content']?.toString() ?? '', isMe: isMe);
                          final isSystemEvent = formattedText.startsWith("ℹ️");
                          
                          return Column(
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), 
                                      borderRadius: BorderRadius.circular(12)
                                    ),
                                    child: Text(
                                      _getDateHeader(message['created_at']?.toString()),
                                      style: TextStyle(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.w500, 
                                        color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B)
                                      ),
                                    ),
                                  ),
                                ),
                              
                              if (isSystemEvent)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Center(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF451A03) : Colors.amber.shade50, 
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF78350F) : Colors.amber.shade200, 
                                          width: 0.5
                                        ),
                                      ),
                                      child: Text(
                                        formattedText, 
                                        style: TextStyle(
                                          fontSize: 12, 
                                          fontStyle: FontStyle.normal,
                                          color: isDark ? const Color(0xFFFBBF24) : const Color.fromARGB(255, 218, 98, 23),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end, 
                                    children: [
                                      Flexible(
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isMe ? kTealColor : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                formattedText, 
                                                style: TextStyle(
                                                  color: isMe ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)), 
                                                  fontSize: 14
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatTimeAgoDetail(message['created_at']?.toString()),
                                                style: TextStyle(
                                                  fontSize: 11, 
                                                  color: isMe ? Colors.white70 : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8))
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              
              if (_transactionStatus == 'completed')
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0)
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Transaction completed successfully', 
                          style: TextStyle(
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A), 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildPostAgreementActions(),
              
              _buildMessageInput(),
            ],
          ),

          if (hasPendingNegotiation && latestProposal != null)
            Positioned(
              top: topOffset,
              left: 16,
              right: 16,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 4 && _isOfferCardMinimized) {
                    HapticFeedback.lightImpact();
                    setState(() => _isOfferCardMinimized = false);
                  } else if (details.delta.dy < -4 && !_isOfferCardMinimized) {
                    HapticFeedback.lightImpact();
                    setState(() => _isOfferCardMinimized = true);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      if (!_isOfferCardMinimized)
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildActionableOfferCard(
                              price: _toDouble(latestProposal['price']),
                              deposit: _toDouble(latestProposal['deposit']),
                              durationValue: _toInt(latestProposal['duration_value']),
                              durationUnit: latestProposal['duration_unit']?.toString() ?? 'days',
                              notes: latestProposal['notes']?.toString() ?? '',
                              proposalId: latestProposal['id'],
                              isMyProposal: latestProposal['sender_id'] == userId,
                              isCounterOffer: _isCounterOffer(latestProposal),
                              onAccept: latestProposal['sender_id'] != userId ? _acceptOffer : () {},
                              onDecline: latestProposal['sender_id'] != userId ? _declineOffer : () {},
                              onCounter: latestProposal['sender_id'] != userId 
                                  ? () => _openNegotiationSheet(mode: 'counter', existingProposal: latestProposal)
                                  : () {},
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: latestProposal['sender_id'] == userId 
                                      ? Colors.orange.withValues(alpha: 0.1) 
                                      : _otherUserAuraColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  latestProposal['sender_id'] == userId 
                                      ? Icons.hourglass_empty_rounded 
                                      : Icons.local_offer_rounded,
                                  color: latestProposal['sender_id'] == userId ? Colors.orange : _otherUserAuraColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  latestProposal['sender_id'] == userId 
                                      ? 'Your Pending Proposal' 
                                      : (_isPaymentDone ? 'Modification Offer' : 'Action Required: New Offer'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isCounterOffer(latestProposal) 
                                      ? Colors.purple.shade50 
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _isCounterOffer(latestProposal) 
                                        ? Colors.purple.shade200 
                                        : Colors.orange.shade200
                                  ),
                                ),
                                child: Text(
                                  _isCounterOffer(latestProposal) ? 'Counter' : 'Waiting...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _isCounterOffer(latestProposal) 
                                        ? Colors.purple.shade700 
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isOfferCardMinimized = !_isOfferCardMinimized);
                        },
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}