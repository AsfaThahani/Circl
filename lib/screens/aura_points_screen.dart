import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuraPointsScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const AuraPointsScreen({super.key, this.profile});

  @override
  State<AuraPointsScreen> createState() => _AuraPointsScreenState();
}

class _AuraPointsScreenState extends State<AuraPointsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _profile = response as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTierFromPoints(int points) {
    if (points >= 1000) return 'Diamond';
    if (points >= 500) return 'Gold';
    if (points >= 300) return 'Silver';
    return 'Bronze';
  }

  Color _getTierColor(String auraLevel) {
    switch (auraLevel.toLowerCase()) {
      case 'diamond':
        return const Color(0xFFC0C0C0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFF94A3B8);
      case 'bronze':
      default:
        return const Color(0xFFD97706);
    }
  }

  int _getTierMinPoints(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return 1000;
      case 'gold':
        return 500;
      case 'silver':
        return 300;
      case 'bronze':
      default:
        return 0;
    }
  }

  String? _getNextTier(String currentAuraLevel) {
    switch (currentAuraLevel.toLowerCase()) {
      case 'bronze':
        return 'Silver';
      case 'silver':
        return 'Gold';
      case 'gold':
        return 'Diamond';
      case 'diamond':
        return null;
      default:
        return 'Silver';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
        ),
      );
    }

    final profile = _profile ?? widget.profile;
    final currentPoints = (profile?['circl_points'] ?? 0) as int;
    
    String auraLevel = profile?['aura_level'] ?? '';
    if (auraLevel.isEmpty) {
      auraLevel = _getTierFromPoints(currentPoints);
    }
    
    final tierColor = _getTierColor(auraLevel);
    final nextTier = _getNextTier(auraLevel);
    
    double progress = 0.0;
    int remainingPoints = 0;
    
    if (nextTier != null) {
      final currentTierMinPoints = _getTierMinPoints(auraLevel);
      final nextTierMinPoints = _getTierMinPoints(nextTier);
      
      remainingPoints = nextTierMinPoints - currentPoints;
      
      final tierRange = nextTierMinPoints - currentTierMinPoints;
      final pointsInCurrentTier = currentPoints - currentTierMinPoints;
      progress = (pointsInCurrentTier / tierRange).clamp(0.0, 1.0);
    }

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
          'Aura Profile',
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: tierColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$auraLevel Aura',
                            style: TextStyle(
                              color: tierColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$currentPoints',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Circl Points',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    if (nextTier != null)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress to $nextTier',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              Text(
                                '$remainingPoints pts left',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: tierColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade100,
                              color: tierColor,
                              minHeight: 10,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stars, color: Color(0xFF10B981), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Maximum Aura Level Reached!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Aura Levels Guide',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            SizedBox(
              height: 130,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildTierCard('Bronze', 0, currentPoints, _getTierColor('bronze'), Icons.emoji_events),
                  _buildTierCard('Silver', 300, currentPoints, _getTierColor('silver'), Icons.workspace_premium),
                  _buildTierCard('Gold', 500, currentPoints, _getTierColor('gold'), Icons.star),
                  _buildTierCard('Diamond', 1000, currentPoints, _getTierColor('diamond'), Icons.diamond),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Earn Points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEarningItem(
                    icon: Icons.check_circle_outline,
                    title: 'Complete a Request',
                    points: '+25',
                    description: 'Finish any request successfully',
                  ),
                  _buildEarningItem(
                    icon: Icons.star_outline,
                    title: 'Get 5-Star Review',
                    points: '+50',
                    description: 'Receive a perfect rating from a user',
                  ),
                  _buildEarningItem(
                    icon: Icons.thumb_up_outlined,
                    title: 'Help Others',
                    points: '+10',
                    description: 'Assist with favours and community tasks',
                  ),
                  _buildEarningItem(
                    icon: Icons.calendar_today_outlined,
                    title: 'Daily Streak',
                    points: '+5',
                    description: 'Log in and stay active daily',
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(String tier, int requiredPoints, int currentPoints, Color color, IconData icon) {
    final isUnlocked = currentPoints >= requiredPoints;
    
    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked ? color.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? color.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUnlocked ? color : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              color: isUnlocked ? Colors.white : Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tier,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isUnlocked ? color : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$requiredPoints+ pts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? color.withValues(alpha: 0.8) : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningItem({
    required IconData icon,
    required String title,
    required String points,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1D9E75), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              points,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}