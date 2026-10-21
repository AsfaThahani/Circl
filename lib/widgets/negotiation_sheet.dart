import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kTealColor = Color(0xFF26A69A);

class NegotiationSheet extends StatefulWidget {
  final String requestType;
  final double initialPrice;
  final double initialDeposit;
  final int initialDurationValue;
  final String initialDurationUnit;
  final String sheetTitle;
  final String actionButtonText;
  final String budgetLabel;
  final double referenceBudget;
  final String depositLabel;
  final double referenceDeposit;
  final String durationHelperLabel;
  final int referenceDurationValue;
  final String referenceDurationUnit;
  final bool hideDeposit;

  final Function(double price, double deposit, int durationValue, String durationUnit, String notes) onProposalSent;

  const NegotiationSheet({
    super.key,
    required this.requestType,
    required this.initialPrice,
    required this.initialDeposit,
    required this.initialDurationValue,
    required this.initialDurationUnit,
    required this.sheetTitle,
    required this.actionButtonText,
    required this.budgetLabel,
    required this.referenceBudget,
    required this.depositLabel,
    required this.referenceDeposit,
    required this.durationHelperLabel,
    required this.referenceDurationValue,
    required this.referenceDurationUnit,
    this.hideDeposit = false,
    required this.onProposalSent,
  });

  @override
  State<NegotiationSheet> createState() => _NegotiationSheetState();
}

class _NegotiationSheetState extends State<NegotiationSheet> {
  late TextEditingController priceInputController;
  late TextEditingController depositInputController;
  late TextEditingController durationInputController;
  final TextEditingController notesInputController = TextEditingController();
  late String tempDurationUnit;

  final List<String> _durationUnits = ['hours', 'days', 'weeks', 'months'];

  String _formatRecommendedDuration(int value, String unit) {
    if (value == 1 && unit.endsWith('s')) {
      return '$value ${unit.substring(0, unit.length - 1)}';
    }
    return '$value $unit';
  }
  final double providerFeeRate = 0.08;  // 8% deducted from provider
  final double requesterFeeRate = 0.04; // 4% added to checkout for requester

  @override
  void initState() {
    super.initState();
    priceInputController = TextEditingController(text: '');
    depositInputController = TextEditingController(text: '');
    durationInputController = TextEditingController(text: widget.initialDurationValue.toString());
    tempDurationUnit = widget.initialDurationUnit;
  }

  @override
  void dispose() {
    priceInputController.dispose();
    depositInputController.dispose();
    durationInputController.dispose();
    notesInputController.dispose();
    super.dispose();
  }

  Widget _buildStepperButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: kTealColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isRent = widget.requestType == 'rent';
    final bool isPaidTask = widget.requestType == 'paid';
    final bool isBorrow = widget.requestType == 'borrow';
    final bool isFavour = widget.requestType == 'favour';

    String durationLabel = 'Duration';
    switch (widget.requestType) {
      case 'rent': durationLabel = 'Rental Period'; break;
      case 'paid': durationLabel = 'Task Duration'; break;
      case 'favour': durationLabel = 'Help Duration'; break;
      case 'borrow': durationLabel = 'Borrowing Duration'; break;
    }
    
    final bool isPaidRequest = isRent || isPaidTask;
    final bool isBorrowOrRent = isBorrow || isRent;

    String feeLabel = 'Expected Price';
    if (isRent) {
      feeLabel = 'Rental Fee';
    } else if (isPaidTask) {
      feeLabel = 'Task Fee';
    }

    double currentTotalPrice = isPaidRequest ? (double.tryParse(priceInputController.text) ?? 0.0) : 0.0;
    double currentDeposit = (isBorrowOrRent && !widget.hideDeposit) 
        ? (double.tryParse(depositInputController.text) ?? 0.0) 
        : widget.initialDeposit;
    
