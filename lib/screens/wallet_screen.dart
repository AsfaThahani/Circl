import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _supabase = Supabase.instance.client;
  
  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalSpent = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final walletData = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final transactionsList = await _supabase
          .from('transactions')
          .select()
          .or('requester_id.eq.${user.id},provider_id.eq.${user.id}')
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        double income = 0.0;
        double spent = 0.0;
        
        for (var t in transactionsList) {
          final isIncome = t['provider_id'] == user.id;
          final rawAmount = t['agreed_price'] ?? t['offered_price'] ?? t['deposit_amount'] ?? 0.0;
          final amount = double.tryParse(rawAmount.toString()) ?? 0.0;
          
          final status = t['status'] ?? '';
          if (status == 'completed' || status == 'accepted' || status == 'payment_pending') {
            if (isIncome) {
              income += amount;
            } else {
              spent += amount;
            }
          }
        }

        setState(() {
          _balance = (walletData?['balance'] as num?)?.toDouble() ?? 0.0;
          _transactions = List<Map<String, dynamic>>.from(transactionsList);
          _totalIncome = income;
          _totalSpent = spent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading wallet: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Database Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF0F172A),
        ),
        title: Text(
          'Wallet',
          style: const TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D9E75)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color.fromARGB(255, 90, 239, 192), Color(0xFF0F766E)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 72, 240, 187).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'LKR ${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.trending_up,
                                  color: Colors.green, size: 24),
                              const SizedBox(height: 8),
                              const Text('Income',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text('LKR ${_totalIncome.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 16,
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.trending_down,
                                  color: Colors.red, size: 24),
                              const SizedBox(height: 8),
                              const Text('Spent',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text('LKR ${_totalSpent.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                        },
                        child: const Text('View All',
                            style: TextStyle(
                                color: Color(0xFF1D9E75), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.history,
                                size: 40,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No transactions yet',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        final user = _supabase.auth.currentUser;
                        
                        final isIncome = transaction['provider_id'] == user?.id;
                        
                        final rawAmount = transaction['agreed_price'] ?? transaction['offered_price'] ?? transaction['deposit_amount'] ?? 0.0;
                        final amount = double.tryParse(rawAmount.toString()) ?? 0.0;
                        
                        final statusStr = transaction['status'] ?? 'Unknown';
                        final formattedStatus = statusStr.toString().replaceAll('_', ' ');
                        final capitalizedStatus = formattedStatus.isNotEmpty 
                            ? '${formattedStatus[0].toUpperCase()}${formattedStatus.substring(1)}'
                            : '';
                        
                        final description = isIncome ? 'Earnings ($capitalizedStatus)' : 'Payment ($capitalizedStatus)';
                        
                        final createdAtStr = transaction['created_at'];
                        final createdAt = createdAtStr != null 
                            ? DateTime.parse(createdAtStr).toLocal() 
                            : DateTime.now();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isIncome ? Icons.add : Icons.remove,
                                  color:
                                      isIncome ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(description,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: textColor)),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('MMM d, yyyy – hh:mm a')
                                          .format(createdAt),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncome ? '+' : '-'} LKR ${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isIncome ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}