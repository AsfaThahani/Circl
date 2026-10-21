import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const Color kTealColor = Color(0xFF26A69A);

class ReviewsScreen extends StatefulWidget {
  final String userId; 
  final String username;

  const ReviewsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await _supabase
          .from('reviews')
          .select('*, reviewer:profiles!reviewer_id(username)')
          .eq('reviewee_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0.0;
    final sum = _reviews.fold<double>(0, (prev, r) => prev + (r['rating'] as num).toDouble());
    return sum / _reviews.length;
  }

  Map<int, int> get _ratingCounts {
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final review in _reviews) {
      final rating = (review['rating'] as num).toInt();
      counts[rating] = (counts[rating] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get _filteredReviews {
    if (_selectedFilter == 'All') return _reviews;
    return _reviews.where((r) => r['rating'].toString() == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    
    final ratingCounts = _ratingCounts;
    final avgRating = _averageRating;
    final filteredReviews = _filteredReviews;

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
          'Reviews',
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
          ? const Center(child: CircularProgressIndicator(color: kTealColor))
          : _reviews.isEmpty
              ? _buildEmptyState(isDark)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(avgRating, ratingCounts, isDark, cardColor),
                      const SizedBox(height: 24),
                      _buildFilterRow(isDark),
                      const SizedBox(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredReviews.length,
                        itemBuilder: (context, index) => _buildReviewTile(
                          filteredReviews[index],
                          isDark,
                          cardColor,
                          textColor,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(double avg, Map<int, int> counts, bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Row(children: List.generate(5, (i) => Icon(
                Icons.star,
                size: 16,
                color: i < avg.toInt() ? const Color(0xFFF59E0B) : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
              ))),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) {
              int stars = 5 - i;
              return _buildRatingBar(stars, counts[stars] ?? 0, isDark);
            }),
          )
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, int count, bool isDark) {
    final percentage = _reviews.isNotEmpty ? count / _reviews.length : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$stars★',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            height: 4,
            child: LinearProgressIndicator(
              value: percentage,
              color: const Color(0xFFF59E0B),
              backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(bool isDark) {
    final filters = ['All', '5', '4', '3', '2', '1'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildPillFilterChip(filter, isDark),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPillFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          label == 'All' ? 'All' : '$label★',
          style: TextStyle(
            fontSize: 12,
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

  Widget _buildReviewTile(Map<String, dynamic> review, bool isDark, Color cardColor, Color textColor) {
    final reviewer = review['reviewer'] as Map<String, dynamic>?;
    final reviewerName = reviewer?['username'] ?? 'Anonymous';
    final createdAt = review['created_at'] != null ? DateTime.parse(review['created_at']) : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: kTealColor.withValues(alpha: 0.1),
                child: Text(
                  reviewerName[0].toUpperCase(),
                  style: TextStyle(
                    color: kTealColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reviewerName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy').format(createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${review['rating']}★',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'] ?? '',
            style: TextStyle(
              height: 1.4,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final iconColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_border_rounded,
              size: 48,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to leave a review!',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}