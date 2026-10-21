import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payhere_service.dart';
import '../services/transaction_service.dart';
import '../services/payment_service.dart';
import 'payment_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final int requestId;
  final int transactionId;
  final double amount;
  final String requestTitle;
  final String paymentType;
  final int? durationValue;
  final String? durationUnit;
  final double? pricePerUnit;
  
  const PaymentScreen({
    super.key,
    required this.requestId,
    required this.transactionId,
    required this.amount,
    required this.requestTitle,
    required this.paymentType,
    this.durationValue,
    this.durationUnit,
    this.pricePerUnit,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PayHereService _payhereService = PayHereService();
  final TransactionService _transactionService = TransactionService();
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;
  bool _paymentCompleted = false;

  String _getFormattedDuration() {
    if (widget.durationValue == null || widget.durationUnit == null) {
      return '';
    }
    
    final value = widget.durationValue!;
    final unit = widget.durationUnit!;
    
    if (value == 1) {
      String singularUnit = unit.substring(0, unit.length - 1);
      return '$value $singularUnit';
    }
    return '$value $unit';
  }

  String _getFormattedPricePerUnit() {
    if (widget.pricePerUnit == null) return '';
    return 'LKR ${widget.pricePerUnit!.toStringAsFixed(0)}';
  }

  @override
  void initState() {
    super.initState();
    debugPrint('📱 PaymentScreen initialized with:');
    debugPrint('  📝 Request Title: ${widget.requestTitle}');
    debugPrint('  💰 Amount: LKR ${widget.amount}');
    debugPrint('  🏷️ Payment Type: ${widget.paymentType}');
    debugPrint('  ⏱️ Duration: ${widget.durationValue} ${widget.durationUnit}');
    debugPrint('  💵 Price Per Unit: ${widget.pricePerUnit}');
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final transaction = await _supabase
          .from('transactions')
          .select('payment_status')
          .eq('id', widget.transactionId)
          .maybeSingle();
          
      if (transaction != null) {
        final status = transaction['payment_status'] as String?;
        debugPrint('💳 Current payment status: $status');
        if (status == 'completed' || status == 'payment_held') {
          setState(() {
            _paymentCompleted = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    
    final isRent = widget.paymentType == 'rent';
    final isTask = widget.paymentType == 'paid';
    final isBorrow = widget.paymentType == 'borrow';
    final isDeposit = widget.paymentType == 'deposit';
    
    String paymentTypeLabel = '';
    if (isRent) {
      paymentTypeLabel = 'Rental Fee + Security Deposit';
    } else if (isTask) {
      paymentTypeLabel = 'Task Payment';
    } else if (isBorrow || isDeposit) {
      paymentTypeLabel = 'Security Deposit';
    }
    
    final bool hasDuration = widget.durationValue != null && widget.durationUnit != null;
    final bool hasPricePerUnit = widget.pricePerUnit != null;
    final bool showDepositLabel = isBorrow || isDeposit;
    final bool showEscrow = isRent || isTask;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      body: _paymentCompleted 
          ? _buildPaymentAlreadyCompleted(isDark)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
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
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Service:',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 14,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.requestTitle,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (hasDuration) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Duration:',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _getFormattedDuration(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasPricePerUnit && !isBorrow && !isDeposit) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rate:',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _getFormattedPricePerUnit(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Type:',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                paymentTypeLabel,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (showDepositLabel) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Deposit Amount:',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'LKR ${widget.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: const Color(0xFF1D9E75),
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'LKR ${widget.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Color(0xFF1D9E75),
                              ),
                            ),
                          ],
                        ),
                        if (showEscrow) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2F1EC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.security_rounded,
                                  size: 16,
                                  color: isDark ? const Color(0xFF26A69A) : const Color(0xFF1D9E75),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Payment held in escrow. Released only when both parties confirm completion.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF26A69A) : const Color(0xFF1D9E75),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Card Details:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.credit_card,
                              size: 16,
                              color: subtitleColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Visa: 4916 2175 0161 1292',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: subtitleColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Any future expiry date',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              size: 16,
                              color: subtitleColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'CVV: Any 3-digit number',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isProcessing ? 0 : 2,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Pay LKR ${widget.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Secure payment powered by PayHere',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentAlreadyCompleted(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: const Color(0xFF26A69A),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Already Completed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This transaction has already been paid for.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26A69A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_isProcessing || _paymentCompleted) return;
    
    setState(() => _isProcessing = true);
    
    try {
      debugPrint('🔐 Authorizing payment...');
      final authorized = await PaymentService.authorizePayment(widget.amount);

      if (!authorized) {
        _showSnackBar('❌ Payment authorization failed', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      debugPrint('✅ Biometric authorization successful');
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Please log in first');
      }
      
      final userProfile = await _supabase
          .from('profiles')
          .select('username, wallet_balance') // Removed 'phone' and 'address'
          .eq('id', user.id)
          .maybeSingle();
      
      final fullName = userProfile?['username'] ?? 'Circl User';
      final firstName = fullName.split(' ')[0];
      final lastName = fullName.contains(' ') 
          ? fullName.split(' ').sublist(1).join(' ') 
          : 'User';
      
      final orderId = "CIRCL_${widget.requestId}_${DateTime.now().millisecondsSinceEpoch}";
      
      debugPrint('🔄 Initiating payment for order: $orderId');
      debugPrint('💰 Amount: LKR ${widget.amount}');
      final success = await _payhereService.initiatePayment(
        amount: widget.amount,
        orderId: orderId,
        itemTitle: widget.requestTitle,
        firstName: firstName,
        lastName: lastName,
        email: user.email ?? 'customer@circl.lk',
        phone: '0770000000', // Default phone number since it doesn't exist in DB
        address: 'Colombo, Sri Lanka', // Default address since it doesn't exist in DB
      );
      if (success && mounted) {
        final paymentId = "PAY_${DateTime.now().millisecondsSinceEpoch}";
        
        debugPrint('✅ Payment successful! Payment ID: $paymentId');
        final status = (widget.paymentType == 'rent' || widget.paymentType == 'paid') 
            ? 'payment_held' 
            : 'completed';
            
        await _transactionService.updatePaymentStatus(
          widget.transactionId,
          paymentId,
          status,
        );
        setState(() {
          _paymentCompleted = true;
        });
        
        debugPrint('📦 Transaction ${widget.transactionId} updated to $status');
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentConfirmationScreen(
                transactionId: widget.transactionId,
                amount: widget.amount,
                requestTitle: widget.requestTitle,
                durationValue: widget.durationValue,
                durationUnit: widget.durationUnit,
                pricePerUnit: widget.pricePerUnit,
              ),
            ),
          );
        }
      } else if (mounted) {
        debugPrint('❌ Payment failed or was cancelled');
        _showSnackBar('Payment failed or was cancelled', isError: true);
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      debugPrint('❌ Payment error: $e');
      _showSnackBar('Error: ${e.toString()}', isError: true);
      if (mounted) {
        setState(() => _isProcessing = false);
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
}