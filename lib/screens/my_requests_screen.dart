import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const Color kTealColor = Color(0xFF26A69A);

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final requests = await _supabase
          .from('requests')
          .select()
          .eq('requester_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(requests);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    List<Map<String, dynamic>> filtered = List.from(_requests);
    if (_selectedFilter != 'All') {
      filtered = filtered
          .where((r) => r['status']?.toString().toLowerCase() == _selectedFilter.toLowerCase())
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        final title = r['title']?.toString().toLowerCase() ?? '';
        final description = r['description']?.toString().toLowerCase() ?? '';
        return title.contains(query) || description.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color.fromARGB(255, 236, 204, 65);
      case 'accepted':
        return const Color.fromARGB(255, 241, 179, 248);
      case 'completed':
        return kTealColor;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'borrow':
        return Colors.green.shade400;
      case 'rent':
        return Colors.blue.shade500;
      case 'favour':
        return Colors.orange.shade500;
      case 'paid':
        return Colors.purple.shade400;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'borrow':
        return 'Borrow';
      case 'rent':
        return 'Rent';
      case 'favour':
        return 'Help';
      case 'paid':
        return 'Paid Task';
      default:
        return type;
    }
  }

  void _showDeleteDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabase
                    .from('requests')
                    .delete()
                    .eq('id', requestId);
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadRequests();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final scaffoldColor = theme.scaffoldBackgroundColor;

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
          'My Posted Requests',
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kTealColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: _buildSearchBar(isDark, textColor),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        _buildPillFilterChip('All', isDark),
                        _buildPillFilterChip('Open', isDark),
                        _buildPillFilterChip('Accepted', isDark),
                        _buildPillFilterChip('Completed', isDark),
                        _buildPillFilterChip('Cancelled', isDark),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.list_alt_outlined,
                                  size: 60,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No requests yet',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              Text('Create a new request to get started!',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 16, 
                            right: 16, 
                            top: 8,
                            bottom: 16,
                          ),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = _filteredRequests[index];
                            final type = request['type'] ?? 'borrow';
                            final status = request['status'] ?? 'open';
                            
                            final price = request['max_price'] ?? request['min_price'];
                            
                            final title = request['title'] ?? 'Untitled';
                            final description = request['description'] ?? '';
                            final radiusKm = request['radius_km'] ?? 0;
                            final createdAt = DateTime.parse(
                                request['created_at'] ?? DateTime.now().toString());

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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getTypeColor(type)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _getTypeLabel(type),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        _getTypeColor(type),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(
                                                          status)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: _getStatusColor(
                                                        status),
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
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Divider(height: 16),
                                        if (description.isNotEmpty) ...[
                                          const Text(
                                            'Description',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            description,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        const Text(
                                          'Details',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Radius',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$radiusKm km',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Price',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  price != null
                                                      ? 'LKR $price'
                                                      : 'Free',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Posted',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat('MMM d, yyyy')
                                                      .format(createdAt),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                },
                                                icon: const Icon(Icons.edit),
                                                label: const Text('Edit'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _showDeleteDialog(
                                                        request['id'].toString()),
                                                icon: const Icon(Icons.delete),
                                                label: const Text('Delete'),
                                                style:
                                                    OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: const BorderSide(
                                                      color: Colors.red),
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
                            );
                          },
                        ),
                )
              ],
            ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color textColor) {
    final searchBarColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.grey.shade500 : Colors.blueGrey;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: searchBarColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: _searchQuery.isNotEmpty ? kTealColor : borderColor,
          width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
        ),
        boxShadow: _searchQuery.isNotEmpty
            ? [
                BoxShadow(
                  color: kTealColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search_rounded,
            color: _searchQuery.isNotEmpty ? kTealColor : iconColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(fontSize: 13, color: textColor),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search your requests...',
                hintStyle: TextStyle(color: hintColor, fontSize: 13),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close_rounded, 
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500, 
                  size: 18
                ),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildPillFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = label;
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
      ),
    );
  }
}