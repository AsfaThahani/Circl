import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../widgets/tamil_text.dart';
import 'package:flutter/rendering.dart'; // Required for ScrollDirection
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../widgets/aura_avatar.dart' as aura_avatar;
import 'chat_detail_screen.dart' as chat_detail_screen;
import '../l10n/app_localizations.dart';

const Color kTealColor = Color(0xFF26A69A);

DateTime _parseSupabaseTimestamp(dynamic timestamp) {
  if (timestamp == null) return DateTime.now();
  final dateString = timestamp.toString();
  if (dateString.isEmpty) return DateTime.now();
  try {
    return DateTime.parse(dateString).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}
Color getAuraColor(String? level) {
  final normalized = (level ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'platinum':
      return const Color(0xFFE5E4E2); // Platinum
    case 'gold':
      return const Color(0xFFFFD700); // Gold
    case 'silver':
      return const Color(0xFFC0C0C0); // Silver
    case 'bronze':
      return const Color(0xFFCD7F32); // Bronze
    default:
      return const Color(0xFFCD7F32); // Default to Bronze
  }
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  bool _showUpButton = false;
  bool _showDownButton = false;

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  Timer? _refreshTimer;

  RealtimeChannel? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setupRealtimeSubscription();

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() => _isSearching = _searchFocusNode.hasFocus);
    });

    _scrollController.addListener(_onScroll);

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

  void _setupRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _realtimeSubscription = _supabase
        .channel('chats_list_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            final record = newRecord.isNotEmpty ? newRecord : oldRecord;
            if (record['requester_id'] == user.id || record['provider_id'] == user.id) {
              if (mounted) _loadConversations();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadConversations() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final conversations = await _chatService.fetchConversations(user.id);
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _filteredConversations = _applyFilters(conversations);
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> conversations) {
    List<Map<String, dynamic>> filtered = List.from(conversations);
    final status = _selectedFilter.toLowerCase();

    if (status == 'unread') {
      final userId = _supabase.auth.currentUser?.id;
      filtered = filtered.where((conv) {
        final messagesData = conv['messages'];
        final List<dynamic> messages = messagesData is List ? messagesData : [];
        return messages.any((msg) => msg['sender_id'] != userId && msg['read_at'] == null);
      }).toList();
    } else if (status == 'active') {
      filtered = filtered.where((conv) {
        final convStatus = conv['status']?.toString().toLowerCase() ?? '';
        return ['active', 'negotiating', 'offer_sent', 'payment_pending', 'terms_agreed', 'payment_held', 'in_progress'].contains(convStatus);
      }).toList();
    } else if (status == 'completed') {
      filtered = filtered.where((conv) {
        final convStatus = conv['status']?.toString().toLowerCase() ?? '';
        return convStatus == 'completed';
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((conv) {
        final request = conv['request'] as Map<String, dynamic>?;
        final title = request?['title']?.toString().toLowerCase() ?? '';
        final name = _getOtherUserName(conv).toLowerCase();
        return title.contains(query) || name.contains(query);
      }).toList();
    }

    switch (_selectedSort) {
      case 'Oldest':
        filtered.sort((a, b) => _getLastActivityTime(a).compareTo(_getLastActivityTime(b)));
        break;
      case 'A-Z':
        filtered.sort((a, b) => _getOtherUserName(a).toLowerCase().compareTo(_getOtherUserName(b).toLowerCase()));
        break;
      case 'Z-A':
        filtered.sort((a, b) => _getOtherUserName(b).toLowerCase().compareTo(_getOtherUserName(a).toLowerCase()));
        break;
      case 'Newest':
      default:
        filtered.sort((a, b) => _getLastActivityTime(b).compareTo(_getLastActivityTime(a)));
        break;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());

    return filtered;
  }

  DateTime _getLastActivityTime(Map<String, dynamic> conv) {
    final messagesData = conv['messages'];
    final List<dynamic> messages = messagesData is List ? messagesData : [];
    if (messages.isNotEmpty) {
      return _parseSupabaseTimestamp(messages.last['created_at']);
    }
    return _parseSupabaseTimestamp(conv['created_at'] ?? conv['updated_at']);
  }
  String _extractAuraLevel(Map<String, dynamic>? userMap) {
    if (userMap == null) return 'bronze';
    final level = userMap['aura_level'] ?? userMap['auraLevel'] ?? userMap['aura'] ?? userMap['tier'];
    final normalized = (level ?? '').toString().trim().toLowerCase();
    if (normalized.contains('platinum')) return 'platinum';
    if (normalized.contains('gold')) return 'gold';
    if (normalized.contains('silver')) return 'silver';
    if (normalized.contains('bronze')) return 'bronze';
    return 'bronze'; // Default to bronze
  }

  String _getOtherUserName(Map<String, dynamic> transaction) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final request = transaction['request'] as Map<String, dynamic>?;
    final provider = transaction['provider'] as Map<String, dynamic>?;
    final requester = request?['requester'] as Map<String, dynamic>?;
    final bool isCurrentUserProvider = transaction['provider_id'] == currentUserId;
    return isCurrentUserProvider ? (requester?['username'] ?? 'User') : (provider?['username'] ?? 'User');
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _filteredConversations = _applyFilters(_conversations);
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _filteredConversations = _applyFilters(_conversations);
    });
  }

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final date = _parseSupabaseTimestamp(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return DateFormat('h:mm a').format(date);
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
        return 'Yesterday';
      }
      if (diff.inDays < 7) {
        return DateFormat('EEEE').format(date); // Monday, Tuesday, etc.
      }
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final textColor = theme.colorScheme.onSurface;
    final scaffoldColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: scaffoldColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 0,
      ),
      floatingActionButton: _buildMinimalScrollButton(isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 20, 10),
                child: Text(
                  l10n?.chatsTitle ?? 'Chats',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: textColor,
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                child: Container(
                  color: scaffoldColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchBar(isDark, textColor),
                      _buildFilterRow(isDark),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: kTealColor)),
              )
            else if (_filteredConversations.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(isDark),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildConversationTile(
                      _filteredConversations[index],
                      isDark,
                      textColor,
                      scaffoldColor,
                    ),
                    childCount: _filteredConversations.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
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
          margin: const EdgeInsets.only(bottom: 76, right: 4),
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

  Widget _buildSearchBar(bool isDark, Color textColor) {
    final l10n = AppLocalizations.of(context);
    final searchBarColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.grey.shade500 : Colors.blueGrey;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: searchBarColor,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: _isSearching ? kTealColor : borderColor,
            width: _isSearching ? 1.5 : 1.0,
          ),
          boxShadow: _isSearching
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
              color: _isSearching ? kTealColor : iconColor,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(fontSize: 13, color: textColor),
                decoration: InputDecoration(
                  hintText: l10n?.chatsSearchHint ?? 'Search conversations...',
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
            if (_isSearching)
              GestureDetector(
                onTap: _clearSearch,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded, 
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500, 
                    size: 18
                  ),
                ),
              ),
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: PopupMenuButton<String>(
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                surfaceTintColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                tooltip: 'Sort conversations',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedSort != 'Newest' 
                        ? kTealColor.withValues(alpha: 0.1) 
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sort_rounded,
                    color: _selectedSort != 'Newest' ? kTealColor : (isDark ? Colors.grey.shade500 : const Color(0xFF64748B)),
                    size: 20,
                  ),
                ),
                onSelected: (String value) {
                  setState(() {
                    _selectedSort = value;
                    _filteredConversations = _applyFilters(_conversations);
                  });
                },
                itemBuilder: (BuildContext context) => [
                  _buildSortMenuItem('Newest', 'Newest to Oldest', Icons.arrow_downward_rounded, isDark),
                  _buildSortMenuItem('Oldest', 'Oldest to Newest', Icons.arrow_upward_rounded, isDark),
                  const PopupMenuDivider(height: 1),
                  _buildSortMenuItem('A-Z', 'A to Z', Icons.sort_by_alpha_rounded, isDark),
                  _buildSortMenuItem('Z-A', 'Z to A', Icons.sort_by_alpha_rounded, isDark),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String title, IconData icon, bool isDark) {
    final bool isSelected = _selectedSort == value;
    
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kTealColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? kTealColor : (isDark ? Colors.grey.shade500 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? kTealColor : (isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 18, color: kTealColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final filters = ['All', 'Unread', 'Active', 'Completed'];
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Container(
      color: scaffoldColor,
      padding: const EdgeInsets.only(top: 4.0, bottom: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            final buttonColor = isSelected 
                ? kTealColor 
                : (isDark ? const Color(0xFF1E293B) : Colors.white);
            final borderColor = isSelected 
                ? kTealColor 
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
            final textColor = isSelected 
                ? Colors.white 
                : (isDark ? Colors.grey.shade400 : const Color(0xFF475569));
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedFilter = filter;
                  _filteredConversations = _applyFilters(_conversations);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: borderColor,
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
                    filter == 'All'
                        ? (l10n?.filterAll ?? 'All')
                        : filter == 'Unread'
                            ? (l10n?.filterUnread ?? 'Unread')
                            : filter == 'Active'
                                ? (l10n?.filterActive ?? 'Active')
                                : (l10n?.filterCompleted ?? 'Completed'),
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.2,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    Map<String, dynamic> transaction, 
    bool isDark, 
    Color textColor, 
    Color backgroundColor
  ) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final request = transaction['request'] as Map<String, dynamic>?;
    final provider = transaction['provider'] as Map<String, dynamic>?;
    final requester = request?['requester'] as Map<String, dynamic>?;
    final bool isCurrentUserProvider = transaction['provider_id'] == currentUserId;
    final String name = isCurrentUserProvider ? (requester?['username'] ?? 'User') : (provider?['username'] ?? 'User');
    final String avatarInitials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
    final String requestTitle = request?['title']?.toString() ?? 'Request';
    
    final messagesData = transaction['messages'];
    final List<dynamic> messages = messagesData is List ? messagesData : [];
    final bool hasUnread = messages.any((msg) => msg['sender_id'] != currentUserId && msg['read_at'] == null);
    final String lastMessageTime = messages.isNotEmpty 
        ? _formatTimeAgo(messages.last['created_at'])
        : '';
    
    final Map<String, dynamic>? otherUser = isCurrentUserProvider ? requester : provider;
    final String? rawAvatarUrl = otherUser?['profile_picture_url'] ?? otherUser?['avatarUrl'];
    final String avatarUrl = aura_avatar.resolveAvatarUrl(rawAvatarUrl);
    final String auraLevel = _extractAuraLevel(otherUser);
    final Color auraColor = getAuraColor(auraLevel);

    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => chat_detail_screen.ChatDetailScreen(
                  transactionId: transaction['id'],
                  name: _getOtherUserName(transaction),
                  requestTitle: request?['title']?.toString() ?? 'Request',
                  requestType: request?['type']?.toString() ?? 'borrow',
                  transactionStatus: transaction['status']?.toString() ?? 'active',
                  requestData: request,
                  avatarUrl: avatarUrl,
                  auraLevel: auraLevel,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                aura_avatar.AuraAvatar(
                  imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                  radius: 18,
                  auraColor: auraColor,
                  backgroundColor: backgroundColor,
                  fallbackChild: Text(
                    avatarInitials,
                    style: const TextStyle(
                      color: kTealColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name, 
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600, 
                                fontSize: 16, 
                                color: textColor
                              ), 
                              overflow: TextOverflow.ellipsis
                            ),
                          ),
                          if (lastMessageTime.isNotEmpty)
                            Text(
                              lastMessageTime, 
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500, 
                                color: hasUnread ? kTealColor : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8))
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        requestTitle, 
                        style: TextStyle(
                          fontSize: 14, 
                          color: hasUnread ? textColor : (isDark ? Colors.grey.shade500 : const Color(0xFF64748B)), 
                          fontWeight: FontWeight.normal
                        ), 
                        overflow: TextOverflow.ellipsis
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1, 
          thickness: 0.5, 
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), 
          indent: 80
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark ? Colors.grey.shade300 : const Color(0xFF0F172A);
    final containerColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final iconColor = isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24), 
            decoration: BoxDecoration(
              color: containerColor, 
              shape: BoxShape.circle
            ), 
            child: Icon(
              Icons.chat_bubble_outline_rounded, 
              size: 48, 
              color: iconColor
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)?.chatsNoConversations ?? 'No conversations yet', 
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w700, 
              color: textColor
            ),
          ),
        ],
      ),
    );
  }
}
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverAppBarDelegate({required this.child});

  @override
  double get minExtent => 112.0;
  
  @override
  double get maxExtent => 112.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}