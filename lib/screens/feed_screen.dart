import 'dart:async';
import 'package:flutter/material.dart' as fm;
import 'package:flutter/material.dart' hide Text;
import '../widgets/tamil_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';
import '../widgets/request_card.dart';
import 'package:flutter/rendering.dart'; // Required for ScrollDirection
import '../widgets/aura_avatar.dart';
import '../services/request_service.dart';
import '../screens/request_detail_screen.dart';
import '../screens/post_screen.dart';
import '../screens/notifications_screen.dart';
import '../services/notification_service.dart' as notification_service;
import '../providers/settings_provider.dart';

class FeedScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? preloadedRequests;
  final bool hasPreloadedData;
  const FeedScreen({
    super.key,
    this.preloadedRequests,
    this.hasPreloadedData = false,
  });
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  List<Map<String, dynamic>> _userTransactions = [];
  String _selectedCategory = 'All';
  final List<Map<String, dynamic>> _categories = [
    {'id': 'All', 'title': 'All', 'icon': Icons.grid_view_rounded},
    {'id': 'Borrow', 'title': 'Borrow', 'icon': Icons.volunteer_activism_outlined},
    {'id': 'Rent', 'title': 'Rent', 'icon': Icons.vpn_key_outlined},
    {'id': 'Favour', 'title': 'Favour', 'icon': Icons.favorite_border_rounded},
    {'id': 'Task', 'title': 'Task', 'icon': Icons.assignment_outlined},
  ];
  final RequestService _requestService = RequestService();
  final notification_service.NotificationService _notificationService = notification_service.NotificationService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoading = true;
  bool _hasLocation = true;
  String _displayName = 'User';
  String _firstLetter = 'U';
  String _avatarUrl = '';
  String _auraLevel = 'Gold';
  int _unreadNotifications = 0;
  RealtimeChannel? _feedChannel;
  Timer? _debounceTimer;
  final PageController _promoController = PageController(viewportFraction: 1.0);
  Timer? _promoTimer;
  int _currentPromoPage = 0;
  final PageController _acceptedController = PageController();
  final PageController _postedController = PageController();
  int _acceptedPage = 0;
  int _postedPage = 0;
  late AnimationController _shimmerController;
  double _filterDistance = 5.0;
  double _filterRating = 0.0;
  String _sortTime = 'Newest to Oldest';
  String _sortAlpha = 'None';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;
  final GlobalKey _requestsKey = GlobalKey();
  final GlobalKey _communityKey = GlobalKey();
  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _communityActivities = [];
  final ScrollController _scrollController = ScrollController();
  bool _showUpButton = false;
  bool _showDownButton = false;
  late final notification_service.NotificationService _realtimeNotificationService;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _loadUserProfile();
    _getCurrentLocation();
    _loadUnreadNotifications();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearching = _searchFocusNode.hasFocus;
      });
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
      _initRealTimeNotifications();
    });
    _subscribeToChanges();
    _startPromoCarousel();
  }

  void _initRealTimeNotifications() {
    _realtimeNotificationService = notification_service.NotificationService();
    _realtimeNotificationService.listenToNotifications(
      onNotification: (payload) {
        _showRealTimeNotification(payload);
        _loadRequests();
        _loadUnreadNotifications();
      },
    );
  }

  void _showRealTimeNotification(Map<String, dynamic> payload) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              payload['title'] ?? 'Notification',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              payload['body'] ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    if (_feedChannel != null) _supabase.removeChannel(_feedChannel!);
    _debounceTimer?.cancel();
    _promoTimer?.cancel();
    _promoController.dispose();
    _acceptedController.dispose();
    _postedController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _realtimeNotificationService.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final direction = _scrollController.position.userScrollDirection;
    bool showUp = false;
    bool showDown = false;
    if (direction == ScrollDirection.reverse) {
      showDown = offset < (maxOffset - 50); // Only show if not at bottom
      showUp = false;
    } else if (direction == ScrollDirection.forward) {
      showUp = offset > 50; // Only show if not at top
      showDown = false;
    } else {
      if (offset <= 50) showUp = false;
      if (offset >= (maxOffset - 50)) showDown = false;
    }

    if (showUp != _showUpButton || showDown != _showDownButton) {
      setState(() {
        _showUpButton = showUp;
        _showDownButton = showDown;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotifications = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification count: $e');
    }
  }

 String _formatTimeAgo(String? dateString) {
  if (dateString == null) return 'Just now';
  final date = DateTime.tryParse(dateString)?.toLocal();  // Convert to local
  if (date == null) return 'Just now';
  final diff = DateTime.now().difference(date);  // Now both are local
  if (diff.inSeconds < 0) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

  Color _getAuraLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'diamond':
        return const Color(0xFFB9F2FF);
      default:
        return const Color(0xFFFFD700);
    }
  }

  String resolveAvatarUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    return rawUrl;
  }

  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (mounted && profile != null) {
        setState(() {
          _displayName = profile['username'] ?? user.email?.split('@').first ?? 'User';
          _firstLetter = _displayName.isNotEmpty ? _displayName.substring(0, 1).toUpperCase() : 'U';
          _auraLevel = profile['aura_level'] ?? 'Gold';
          String rawAvatar = profile['profile_picture_url'] ?? '';
          _avatarUrl = resolveAvatarUrl(rawAvatar);
        });
      }
    } catch (e) {
      debugPrint('Error loading profile for header: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _hasLocation = false);
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _hasLocation = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _hasLocation = false);
        return;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _hasLocation = true;
        });
        _loadRequests();
      }
    } catch (e) {
      debugPrint('Error getting feed location: $e');
    }
  }

  void _startPromoCarousel() {
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_promoController.hasClients) {
        _currentPromoPage++;
        if (_currentPromoPage > 3) _currentPromoPage = 0;
        _promoController.animateToPage(
          _currentPromoPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _subscribeToChanges() {
    _feedChannel = _supabase
        .channel('feed_changes')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'requests', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: (_) => _handleRealtimeUpdate());
    _feedChannel?.subscribe();
  }

  void _handleRealtimeUpdate() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () => _loadRequests());
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      if (_searchQuery.isEmpty) {
        _searchResults = [];
        return;
      }
      final allRequests = _processedRequests;
      _searchResults = allRequests.where((request) {
        final title = (request['title'] ?? '').toString().toLowerCase();
        final description = (request['description'] ?? '').toString().toLowerCase();
        final type = (request['type'] ?? '').toString().toLowerCase();
        final username = (request['profiles']?['username'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) ||
               description.contains(_searchQuery) ||
               type.contains(_searchQuery) ||
               username.contains(_searchQuery);
      }).toList();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults = [];
    });
  }

  List<TextSpan> _highlightText(String text, String query, ThemeData theme, bool isDark) {
    if (query.isEmpty) {
      return [TextSpan(text: text, style: TextStyle(color: theme.colorScheme.onSurface))];
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          backgroundColor: isDark ? const Color(0xFF134E4A) : const Color(0xFFE0F2F1),
        ),
      ));
      start = index + query.length;
    }
    return spans;
  }

  Future<void> _loadRequests() async {
    try {
      debugPrint('🔄 Loading data...');
      final requests = await _requestService.fetchRequests();
      final userId = _supabase.auth.currentUser?.id;
      List<Map<String, dynamic>> transactions = [];
      if (userId != null) {
        transactions = await _requestService.getUserTransactions(userId);
      }
      if (mounted) {
        setState(() {
          _allRequests = requests;
          _userTransactions = transactions;
          _recentActivities = transactions.take(4).map((t) {
            final isProvider = t['provider_id'] == userId;
            final status = t['status']?.toString().toLowerCase() ?? '';
            return {
              'icon': status == 'completed' ? Icons.check_circle_outline : Icons.sync,
              'color': status == 'completed' ? const Color(0xFF26A69A) : Colors.orange,
              'text': isProvider
                  ? "You offered help on a request ($status)"
                  : "Update on your request ($status)",
              'time': _formatTimeAgo(t['updated_at'] ?? t['created_at'])
            };
          }).toList();
          _communityActivities = requests.take(4).map((r) {
            final type = r['type'] ?? 'request';
            final title = r['title'] ?? 'Something';
            return {
              'icon': Icons.inventory_2_rounded,
              'color': const Color(0xFF26A69A),
              'text': "New $type listed nearby: $title",
              'time': _formatTimeAgo(r['created_at'])
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _processedRequests {
    List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(_allRequests);
    
    for (var r in filtered) {
      double score = 0.0;
      
      double? distance;
      if (_currentPosition != null && r['latitude'] != null && r['longitude'] != null) {
        try {
          final latVal = r['latitude'];
          final lngVal = r['longitude'];
          final double? lat = latVal is num ? latVal.toDouble() : double.tryParse(latVal?.toString() ?? '');
          final double? lng = lngVal is num ? lngVal.toDouble() : double.tryParse(lngVal?.toString() ?? '');
          if (lat != null && lng != null) {
            distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              lat,
              lng,
            ) / 1000.0;
            r['distance_km'] = double.parse(distance.toStringAsFixed(1));
          }
        } catch (e) {
          debugPrint('Distance calculation error: $e');
        }
      }
      
      if (distance != null) {
        double proximityScore = (1.0 - (distance / _filterDistance)).clamp(0.0, 1.0) * 40.0;
        score += proximityScore;
      } else {
        score += 20.0;
      }
      
      final profile = r['profiles'] as Map<String, dynamic>?;
      double rating = 5.0;
      if (profile?['rating'] != null) {
        rating = double.tryParse(profile!['rating'].toString()) ?? 5.0;
      }
      double trustScore = (rating / 5.0) * 20.0;
      if (profile?['verified'] == true || profile?['is_nic_verified'] == true) {
        trustScore += 10.0;
      }
      score += trustScore;
      
      String aura = profile?['aura_level']?.toString().toLowerCase() ?? 'bronze';
      double auraScore = 5.0;
      if (aura == 'silver') auraScore = 10.0;
      if (aura == 'gold') auraScore = 15.0;
      if (aura == 'diamond') auraScore = 20.0;
      score += auraScore;
      
      DateTime createdAt = DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now();
      double hoursOld = DateTime.now().difference(createdAt).inMinutes / 60.0;
      double recencyScore = (1.0 - (hoursOld / 24.0)).clamp(0.0, 1.0) * 10.0;
      score += recencyScore;
      
      
      r['match_score'] = score;
    }

    if (_filterRating > 0) {
      filtered = filtered.where((r) {
        final rating = r['profiles']?['rating'] ?? 5.0;
        return rating >= _filterRating;
      }).toList();
    }

    if (_selectedCategory != 'All') {
      String filterType = _selectedCategory == 'Task' ? 'paid' : _selectedCategory.toLowerCase();
      filtered = filtered.where((r) => r['type'] == filterType).toList();
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      filtered = filtered.where((r) => r['requester_id'] != userId).toList();
    }

    if (_currentPosition != null) {
      filtered = filtered.where((r) {
        if (r['location_preference'] == 'remote') return true;
        final dist = r['distance_km'] as double?;
        if (dist != null) {
          return dist <= _filterDistance;
        }
        return true;
      }).toList();
    }

    filtered.sort((a, b) {
      if (_sortAlpha == 'A to Z') {
        return (a['title']?.toString() ?? '').compareTo(b['title']?.toString() ?? '');
      } else if (_sortAlpha == 'Z to A') {
        return (b['title']?.toString() ?? '').compareTo(a['title']?.toString() ?? '');
      }
      
      if (_sortTime == 'Oldest to Newest') {
        return (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? '');
      } else if (_sortTime == 'Newest to Oldest') {
        final scoreA = a['match_score'] as double? ?? 0.0;
        final scoreB = b['match_score'] as double? ?? 0.0;
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        return (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? '');
      }
      return 0;
    });

    return filtered;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  void _showFilterSheet(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [Icon(Icons.filter_alt_outlined, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(l10n.feedFilterSortTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))]),
                    IconButton(icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)), onPressed: () => Navigator.pop(context))
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l10n.feedFilterMaxDistance, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)), Text("${_filterDistance.toInt()} km", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary))]),
                        SliderTheme(
                          data: SliderThemeData(activeTrackColor: theme.colorScheme.primary, inactiveTrackColor: theme.dividerColor, thumbColor: theme.colorScheme.primary, overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1)),
                          child: Slider(value: _filterDistance, min: 1, max: 50, onChanged: (val) => setModalState(() => _filterDistance = val)),
                        ),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [5, 10, 25, 50].map((v) => GestureDetector(onTap: () { HapticFeedback.lightImpact(); setModalState(() => _filterDistance = v.toDouble()); }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: _filterDistance == v ? theme.colorScheme.primary : theme.cardColor, borderRadius: BorderRadius.circular(50), border: Border.all(color: _filterDistance == v ? Colors.transparent : theme.dividerColor)), child: Text("$v km", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _filterDistance == v ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6)))))).toList()),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(color: theme.dividerColor)),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l10n.feedFilterMinRating, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)), Text(_filterRating == 0 ? l10n.feedFilterAny : "${_filterRating.toStringAsFixed(1)} ★", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary))]),
                        SliderTheme(
                          data: SliderThemeData(activeTrackColor: Colors.amber, inactiveTrackColor: theme.dividerColor, thumbColor: Colors.amber, overlayColor: Colors.amber.withValues(alpha: 0.1)),
                          child: Slider(value: _filterRating, min: 0, max: 5, divisions: 10, onChanged: (val) => setModalState(() => _filterRating = val)),
                        ),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [0.0, 4.0, 4.5, 5.0].map((v) => GestureDetector(onTap: () { HapticFeedback.lightImpact(); setModalState(() => _filterRating = v); }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: _filterRating == v ? Colors.amber : theme.cardColor, borderRadius: BorderRadius.circular(50), border: Border.all(color: _filterRating == v ? Colors.transparent : theme.dividerColor)), child: Text(v == 0 ? l10n.feedFilterAny : "$v+", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _filterRating == v ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6)))))).toList()),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(color: theme.dividerColor)),
                        Text(l10n.feedFilterSortByDate, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 12, runSpacing: 12, children: ['Newest to Oldest', 'Oldest to Newest'].map((c) { final isSelected = _sortTime == c; return ChoiceChip(label: Text(c == 'Newest to Oldest' ? l10n.feedFilterNewest : l10n.feedFilterOldest, style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), selected: isSelected, selectedColor: theme.colorScheme.primary, backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50), side: BorderSide(color: isSelected ? Colors.transparent : theme.dividerColor)), onSelected: (val) => setModalState(() => _sortTime = c)); }).toList()),
                        const SizedBox(height: 20),
                        Text(l10n.feedFilterSortAlpha, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 12, runSpacing: 12, children: ['None', 'A to Z', 'Z to A'].map((c) { final isSelected = _sortAlpha == c; return ChoiceChip(label: Text(c == 'None' ? l10n.feedFilterNone : (c == 'A to Z' ? l10n.feedFilterAtoZ : l10n.feedFilterZtoA), style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), selected: isSelected, selectedColor: theme.colorScheme.primary, backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50), side: BorderSide(color: isSelected ? Colors.transparent : theme.dividerColor)), onSelected: (val) => setModalState(() => _sortAlpha = c)); }).toList()),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: double.infinity, height: 50, child: TextButton(onPressed: () { setState(() {}); Navigator.pop(context); }, style: TextButton.styleFrom(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(l10n.feedFilterApply, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16))))
              ],
            ),
          );
        }
      )
    );
  }

  void _handleCarouselAction(String tag) {
    HapticFeedback.lightImpact();
    switch (tag) {
      case "CREATE A REQUEST":
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PostScreen()));
        break;
      case "DAILY CHALLENGE":
        setState(() => _selectedCategory = 'All');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_requestsKey.currentContext != null) {
            Scrollable.ensureVisible(
              _requestsKey.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
            );
          }
        });
        break;
      case "INVITE & EARN":
        SharePlus.instance.share(
          ShareParams(
            text: 'Join me on Circl! The best place to share and help the community. '
                  'Use my invite code and we both get +50 Aura points! \n\nhttps://circl.app/invite/$_displayName',
          ),
        );
        break;
      case "COMMUNITY WIN":
        Scrollable.ensureVisible(
          _communityKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut
        );
        break;
    }
  }