    double providerCommission = currentTotalPrice * providerFeeRate;
    double providerEarnings = currentTotalPrice - providerCommission;
    double requesterServiceFee = currentTotalPrice * requesterFeeRate;
    double totalCustomerPays = currentTotalPrice + requesterServiceFee + currentDeposit;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kTealColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_note_rounded, color: kTealColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.sheetTitle,
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.hideDeposit ? 'Modify your terms below.' : 'Negotiate your terms below.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B))
              ),
              const SizedBox(height: 20),
              if (isPaidRequest) ...[
                Text(
                  feeLabel, 
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceInputController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    prefixText: 'LKR ',
                    prefixStyle: TextStyle(color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w600),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kTealColor, width: 1.5)),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('${widget.budgetLabel}: LKR ${widget.referenceBudget.toStringAsFixed(0)}', style: const TextStyle(color: kTealColor, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 16),
              ],
              if (isBorrowOrRent && !widget.hideDeposit) ...[
                Text(
                  'Security Deposit', 
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: depositInputController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    prefixText: 'LKR ',
                    prefixStyle: TextStyle(color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w600),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kTealColor, width: 1.5)),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('${widget.depositLabel}: LKR ${widget.referenceDeposit.toInt()}', style: const TextStyle(color: kTealColor, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                durationLabel, 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white, 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStepperButton(Icons.remove, () {
                            int current = int.tryParse(durationInputController.text) ?? 1;
                            if (current > 1) {
                              setState(() => durationInputController.text = (current - 1).toString());
                            }
                          }, isDark),
                          Container(
                            width: 64,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(19)),
                            child: TextField(
                              controller: durationInputController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              onChanged: (val) => setState(() {}),
                            ),
                          ),
                          _buildStepperButton(Icons.add, () {
                            int current = int.tryParse(durationInputController.text) ?? 1;
                            setState(() => durationInputController.text = (current + 1).toString());
                          }, isDark),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 30, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    Expanded(
                      flex: 4,
                      child: PopupMenuButton<String>(
                        initialValue: tempDurationUnit,
                        position: PopupMenuPosition.under,
                        elevation: 4,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (String newValue) => setState(() => tempDurationUnit = newValue),
                        itemBuilder: (BuildContext context) {
                          return _durationUnits.map((String unit) {
                            bool isSelected = tempDurationUnit == unit;
                            return PopupMenuItem<String>(
                              value: unit,
                              child: Text(
                                unit[0].toUpperCase() + unit.substring(1), 
                                style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? kTealColor : (isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)))
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.only(left: 16, right: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tempDurationUnit[0].toUpperCase() + tempDurationUnit.substring(1), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A))),
                              Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  '${widget.durationHelperLabel}: ${_formatRecommendedDuration(widget.referenceDurationValue, widget.referenceDurationUnit)}',
                  style: const TextStyle(color: kTealColor, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Proposal Notes', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : const Color(0xFF475569))
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesInputController,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A), fontSize: 15),
                decoration: InputDecoration(
                  filled: true, 
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  hintText: widget.hideDeposit ? 'Explain your proposed changes...' : 'Add a clear statement explaining your terms...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kTealColor, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              if ((isPaidRequest || isBorrowOrRent) && !widget.hideDeposit) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kTealColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kTealColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPaidRequest) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Base $feeLabel:', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            Text('LKR ${currentTotalPrice.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Circl Fee (8%):', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            Text('- LKR ${providerCommission.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ],
                        ),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), thickness: 0.5)),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPaidRequest ? 'Your Earnings:' : 'Security Deposit (Held):', 
                            style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A), fontSize: 14)
                          ),
                          Text(
                            'LKR ${(isPaidRequest ? providerEarnings : currentDeposit).toStringAsFixed(2)}', 
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kTealColor)
                          ),
                        ],
                      ),
                      if (isPaidRequest) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total amount customer pays:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text(
                                'LKR ${totalCustomerPays.toStringAsFixed(2)}', 
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A))
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        foregroundColor: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                        elevation: 0, 
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onProposalSent(
                          currentTotalPrice, 
                          currentDeposit, 
                          int.tryParse(durationInputController.text) ?? 1, 
                          tempDurationUnit,
                          notesInputController.text.trim()
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTealColor,
                        foregroundColor: Colors.white,
                        elevation: 0, 
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(widget.actionButtonText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}