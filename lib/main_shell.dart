import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/admin_dispute_dashboard.dart'; // 👈 ADD THIS IMPORT
import 'screens/feed_screen.dart';
import 'screens/map_screen.dart';
import 'screens/post_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_signup_page.dart';
import 'l10n/app_localizations.dart';

class MainShell extends StatefulWidget {
  final List<Map<String, dynamic>>? preloadedRequests;
  final bool hasPreloadedData;
  final Map<String, dynamic>? preloadedProfile;
  final bool hasPreloadedProfile;

  const MainShell({
    super.key,
    this.preloadedRequests,
    this.hasPreloadedData = false,
    this.preloadedProfile,
    this.hasPreloadedProfile = false,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentTab = 0;

  String _displayName = '';
  String _firstLetter = '';
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = true; // 👈 ADD THIS FLAG

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoadingProfile = true); // 👈 ADD THIS
    if (widget.hasPreloadedProfile && widget.preloadedProfile != null) {
      final String role = widget.preloadedProfile?['role'] ?? 'user';
      if (role == 'admin') {
        debugPrint('🚨 Admin detected in MainShell (preloaded)! Redirecting to Admin dashboard...');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDisputeDashboard()),
          );
        }
        return;
      }
      
      _setProfileData(widget.preloadedProfile!);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginSignupPage()),
        );
      }
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        final String role = profile['role'] ?? 'user';
        if (role == 'admin') {
          debugPrint('🚨 Admin detected in MainShell (database)! Redirecting to Admin dashboard...');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminDisputeDashboard()),
            );
          }
          return;
        }
        
        _setProfileData(profile);
      } else {
        final newProfile = {
          'id': user.id,
          'username': user.email?.split('@').first ?? 'User',
          'role': 'user',
          'location': 'Sri Lanka',
          'circl_points': 0,
          'aura_level': 'Bronze',
          'rating': 0.0,
          'review_count': 0,
          'verified': false,
          'is_nic_verified': false,
          'nic_skipped': false,
          'verification_status': 'none',
        };
        
        await Supabase.instance.client
            .from('profiles')
            .insert(newProfile);
        
        _setProfileData(newProfile);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _displayName = user.email?.split('@').first ?? 'User';
          _firstLetter = _displayName.isNotEmpty ? _displayName.substring(0, 1).toUpperCase() : 'U';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _setProfileData(Map<String, dynamic> profile) {
    final user = Supabase.instance.client.auth.currentUser;
    final String username = profile['username']?.toString().isNotEmpty == true
        ? profile['username']
        : (user?.email?.split('@').first ?? 'User');

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _displayName = username;
        _firstLetter = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginSignupPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final String role = _userProfile?['role'] ?? 'user';
    if (role == 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDisputeDashboard()),
          );
        }
      });
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 48,
                color: Colors.orange,
              ),
              SizedBox(height: 16),
              Text(
                'Redirecting to Admin Dashboard...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentTab,
        children: [
          FeedScreen(
            key: const ValueKey('feed'),
            preloadedRequests: widget.preloadedRequests,
            hasPreloadedData: widget.hasPreloadedData,
          ),
          const MapScreen(key: ValueKey('map')),
          const PostScreen(key: ValueKey('post')),
          const ChatsScreen(key: ValueKey('chats')),
          const ProfileScreen(key: ValueKey('profile')),
        ],
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: isKeyboardOpen ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: isKeyboardOpen,
          child: _buildCenterButton(theme),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedOpacity(
        opacity: isKeyboardOpen ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: isKeyboardOpen,
          child: _buildBottomNavBar(theme),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final feedLabel = l10n?.navFeed ?? 'Feed';
    final mapLabel = l10n?.navMap ?? 'Map';
    final chatLabel = l10n?.navChat ?? 'Chat';
    final accountLabel = l10n?.navAccount ?? 'Account';
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(0, Icons.home_outlined, feedLabel, theme)),
              Expanded(child: _buildNavItem(1, Icons.map_outlined, mapLabel, theme)),
              const SizedBox(width: 56),
              Expanded(child: _buildNavItem(3, Icons.chat_bubble_outline_rounded, chatLabel, theme)),
              Expanded(child: _buildNavItem(4, Icons.person_outline_rounded, accountLabel, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ThemeData theme) {
    bool isSelected = _currentTab == index;
    final isDark = theme.brightness == Brightness.dark;
    
    final Color itemColor = isSelected 
        ? theme.colorScheme.primary 
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF8B8B8B));

    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: itemColor, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: itemColor,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _currentTab = 2),
      child: Container(
        margin: const EdgeInsets.only(top: 18),
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}