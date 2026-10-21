import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const Color kTealColor = Color(0xFF26A69A);

class DisputeCenterScreen extends StatefulWidget {
  const DisputeCenterScreen({super.key});

  @override
  State<DisputeCenterScreen> createState() => _DisputeCenterScreenState();
}

class _DisputeCenterScreenState extends State<DisputeCenterScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _disputes = [];
  bool _isLoading = true;
  String _selectedTab = 'Active';

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }
  Future<void> _loadDisputes() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final disputes = await _supabase
          .from('disputes')
          .select()
          .eq('raised_by', user.id) 
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _disputes = List<Map<String, dynamic>>.from(disputes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading disputes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDisputes {
    if (_selectedTab == 'Active') {
      return _disputes.where((d) => d['status'] == 'open').toList();
    } else {
      return _disputes.where((d) => d['status'] == 'resolved' || d['status'] == 'rejected').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        title: Text(
          'Dispute Center',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kTealColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildPillFilterChip('Active', isDark),
                        const SizedBox(width: 8),
                        _buildPillFilterChip('Resolved', isDark),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: kTealColor,
                    onRefresh: _loadDisputes, // Enables pull-to-refresh
                    child: _filteredDisputes.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredDisputes.length,
                            itemBuilder: (context, index) {
                              final dispute = _filteredDisputes[index];
                              return _buildDisputeCard(dispute, isDark);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPillFilterChip(String label, bool isDark) {
    final isSelected = _selectedTab == label;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? kTealColor 
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected 
                ? kTealColor 
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kTealColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 0.2,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.grey.shade400 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute, bool isDark) {
    final status = dispute['status'] ?? 'open';
    final createdAtStr = dispute['created_at']?.toString();
    final createdAt = createdAtStr != null 
        ? (DateTime.tryParse(createdAtStr) ?? DateTime.now()) 
        : DateTime.now();

    final isResolved = status == 'resolved' || status == 'rejected';
    
    Color statusColor = isResolved ? kTealColor : const Color(0xFFFF6B6B);
    String statusLabel = isResolved ? 'Resolved' : 'Active';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dispute['reason'] ?? 'Dispute #${dispute['id']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, yyyy').format(createdAt.toLocal()),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reason:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dispute['reason'] ?? 'No reason provided.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                  ),
                ),
                if (dispute['resolution_notes'] != null && dispute['resolution_notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Resolution:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: kTealColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dispute['resolution_notes'],
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                    ),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No $_selectedTab disputes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your disputes will appear here',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}