Widget _buildMinimalScrollButton(bool isDark) {
  final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
  final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  final arrowColor = isDark ? Colors.white : const Color(0xFF111827); // Deep black minimal arrow

  final bool isVisible = _showUpButton || _showDownButton;

  return AnimatedScale(
    scale: isVisible ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutBack,
    child: AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        margin: const EdgeInsets.only(bottom: 92, right: 20), // ✅ MATCHES CHATS SCREEN EXACTLY
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showUpButton ? _scrollToTop : _scrollToBottom,
            customBorder: const CircleBorder(),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Transform.rotate(
                  key: ValueKey<bool>(_showUpButton),
                  angle: _showUpButton ? 1.57079633 : -1.57079633, // -90° for up, 90° for down
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded, // Tail-less arrow from PostScreen
                    color: arrowColor,
                    size: 18, // Slightly smaller for cleaner look
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

 @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final currentRequests = _processedRequests;
  final l10n = AppLocalizations.of(context)!;
  
  return Scaffold(
    body: RefreshIndicator(
      onRefresh: _loadRequests,
      color: theme.colorScheme.primary,
      edgeOffset: 120,
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildTopGreeting(theme, isDark)),
              const SliverToBoxAdapter(child: SizedBox(height: 0)), 
              
              SliverAppBar(
                floating: true,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: _isSearching ? 2 : 0,
                toolbarHeight: 55,
                titleSpacing: 0,
                title: _buildSearchBar(theme, isDark),
                actions: _isSearching ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: TextButton(
                      onPressed: _clearSearch,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ] : null,
              ),
              if (_isSearching) ...[
                _buildSearchResults(theme, isDark),
              ],
              if (!_isSearching) ...[
                SliverToBoxAdapter(child: _buildPromoCarousel(theme, isDark)),
                SliverToBoxAdapter(child: _buildInProgress(theme, isDark)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyCategoryDelegate(
                    child: _buildCategoryIcons(theme), 
                    height: 105, 
                    bgColor: theme.scaffoldBackgroundColor
                  ),
                ),
                SliverToBoxAdapter(
                  key: _requestsKey,
                  child: _buildStatusHeader(currentRequests.length, theme)
                ),
                _isLoading
                    ? _buildShimmerLoading(theme)
                    : _buildRequestList(currentRequests),
                SliverToBoxAdapter(child: _buildPersonalActivity(theme)),
                SliverToBoxAdapter(
                  key: _communityKey,
                  child: _buildCommunityActivity(theme)
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 120),
                    child: Center(
                      child: Column(
                        children: [
                          const Text("🎉", style: TextStyle(fontSize: 24)),
                          const SizedBox(height: 8),
                          Text(
                            "You are all caught up.",
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  )
                ),
              ],
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: _buildMinimalScrollButton(isDark),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildTopGreeting(ThemeData theme, bool isDark) {
    final settings = context.watch<SettingsProvider>();
    final currentLang = settings.languageCode;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: AuraAvatar(
                    imageUrl: _avatarUrl,
                    radius: 20,
                    auraColor: _getAuraLevelColor(_auraLevel),
                    backgroundColor: theme.scaffoldBackgroundColor,
                    fallbackChild: Text(_firstLetter, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    borderWidth: 1.0,
                    glowOpacity: 0.18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getGreeting(), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    Text(_displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? theme.cardColor : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.language_rounded,
                      color: theme.colorScheme.onSurface,
                      size: 22,
                    ),
                    tooltip: 'Change Language',
                    offset: const Offset(0, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: theme.cardColor,
                    onSelected: (String langCode) {
                      settings.changeLanguage(langCode);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'en',
                        child: Text('English', 
                          style: TextStyle(
                            color: theme.colorScheme.onSurface, 
                            fontWeight: currentLang == 'en' ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'si',
                        child: Text('සිංහල', 
                          style: TextStyle(
                            color: theme.colorScheme.onSurface, 
                            fontWeight: currentLang == 'si' ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'ta',
                        child: Text('தமிழ்', 
                          style: TextStyle(
                            color: theme.colorScheme.onSurface, 
                            fontWeight: currentLang == 'ta' ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                _buildNotificationIcon(theme, isDark),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), 
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.discover, // LOCALIZED
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: EdgeInsets.only(left: 16, right: _isSearching ? 8 : 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _isSearching ? theme.cardColor : theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: _isSearching ? theme.colorScheme.primary : theme.dividerColor,
            width: _isSearching ? 1.5 : 1.0,
          ),
          boxShadow: _isSearching ? [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: _isSearching ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: l10n.searchHint, // LOCALIZED
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: l10n.localeName == 'ta' ? 8 : 13,
                  ),
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
            if (_isSearching)
              GestureDetector(
                onTap: _clearSearch,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ),
              ),
            if (!_isSearching)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showFilterSheet(theme);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.tune_rounded,
                    color: theme.colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    
    if (_searchQuery.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 48,
                  color: theme.dividerColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'Start typing to search',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find requests by title, description, or type',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results (${_searchResults.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Text(
                    'for "$_searchQuery"',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: theme.dividerColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No results found for "$_searchQuery"',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try different keywords or adjust your filters',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_searchResults.isNotEmpty)
            ..._searchResults.map(
              (request) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: _buildSearchResultCard(request, theme, isDark),
              ),
            ),
          Divider(
            color: theme.dividerColor,
            height: 1,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> request, ThemeData theme, bool isDark) {
    final title = request['title'] ?? 'Untitled';
    final type = request['type'] ?? 'borrow';
    final username = request['profiles']?['username'] ?? 'User';
    final description = request['description'] ?? '';
    final rawId = request['id'];
    final titleSpans = _highlightText(title.toString(), _searchQuery, theme, isDark);
    final descSpans = _highlightText(description.toString(), _searchQuery, theme, isDark);
    return GestureDetector(
      onTap: () {
        _clearSearch();
        if (rawId != null) {
          final int requestId = rawId is int ? rawId : int.parse(rawId.toString());
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestDetailScreen(requestId: requestId),
            ),
          );
        } else {
          _showSnackBar('Could not open request details');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getTypeColor(type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTypeIcon(type),
                color: _getTypeColor(type),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: titleSpans,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by $username',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: RichText(
                        text: TextSpan(
                          children: descSpans,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(ThemeData theme, bool isDark) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? theme.cardColor : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: theme.colorScheme.onSurface,
              size: 22,
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
              if (result == true) {
                _loadUnreadNotifications();
              }
            },
          ),
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPromoCarousel(ThemeData theme, bool isDark) {
    final carouselItems = [
      {
        "tag": "CREATE A REQUEST",
        "icon": Icons.add_circle_outline,
        "headline": "Need something done?",
        "subhead": "Post your task and let the community help.",
        "btnText": "Post Now",
        "gradient": [const Color.fromARGB(255, 29, 184, 166), const Color.fromARGB(255, 188, 234, 172)],
        "isDark": false,
      },
      {
        "tag": "DAILY CHALLENGE",
        "icon": Icons.bolt_rounded,
        "headline": "Help a neighbour",
        "subhead": "Complete any request to earn +25 bonus points.",
        "btnText": "See Requests",
        "gradient": [const Color.fromARGB(255, 148, 179, 253), const Color.fromARGB(255, 180, 211, 216)],
        "isDark": false,
      },
      {
        "tag": "INVITE & EARN",
        "icon": Icons.people_alt_rounded,
        "headline": "Bring a friend",
        "subhead": "Both get +50 pts when they join.",
        "btnText": "Share Code",
        "gradient": [  const Color.fromARGB(255, 160, 170, 211), const Color.fromARGB(255, 227, 178, 181)],
        "isDark": false,
      },
      {
        "tag": "COMMUNITY WIN",
        "icon": Icons.leaderboard_rounded,
        "headline": "Stronger Together",
        "subhead": "Check out the latest kindness happening in your community.",
        "btnText": "View Activity",
        "gradient": [const Color.fromARGB(255, 238, 110, 146), const Color.fromARGB(255, 236, 231, 194)],
        "isDark": false,
      },
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            PageView.builder(
              controller: _promoController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentPromoPage = index);
              },
              itemCount: carouselItems.length,
              itemBuilder: (context, index) {
                final item = carouselItems[index];
                return _buildCarouselCard(
                  item["tag"] as String,
                  item["icon"] as IconData,
                  item["headline"] as String,
                  item["subhead"] as String,
                  item["btnText"] as String,
                  item["gradient"] as List<Color>,
                  item["isDark"] as bool,
                );
              },
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _promoController,
                  count: carouselItems.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: theme.colorScheme.onSurface,
                    dotColor: isDark ? Colors.white24 : Colors.black12,
                    dotHeight: 6,
                    dotWidth: 6,
                    expansionFactor: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselCard(
    String tag,
    IconData bgIcon,
    String headline,
    String subhead,
    String btnText,
    List<Color> gradient,
    bool isDarkTheme,
  ) {
    final textColor = isDarkTheme ? Colors.white : const Color(0xFF0F172A);
    final badgeBgColor = isDarkTheme ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.06);
    final badgeTextColor = isDarkTheme ? Colors.white : const Color(0xFF0F172A);
    final btnColor = isDarkTheme ? Colors.white : const Color(0xFF0F172A);
    final btnTextColor = isDarkTheme ? const Color(0xFF0F172A) : Colors.white;
    final arrowBgColor = isDarkTheme ? const Color(0xFF0F172A).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -20,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  bgIcon,
                  size: 150,
                  color: isDarkTheme ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)
                ),
              ),
            ),
            Positioned(
              right: 60,
              top: -30,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: isDarkTheme ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 20, right: 24, bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(color: badgeTextColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.65,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: -0.5
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subhead,
                          style: TextStyle(color: textColor.withValues(alpha: 0.75), fontSize: 12, height: 1.3, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _handleCarouselAction(tag),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnColor,
                      foregroundColor: btnTextColor,
                      elevation: 0,
                      padding: const EdgeInsets.only(left: 16, right: 6, top: 6, bottom: 6),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: arrowBgColor, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_forward_rounded, size: 14, color: btnTextColor)
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInProgress(ThemeData theme, bool isDark) {
    final userId = _supabase.auth.currentUser?.id;
    final l10n = AppLocalizations.of(context)!;
    
    if (userId == null) return const SizedBox.shrink();
    final Map<String, Map<String, dynamic>> requestMap = {
      for (var req in _allRequests) if (req['id'] != null) req['id'].toString(): req
    };
    final activeStatuses = {'negotiating', 'in_progress', 'offer_sent', 'payment_pending', 'accepted'};
    final acceptedTransactions = _userTransactions.where((t) {
      final status = (t['status'] ?? '').toString().toLowerCase();
      final isProvider = (t['provider_id'] ?? '').toString() == userId;
      final isRequester = (t['requester_id'] ?? '').toString() == userId;
      return (isProvider || isRequester) && activeStatuses.contains(status);
    }).toList();
    final acceptedRequests = acceptedTransactions
        .map((t) => t['request_id']?.toString())
        .where((reqId) => reqId != null && requestMap.containsKey(reqId))
        .map((reqId) => requestMap[reqId!]!)
        .toList();
    final posted = _allRequests.where((r) {
      final requesterId = (r['requester_id'] ?? '').toString();
      final status = (r['status'] ?? '').toString().toLowerCase();
      return requesterId == userId && status == 'open';
    }).toList();
    if (acceptedRequests.isEmpty && posted.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final acceptedBg = isDark ? const Color.fromARGB(255, 99, 150, 151) : const Color.fromARGB(255, 205, 240, 247);
    final postedBg = isDark ? const Color.fromARGB(255, 125, 104, 152) : const Color.fromARGB(255, 239, 250, 208);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 16, 14),
          child: Text(
            l10n.activeRequests, // LOCALIZED
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), letterSpacing: 0.5),
          ),
        ),
        SizedBox(
          height: 160,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildColumnSection(
                    l10n.accepted, // LOCALIZED
                    acceptedRequests,
                    acceptedBg,
                    _acceptedController,
                    _acceptedPage,
                    (i) => setState(() => _acceptedPage = i),
                    theme,
                    isDark
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildColumnSection(
                    l10n.posted, // LOCALIZED
                    posted,
                    postedBg,
                    _postedController,
                    _postedPage,
                    (i) => setState(() => _postedPage = i),
                    theme,
                    isDark
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
  Widget _buildColumnSection(
    String title,
    List<Map<String, dynamic>> items,
    Color bgColor,
    PageController controller,
    int currentPage,
    Function(int) onPageChanged,
    ThemeData theme,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8, right: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  fm.Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: l10n.localeName == 'ta' ? 8.5 : 11,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${items.length}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  items.isEmpty
                      ? _buildEmptyState(l10n.none, isDark)
                      : PageView.builder(
                          controller: controller,
                          onPageChanged: onPageChanged,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _buildActiveTaskCard(items[index], theme, isDark);
                          },
                        ),
                  if (items.length > 1 && currentPage > 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _buildNavButton(
                        icon: Icons.chevron_left_rounded,
                        isDark: isDark,
                        onTap: () {
                          controller.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                  if (items.length > 1 && currentPage < items.length - 1)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _buildNavButton(
                        icon: Icons.chevron_right_rounded,
                        isDark: isDark,
                        onTap: () {
                          controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildActiveTaskCard(Map<String, dynamic> item, ThemeData theme, bool isDark) {
  final title = item['title']?.toString() ?? 'Request';
  final type = item['type']?.toString().toUpperCase() ?? 'GENERAL';
  final durationVal = item['duration_value'];
  final durationUnit = item['duration_unit']?.toString() ?? '';
  
  final bool hasTimer = durationVal != null && durationUnit.isNotEmpty;
  String timeText;
  if (hasTimer) {
    final numValue = durationVal is num ? durationVal : double.tryParse(durationVal.toString()) ?? 0;
    final baseUnit = durationUnit.replaceAll(RegExp(r's$'), ''); // Remove trailing 's'
    final unitDisplay = numValue == 1 ? baseUnit : '${baseUnit}s';
    timeText = '$numValue $unitDisplay left';
  } else {
    timeText = 'Ongoing';
  }

  return Padding(
    padding: const EdgeInsets.all(14.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: hasTimer 
                    ? const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.15)
                    : const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasTimer ? Icons.timer_outlined : Icons.sync_rounded,
                    size: 11,
                    color: hasTimer ? const Color.fromARGB(255, 85, 85, 85) : const Color.fromARGB(255, 88, 88, 88),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: hasTimer ? const Color.fromARGB(255, 86, 86, 86) : const Color.fromARGB(255, 76, 76, 77),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.2,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    ),
  );
}
  Widget _buildEmptyState(String emptyText, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 24,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 4),
          Text(
            emptyText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildNavButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.5) 
                : Colors.white.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white70 : Colors.black,
            size: 16,
          ),
        ),
      ),
    );
  }
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'borrow':
        return Icons.volunteer_activism_outlined;
      case 'rent':
        return Icons.vpn_key_outlined;
      case 'paid':
        return Icons.assignment_outlined;
      case 'favour':
        return Icons.favorite_border_rounded;
      default:
        return Icons.help_outline;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'borrow':
        return const Color(0xFF26A69A);
      case 'rent':
        return const Color(0xFFFF9800);
      case 'paid':
        return const Color(0xFF2196F3);
      case 'favour':
        return const Color(0xFFE91E63);
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildCategoryIcons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _categories.map((cat) {
          final bool isSelected = _selectedCategory == cat['id'];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCategory = cat['id']);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : theme.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.transparent : theme.dividerColor,
                      width: 1.5
                    ),
                    boxShadow: isSelected ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : []
                  ),
                  child: Icon(cat['icon'], color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  cat['title'],
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusHeader(int count, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            count > 0 ? '${l10n.feedNearbyRequests} ($count)' : l10n.feedNoRequestsFound,
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: theme.colorScheme.onSurface, 
              fontSize: l10n.localeName == 'ta' ? 14 : 18,
            )
          ),
          Row(
            children: [
              Icon(Icons.sort_rounded, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(_sortAlpha != 'None' ? _sortAlpha : _sortTime, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12))
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => FadeTransition(
            opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_shimmerController),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 160,
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
            ),
          ),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> targetRequests) {
  final userId = _supabase.auth.currentUser?.id;
  return SliverPadding(
    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final request = targetRequests[index];
          final profile = request['profiles'] as Map<String, dynamic>?;
          final cardId = request['id'] as int?;
          final auraLevel = profile?['aura_level'] ?? 'Gold';
          final String timeAgo = _formatTimeAgo(request['created_at']?.toString());
          
          final isVerified = profile?['is_nic_verified'] ?? false;
          String rawAvatar = profile?['profile_picture_url'] ?? '';
          
          String finalAvatarUrl = resolveAvatarUrl(rawAvatar);
          
          if (finalAvatarUrl.isEmpty) {
            finalAvatarUrl = 'https://ui-avatars.com/api/?name=${profile?['username'] ?? 'N'}&background=random';
          }
          
          final displayData = {
            'id': cardId,
            'requester_id': request['requester_id'],
            'type': request['type'] ?? 'borrow',
            'title': request['title'] ?? 'Untitled',
            'description': request['description'] ?? '',
            'distance': request['distance_km'] != null ? '${request['distance_km']} km' : '${request['radius_km'] ?? '?'} km',
            'rating': profile?['rating'] ?? 4.8,
            'user': profile?['username'] ?? 'Neighbour',
            'profile_picture_url': finalAvatarUrl,
            'isBest': index == 0,
            'isVerified': isVerified,
            'timeAgo': timeAgo,  // ✅ Now uses actual database timestamp
            'auraLevel': auraLevel,
            'min_price': request['min_price'],
            'max_price': request['max_price'] ?? request['price'],
            'min_deposit': request['min_deposit'],
            'max_deposit': request['max_deposit'] ?? request['deposit'],
            'price_unit': request['price_unit'],
            'duration_value': request['duration_value'],
            'duration_unit': request['duration_unit'],
          };
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: RequestCard(
              request: displayData,
              isOwn: displayData['requester_id'] == userId,
              onAccept: () => _loadRequests(),
            ),
          );
        },
        childCount: targetRequests.length,
      ),
    ),
  );
}
  Widget _buildPersonalActivity(ThemeData theme) {
    if (_recentActivities.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recentActivity, // LOCALIZED
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 0.5)
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor)),
            child: Column(
              children: _recentActivities.asMap().entries.map((entry) {
                final activity = entry.value;
                final isLast = entry.key == _recentActivities.length - 1;
                return _buildActivityRow(activity['icon'], activity['color'], activity['text'], activity['time'], theme, isLast: isLast);
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
  Widget _buildCommunityActivity(ThemeData theme) {
    if (_communityActivities.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.communityActivity, // LOCALIZED
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 0.5)
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.dividerColor)),
            child: Column(
              children: _communityActivities.asMap().entries.map((entry) {
                final activity = entry.value;
                final isLast = entry.key == _communityActivities.length - 1;
                return _buildActivityRow(activity['icon'], activity['color'], activity['text'], activity['time'], theme, isLast: isLast);
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActivityRow(IconData icon, Color color, String text, String time, ThemeData theme, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16)
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface))),
              Text(time, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
        ),
        if (!isLast) Divider(color: theme.dividerColor, height: 16),
      ],
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _StickyCategoryDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final Color bgColor;
  _StickyCategoryDelegate({required this.child, required this.height, required this.bgColor});
  @override double get minExtent => height;
  @override double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(top: -1.5, bottom: -1.5, left: 0, right: 0, child: Container(color: bgColor.withValues(alpha: 0.95))),
        Positioned.fill(child: child),
      ],
    );
  }
  @override bool shouldRebuild(covariant _StickyCategoryDelegate oldDelegate) => true;
}