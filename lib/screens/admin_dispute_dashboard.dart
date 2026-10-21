import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../services/nic_verification_service.dart';
import '../services/ledger_service.dart';
import '../services/transaction_service.dart';
import '../screens/login_signup_page.dart';

const Color kTealColor = Color(0xFF26A69A);
const Color kCardDarkColor = Color(0xFF1E293B);
const Color kBorderDarkColor = Color(0xFF334155);
const double kPlatformFeeRate = 0.04;
class DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;

  DonutChartPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = size.width * 0.14;
    final double radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -3.14159265 / 2; // Start from top
    int index = 0;

    data.forEach((key, percentage) {
      if (percentage <= 0) return;
      final sweepAngle = percentage * 2 * 3.14159265;
      paint.color = colors[index % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.05, 
        false,
        paint,
      );
      startAngle += sweepAngle;
      index++;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AdminDisputeDashboard extends StatefulWidget {
  const AdminDisputeDashboard({super.key});

  @override
  State<AdminDisputeDashboard> createState() => _AdminDisputeDashboardState();
}

class _AdminDisputeDashboardState extends State<AdminDisputeDashboard> {
  final _supabase = Supabase.instance.client;
  final _nicService = NICVerificationService();
  final _ledgerService = LedgerService();
  final _transactionService = TransactionService();

  int _selectedTab = 0; 
  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _allDisputes = [];
  List<Map<String, dynamic>> _allNics = [];
  List<Map<String, dynamic>> _allReports = [];
  String _disputeFilter = 'All'; 
  String _nicFilter = 'All';
  String _reportFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      debugPrint('==================== START DATA LOAD ====================');
      try {
        final usersRes = await _supabase.from('profiles').select('*');
        _allUsers = List<Map<String, dynamic>>.from(usersRes);
        debugPrint('✅ Loaded ${_allUsers.length} users');
      } catch (e) {
        debugPrint('Error fetching profiles: $e');
        try {
          final usersRes = await _supabase.from('profiles').select('id');
          _allUsers = List<Map<String, dynamic>>.from(usersRes);
          debugPrint('✅ Loaded ${_allUsers.length} users (fallback)');
        } catch (e2) {
          debugPrint('Error fetching profiles (fallback): $e2');
          _allUsers = [];
        }
      }
      try {
        debugPrint('📊 Fetching transactions with request data...');
        final txsRes = await _supabase.from('transactions').select('''
          *,
          request:requests!transactions_request_id_fkey (
            id,
            title,
            type,
            description
          )
        ''');
        _allTransactions = List<Map<String, dynamic>>.from(txsRes);
        debugPrint('✅ Loaded ${_allTransactions.length} transactions');
        if (_allTransactions.isNotEmpty) {
          debugPrint('🔍 First transaction sample:');
          final sample = _allTransactions[0];
          debugPrint('  Transaction ID: ${sample['id']}');
          debugPrint('  Request ID: ${sample['request_id']}');
          debugPrint('  Status: ${sample['status']}');
          debugPrint('  Has "request" key? ${sample.containsKey('request')}');
          if (sample.containsKey('request')) {
            debugPrint('  Request data: ${sample['request']}');
            if (sample['request'] != null) {
              debugPrint('  Request type: ${sample['request']['type']}');
              debugPrint('  Request title: ${sample['request']['title']}');
            } else {
              debugPrint('  ❌ Request data is null');
            }
          } else {
            debugPrint('  ❌ No "request" key found in transaction');
          }
        }
        final withRequest = _allTransactions.where((t) => 
          t.containsKey('request') && t['request'] != null
        ).length;
        debugPrint('📊 Transactions with request data: $withRequest / ${_allTransactions.length}');
        
      } catch (e) {
        debugPrint('❌ Error fetching transactions: $e');
        _allTransactions = [];
      }
      try {
        final disputesRes = await _supabase.from('disputes').select('''
          *,
          transactions!disputes_transaction_id_fkey (*)
        ''').order('created_at', ascending: false);
        _allDisputes = List<Map<String, dynamic>>.from(disputesRes);
        debugPrint('✅ Loaded ${_allDisputes.length} disputes');
      } catch (e) {
        debugPrint('Error fetching disputes: $e');
        _allDisputes = [];
      }
      try {
        final nicsRes = await _supabase.from('nic_verifications').select('*').order('created_at', ascending: false);
        _allNics = List<Map<String, dynamic>>.from(nicsRes);
        debugPrint('✅ Loaded ${_allNics.length} NIC verifications');
      } catch (e) {
        debugPrint('Error fetching NICs: $e');
        _allNics = [];
      }
      try {
        final reportsRes = await _supabase.from('reports').select('*').order('created_at', ascending: false);
        _allReports = List<Map<String, dynamic>>.from(reportsRes);
        debugPrint('✅ Loaded ${_allReports.length} reports');
      } catch (e) {
        debugPrint('Reports table missing or empty. Skipping: $e');
        _allReports = [];
      }
      _debugTransactionTypes();

      debugPrint('==================== END DATA LOAD ====================');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Admin panel load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _debugTransactionTypes() {
    debugPrint('');
    debugPrint('========== TYPE DEBUG ANALYSIS ==========');
    debugPrint('Total transactions: ${_allTransactions.length}');
    
    if (_allTransactions.isEmpty) {
      debugPrint('⚠️ No transactions found!');
      debugPrint('===========================================');
      return;
    }
    final requestIds = _allTransactions.map((t) => t['request_id']).toSet();
    debugPrint('📋 Unique request IDs in transactions: $requestIds');
    Map<String, int> typeCounts = {};
    int nullTypeCount = 0;
    int emptyTypeCount = 0;
    int noRequestDataCount = 0;
    
    for (var tx in _allTransactions) {
      String type = 'unknown';
      if (tx.containsKey('request') && tx['request'] != null) {
        final request = tx['request'] as Map;
        if (request.containsKey('type')) {
          final typeValue = request['type'];
          if (typeValue != null) {
            type = typeValue.toString().toLowerCase();
            if (type.isEmpty) {
              emptyTypeCount++;
              type = 'empty_string';
            }
          } else {
            nullTypeCount++;
            type = 'null';
          }
        } else {
          type = 'no_type_field';
        }
      } else {
        noRequestDataCount++;
        type = 'no_request_data';
      }
      
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    
    debugPrint('📊 Type distribution:');
    typeCounts.forEach((type, count) {
      debugPrint('  $type: $count');
    });
    
    debugPrint('');
    debugPrint('📌 Summary:');
    debugPrint('  Transactions with no request data: $noRequestDataCount');
    debugPrint('  Transactions with null type: $nullTypeCount');
    debugPrint('  Transactions with empty string type: $emptyTypeCount');
    debugPrint('');
    debugPrint('📝 Sample transactions (first 5):');
    final sampleCount = _allTransactions.length < 5 ? _allTransactions.length : 5;
    for (int i = 0; i < sampleCount; i++) {
      final tx = _allTransactions[i];
      final type = _getTransactionType(tx);
      final requestId = tx['request_id'];
      final hasRequest = tx.containsKey('request') && tx['request'] != null;
      debugPrint('  ${i+1}. Tx #${tx['id']} | Request: $requestId | Has Request: $hasRequest | Type: "$type"');
    }
    
    debugPrint('===========================================');
    debugPrint('');
  }
  String _getUserField(Map<String, dynamic> user, String field, {String fallback = 'User'}) {
    final value = user[field];
    if (value == null) return fallback;
    return value.toString();
  }
  String _getUsername(Map<String, dynamic> user) {
    final fields = ['username', 'full_name', 'name', 'display_name', 'email'];
    for (var field in fields) {
      if (user.containsKey(field) && user[field] != null && user[field].toString().isNotEmpty) {
        return user[field].toString();
      }
    }
    if (user.containsKey('id')) {
      final id = user['id'].toString();
      return id.length > 8 ? 'User_${id.substring(0, 8)}' : 'User_$id';
    }
    
    return 'User';
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginSignupPage(),
            settings: const RouteSettings(name: '/login'),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  Future<void> _showLogoutConfirmation() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text('Are you sure you want to logout from Admin Panel?', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.black87)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
          ),
        ],
      ),
    );
  }
  String _getTransactionType(Map<String, dynamic> transaction) {
    if (transaction['type'] != null && transaction['type'].toString().isNotEmpty) {
      return transaction['type'].toString().toLowerCase();
    }
    if (transaction['request'] != null && transaction['request'] is Map) {
      final request = transaction['request'] as Map;
      if (request['type'] != null && request['type'].toString().isNotEmpty) {
        return request['type'].toString().toLowerCase();
      }
    }
    if (transaction['request'] != null && transaction['request'] is Map) {
      final request = transaction['request'] as Map;
      if (request['title'] != null) {
        final title = request['title'].toString().toLowerCase();
        if (title.contains('borrow') || title.contains('loan') || title.contains('lend')) {
          return 'borrow';
        }
        if (title.contains('rent') || title.contains('rental')) {
          return 'rent';
        }
        if (title.contains('favour') || title.contains('help') || title.contains('assist')) {
          return 'favour';
        }
        if (title.contains('paid') || title.contains('task') || title.contains('job')) {
          return 'paid';
        }
      }
    }
    return '';
  }
  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
  
  double get _totalProfits {
    return _allTransactions.where((t) => t['status'] == 'completed').fold(0.0, (sum, t) {
      final price = _toDouble(t['agreed_price'] ?? t['amount'] ?? t['offered_price']);
      return sum + (price * kPlatformFeeRate);
    });
  }

  double get _totalLossesAndRefunds {
    return _allTransactions.where((t) => t['status'] == 'cancelled').fold(0.0, (sum, t) {
      final price = _toDouble(t['agreed_price'] ?? t['amount'] ?? t['offered_price']);
      final deposit = _toDouble(t['agreed_deposit'] ?? t['deposit_amount'] ?? t['offered_deposit'] ?? t['amount_deposit']);
      return sum + price + deposit;
    });
  }

  int get _activeTxs {
    return _allTransactions.where((t) => ['payment_held', 'in_progress', 'payment_pending'].contains(t['status'])).length;
  }

  List<Map<String, dynamic>> _getMonthlyTrends() {
    List<Map<String, dynamic>> trends = [];
    DateTime now = DateTime.now();
    
    for (int i = 4; i >= 0; i--) {
      DateTime targetMonth = DateTime(now.year, now.month - i);
      String monthLabel = DateFormat('MMM').format(targetMonth);
      
      double monthProfit = _allTransactions.where((t) {
        if (t['status'] != 'completed') return false;
        DateTime? completedAt = DateTime.tryParse(t['completed_at']?.toString() ?? t['created_at'].toString());
        if (completedAt == null) return false;
        return completedAt.year == targetMonth.year && completedAt.month == targetMonth.month;
      }).fold(0.0, (sum, t) => sum + (_toDouble(t['agreed_price'] ?? t['amount'] ?? t['offered_price']) * kPlatformFeeRate));

      trends.add({'label': monthLabel, 'profit': monthProfit});
    }
    return trends;
  }
  
  Future<void> _approveNIC(String userId) async {
    setState(() => _isLoading = true);
    try {
      await _nicService.approveVerification(userId);
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ NIC verified successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectNIC(String userId) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('nic_verifications').update({'verification_status': 'rejected'}).eq('user_id', userId);
      await _supabase.from('profiles').update({'is_nic_verified': false, 'verification_status': 'rejected'}).eq('id', userId);
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ NIC rejected'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveDisputeRelease(int disputeId, int transactionId) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('transactions').update({
        'status': 'completed', 
        'completed_at': DateTime.now().toIso8601String()
      }).eq('id', transactionId);
      
      await _ledgerService.processTransactionCompletion(transactionId);
      
      await _supabase.from('disputes').update({
        'status': 'resolved', 
        'resolved_at': DateTime.now().toIso8601String()
      }).eq('id', disputeId);
      
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Payment released to provider'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveDisputeRefund(int disputeId, int transactionId) async {
    setState(() => _isLoading = true);
    try {
      await _transactionService.releasePayment(transactionId);
      
      await _supabase.from('transactions').update({
        'status': 'cancelled', 
        'cancelled_at': DateTime.now().toIso8601String()
      }).eq('id', transactionId);
      
      await _supabase.from('disputes').update({
        'status': 'resolved', 
        'resolved_at': DateTime.now().toIso8601String()
      }).eq('id', disputeId);
      
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Refund processed successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveReport(int reportId, String status) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('reports').update({'status': status}).eq('id', reportId);
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Report ${status == 'actioned' ? 'actioned' : 'dismissed'}'), 
            backgroundColor: status == 'actioned' ? Colors.orange : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }
  Widget _buildPillFilter({
    required List<String> options,
    required String currentVal,
    required Function(String) onChanged,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: options.map((opt) {
          final isSel = currentVal == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? kTealColor : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSel ? kTealColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  boxShadow: isSel ? [
                    BoxShadow(
                      color: kTealColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ] : [],
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSel ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? kCardDarkColor : Colors.white;
    final borderCol = isDark ? kBorderDarkColor : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: kTealColor, size: 28),
            const SizedBox(width: 8),
            Text(
              'circl admin',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.grey.shade400 : Colors.blueGrey),
            onPressed: _loadAllData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: isDark ? Colors.grey.shade400 : Colors.blueGrey),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _buildBottomNavbar(isDark, cardBg, borderCol),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kTealColor))
          : SafeArea(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  RefreshIndicator(color: kTealColor, onRefresh: _loadAllData, child: _buildOverviewTab(isDark, cardBg, borderCol)),
                  RefreshIndicator(color: kTealColor, onRefresh: _loadAllData, child: _buildNICsTab(isDark, cardBg, borderCol)),
                  RefreshIndicator(color: kTealColor, onRefresh: _loadAllData, child: _buildDisputesTab(isDark, cardBg, borderCol)),
                  RefreshIndicator(color: kTealColor, onRefresh: _loadAllData, child: _buildReportsTab(isDark, cardBg, borderCol)),
                ],
              ),
            ),
    );
  }
  Widget _buildOverviewTab(bool isDark, Color cardBg, Color borderCol) {
    int totalTxs = _allTransactions.isEmpty ? 1 : _allTransactions.length;
    
    debugPrint('');
    debugPrint('========== CHART DATA CALCULATION ==========');
    debugPrint('Total transactions: $totalTxs');
    int borrowCount = _allTransactions.where((t) => _getTransactionType(t) == 'borrow').length;
    int rentCount = _allTransactions.where((t) => _getTransactionType(t) == 'rent').length;
    int favourCount = _allTransactions.where((t) => _getTransactionType(t) == 'favour').length;
    int paidCount = _allTransactions.where((t) => _getTransactionType(t) == 'paid').length;
    int unknownCount = _allTransactions.where((t) => _getTransactionType(t) == '').length;
    
    debugPrint('📊 Raw counts:');
    debugPrint('  Borrow: $borrowCount');
    debugPrint('  Rent: $rentCount');
    debugPrint('  Favour: $favourCount');
    debugPrint('  Paid: $paidCount');
    debugPrint('  Unknown/Empty: $unknownCount');
    
    double borrowPct = borrowCount / totalTxs;
    double rentPct = rentCount / totalTxs;
    double favourPct = favourCount / totalTxs;
    double paidPct = paidCount / totalTxs;
    
    debugPrint('📊 Percentages:');
    debugPrint('  Borrow: ${(borrowPct * 100).toStringAsFixed(1)}%');
    debugPrint('  Rent: ${(rentPct * 100).toStringAsFixed(1)}%');
    debugPrint('  Favour: ${(favourPct * 100).toStringAsFixed(1)}%');
    debugPrint('  Paid: ${(paidPct * 100).toStringAsFixed(1)}%');
    debugPrint('📝 Sample type extraction:');
    final sampleCount = _allTransactions.length < 3 ? _allTransactions.length : 3;
    for (int i = 0; i < sampleCount; i++) {
      final tx = _allTransactions[i];
      final type = _getTransactionType(tx);
      debugPrint('  Tx #${tx['id']} -> Type: "$type"');
      if (tx.containsKey('request') && tx['request'] != null) {
        final req = tx['request'] as Map;
        debugPrint('    Request data: id=${req['id']}, title=${req['title']}, type=${req['type']}');
      } else {
        debugPrint('    ❌ No request data');
      }
    }
    
    debugPrint('=============================================');
    debugPrint('');

    List<Map<String, dynamic>> monthlyData = _getMonthlyTrends();
    double maxMonthlyProfit = monthlyData.fold(0.0, (max, item) => item['profit'] > max ? item['profit'] : max);
    if (maxMonthlyProfit == 0) maxMonthlyProfit = 1; 

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total Commission', 'LKR ${_totalProfits.toStringAsFixed(0)}', Icons.payments_rounded, Colors.green, isDark, cardBg, borderCol)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Refunds Vol.', 'LKR ${_totalLossesAndRefunds.toStringAsFixed(0)}', Icons.money_off_rounded, Colors.red, isDark, cardBg, borderCol)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total Users', '${_allUsers.length}', Icons.people_alt_rounded, Colors.blue, isDark, cardBg, borderCol)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Active Escrows', '$_activeTxs', Icons.lock_clock_rounded, Colors.amber, isDark, cardBg, borderCol)),
            ],
          ),
          const SizedBox(height: 20),

          Text('Platform Commission Trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Earned (Live)', style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontSize: 13)),
                    Text('LKR ${_totalProfits.toStringAsFixed(0)}', style: const TextStyle(color: kTealColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: monthlyData.map((data) {
                      double ratio = data['profit'] / maxMonthlyProfit;
                      return _buildBarCol(
                        data['label'], 
                        ratio, 
                        data['profit'] > 0 ? 'Rs ${(data['profit']/1000).toStringAsFixed(1)}k' : 'Rs 0', 
                        isDark
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Transaction Types Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: DonutChartPainter(
                      data: {'borrow': borrowPct, 'rent': rentPct, 'favour': favourPct, 'paid': paidPct},
                      colors: const [Colors.teal, Colors.blue, Colors.pinkAccent, Colors.amber],
                    ),
                    child: Center(
                      child: Text('${_allTransactions.length}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendDot('Borrow', Colors.teal, borrowPct),
                      const SizedBox(height: 6),
                      _buildLegendDot('Rent', Colors.blue, rentPct),
                      const SizedBox(height: 6),
                      _buildLegendDot('Favour', Colors.pinkAccent, favourPct),
                      const SizedBox(height: 6),
                      _buildLegendDot('Paid Tasks', Colors.amber, paidPct),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  Widget _buildNICsTab(bool isDark, Color cardBg, Color borderCol) {
    final filtered = _allNics.where((nic) {
      final status = nic['verification_status']?.toString().toLowerCase() ?? '';
      if (_nicFilter == 'Pending') return status == 'pending';
      if (_nicFilter == 'Verified') return status == 'verified';
      return true;
    }).toList();

    return Column(
      children: [
        _buildPillFilter(
          options: const ['All', 'Pending', 'Verified'],
          currentVal: _nicFilter,
          onChanged: (val) => setState(() => _nicFilter = val),
          isDark: isDark,
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildPanelEmptyState(Icons.badge_rounded, 'No identity requests found')
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final userId = item['user_id'];
                    final userProfile = _allUsers.firstWhere(
                      (u) => u['id'] == userId,
                      orElse: () => <String, dynamic>{},
                    );
                    final username = _getUsername(userProfile);
                    final email = _getUserField(userProfile, 'email', fallback: 'No email');
                    final status = item['verification_status'] ?? 'pending';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('@$username', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                              _buildStatusIndicator(status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(email, style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontSize: 13)),
                          const SizedBox(height: 16),
                          if (item['temp_image_url'] != null) ...[
                            GestureDetector(
                              onTap: () => _viewNICImage(item['temp_image_url'], isDark),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      item['temp_image_url'],
                                      height: 120, width: double.infinity, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 120, color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                                        child: const Center(child: Icon(Icons.broken_image_rounded)),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                                        SizedBox(width: 6),
                                        Text('Zoom Identity Card', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (status == 'pending') ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _rejectNIC(item['user_id']),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _approveNIC(item['user_id']),
                                  style: ElevatedButton.styleFrom(backgroundColor: kTealColor, foregroundColor: Colors.white),
                                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }
  Widget _buildDisputesTab(bool isDark, Color cardBg, Color borderCol) {
    final filtered = _allDisputes.where((d) {
      final status = d['status']?.toString().toLowerCase() ?? '';
      if (_disputeFilter == 'Active') return status == 'open';
      if (_disputeFilter == 'Resolved') return status != 'open';
      return true;
    }).toList();

    return Column(
      children: [
        _buildPillFilter(
          options: const ['All', 'Active', 'Resolved'],
          currentVal: _disputeFilter,
          onChanged: (val) => setState(() => _disputeFilter = val),
          isDark: isDark,
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildPanelEmptyState(Icons.gavel_rounded, 'No dispute queries')
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final status = item['status'] ?? 'open';
                    final reason = item['reason'] ?? 'No reason provided';
                    final txId = item['transaction_id'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Dispute #${item['id']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                              _buildStatusIndicator(status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(reason, style: TextStyle(color: isDark ? Colors.grey.shade300 : const Color(0xFF334155), fontSize: 14)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Transaction ID: $txId', style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontSize: 12)),
                              if (status == 'open')
                                ElevatedButton(
                                  onPressed: () => _showDisputeResolutionDialog(item, isDark),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  void _showDisputeResolutionDialog(Map<String, dynamic> dispute, bool isDark) {
    final tx = dispute['transactions'];
    final txId = dispute['transaction_id'];
    double totalVal = 0.0;
    double deposit = 0.0;

    if (tx != null) {
      totalVal = _toDouble(tx['agreed_price'] ?? tx['amount'] ?? tx['offered_price']) * _toDouble(tx['agreed_duration_value'] ?? 1);
      deposit = _toDouble(tx['agreed_deposit'] ?? tx['deposit_amount'] ?? tx['offered_deposit']);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Resolve Dispute #${dispute['id']}', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filer Details: ${dispute['reason']}', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87)),
            const SizedBox(height: 12),
            Text('Transaction Amount: LKR ${totalVal.toStringAsFixed(0)}', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87)),
            Text('Transaction Deposit: LKR ${deposit.toStringAsFixed(0)}', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87)),
            const SizedBox(height: 16),
            Text('Select resolving strategy:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Refund Requester'),
            onPressed: () {
              Navigator.pop(context);
              _resolveDisputeRefund(dispute['id'], txId);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kTealColor, foregroundColor: Colors.white),
            child: const Text('Release to Provider'),
            onPressed: () {
              Navigator.pop(context);
              _resolveDisputeRelease(dispute['id'], txId);
            },
          ),
        ],
      ),
    );
  }
  Widget _buildReportsTab(bool isDark, Color cardBg, Color borderCol) {
    final filtered = _allReports.where((r) {
      final status = r['status']?.toString().toLowerCase() ?? '';
      if (_reportFilter == 'Pending') return status == 'pending';
      if (_reportFilter == 'Actioned') return status == 'actioned' || status == 'dismissed';
      return true;
    }).toList();

    return Column(
      children: [
        _buildPillFilter(
          options: const ['All', 'Pending', 'Actioned'],
          currentVal: _reportFilter,
          onChanged: (val) => setState(() => _reportFilter = val),
          isDark: isDark,
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildPanelEmptyState(Icons.report_gmailerrorred_rounded, 'Clear of user reports')
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final reporterId = item['reporter_id'];
                    final reportedId = item['reported_user_id'];
                    final reporterProfile = _allUsers.firstWhere(
                      (u) => u['id'] == reporterId,
                      orElse: () => <String, dynamic>{},
                    );
                    final reportedProfile = _allUsers.firstWhere(
                      (u) => u['id'] == reportedId,
                      orElse: () => <String, dynamic>{},
                    );
                    final reporter = _getUsername(reporterProfile);
                    final reported = _getUsername(reportedProfile);
                    final reason = item['reason'] ?? '';
                    final desc = item['description'] ?? 'No description provided';
                    final status = item['status'] ?? 'pending';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Reported User: @$reported', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                              _buildStatusIndicator(status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Reason: $reason', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(desc, style: TextStyle(color: isDark ? Colors.grey.shade300 : const Color(0xFF334155), fontSize: 13)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('By reporter: @$reporter', style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontSize: 11)),
                              if (status == 'pending')
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _resolveReport(item['id'], 'dismissed'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                      child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _resolveReport(item['id'], 'actioned'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                      child: const Text('Take Action', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  void _viewNICImage(String url, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, bool isDark, Color cardBg, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBarCol(String label, double valRatio, String valueLabel, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(valueLabel, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          width: 28,
          height: 100 * (valRatio == 0 ? 0.05 : valRatio),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: valRatio == 0 ? [Colors.grey.shade300, Colors.grey.shade400] : [kTealColor, Colors.blueAccent],
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : const Color(0xFF475569), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLegendDot(String label, Color color, double pct) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color bg; Color fg;
    String label = status.toUpperCase();
    switch (status.toLowerCase()) {
      case 'verified': case 'resolved': case 'dismissed':
        bg = Colors.green.withValues(alpha: 0.1); fg = Colors.green; break;
      case 'pending': case 'open':
        bg = Colors.amber.withValues(alpha: 0.1); fg = Colors.amber.shade800; break;
      case 'actioned':
        bg = Colors.orange.withValues(alpha: 0.1); fg = Colors.orange; break;
      default:
        bg = Colors.grey.withValues(alpha: 0.1); fg = Colors.grey; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
    );
  }

  Widget _buildPanelEmptyState(IconData icon, String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavbar(bool isDark, Color cardBg, Color borderCol) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderCol, width: 1.0)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        elevation: 0,
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kTealColor,
        unselectedItemColor: isDark ? Colors.grey.shade500 : const Color(0xFF64748B),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('${_allNics.where((n) => n['verification_status'] == 'pending').length}'),
              isLabelVisible: _allNics.where((n) => n['verification_status'] == 'pending').isNotEmpty,
              backgroundColor: kTealColor,
              child: const Icon(Icons.assignment_ind_rounded),
            ),
            label: 'NICs',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('${_allDisputes.where((d) => d['status'] == 'open').length}'),
              isLabelVisible: _allDisputes.where((d) => d['status'] == 'open').isNotEmpty,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.gavel_rounded),
            ),
            label: 'Disputes',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('${_allReports.where((r) => r['status'] == 'pending').length}'),
              isLabelVisible: _allReports.where((r) => r['status'] == 'pending').isNotEmpty,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.report_problem_rounded),
            ),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}