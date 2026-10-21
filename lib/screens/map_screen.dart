import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Text;
import '../widgets/tamil_text.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/request_service.dart';
import '../screens/chat_detail_screen.dart';
import '../screens/request_detail_screen.dart';
import '../widgets/aura_avatar.dart';
import '../l10n/app_localizations.dart';

const Color kTealColor = Color(0xFF26A69A);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final RequestService _requestService = RequestService();
  int _radiusIndex = 1; // Default to 5km (index 1)
  final List<double> _radiusValues = [1, 5, 10, 50];
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Borrow', 'Rent', 'Favour', 'Task'];
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  Map<String, dynamic>? _selectedRequest;
  
  bool _isCardMinimized = false; // Controls the drag-down peek state
  
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isLoading = true;
  LatLng _currentPosition = const LatLng(6.9271, 79.8612);
  final Map<String, BitmapDescriptor> _customIcons = {};
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  
  final String _mapStyle = '''
  [
    {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
    {"featureType": "transit", "elementType": "labels", "stylers": [{"visibility": "off"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "landscape", "elementType": "geometry", "stylers": [{"color": "#e2f1ec"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c4e5dc"}]}
  ]
  ''';

  final String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#86a1c5"}]},
    {"featureType": "administrative.province", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#1a3a4a"}]},
    {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "road.local", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "transit", "elementType": "labels", "stylers": [{"visibility": "off"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f3d4d"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _initializeMapData();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearching = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeMapData() async {
    await _generateCustomIcons();
    await _getCurrentLocation();
    await _loadRequests();
  }
  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
      _applyFilters();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _applyFilters();
  }

  Future<void> _generateCustomIcons() async {
    _customIcons['borrow'] = await _createCustomMarkerBitmap(Colors.green.shade400);
    _customIcons['rent'] = await _createCustomMarkerBitmap(Colors.blue.shade500);
    _customIcons['favour'] = await _createCustomMarkerBitmap(Colors.orange.shade500);
    _customIcons['task'] = await _createCustomMarkerBitmap(Colors.purple.shade400);
    _customIcons['default'] = await _createCustomMarkerBitmap(Colors.grey.shade600);
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 60.0; // Marker size
    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 4),
      size / 2.2,
      Paint()..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2.2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2.8,
      Paint()..color = color,
    );
    
    final ui.Image img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _applyFilters();
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition, 13.5),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadRequests() async {
    try {
      final requests = await _requestService.fetchRequests();
      if (mounted) {
        setState(() {
          _allRequests = requests;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(String? dateString) {
    if (dateString == null) return 'Just now';
    final DateTime? date = DateTime.tryParse(dateString)?.toLocal();
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    
    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _applyFilters() {
    final maxDistanceMeters = _radiusValues[_radiusIndex] * 1000;
    final List<Map<String, dynamic>> filtered = [];
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    for (var request in _allRequests) {
      if (currentUserId != null && request['requester_id'] == currentUserId) {
        continue;
      }

      final type = (request['type'] as String? ?? 'borrow').toLowerCase();
      
      if (_selectedCategory != 'All' && type != _selectedCategory.toLowerCase()) continue;
      
      if (_searchQuery.isNotEmpty) {
        final title = (request['title'] ?? '').toString().toLowerCase();
        final description = (request['description'] ?? '').toString().toLowerCase();
        final username = (request['profiles']?['username'] ?? '').toString().toLowerCase();
        
        if (!title.contains(_searchQuery) &&
            !description.contains(_searchQuery) &&
            !username.contains(_searchQuery) &&
            !type.contains(_searchQuery)) {
          continue;
        }
      }
      
      final latVal = request['latitude'];
      final lngVal = request['longitude'];
      
      final double? lat = latVal is num 
          ? latVal.toDouble() 
          : double.tryParse(latVal?.toString() ?? '');
      final double? lng = lngVal is num 
          ? lngVal.toDouble() 
          : double.tryParse(lngVal?.toString() ?? '');
      
      if (lat != null && lng != null) {
        final dist = Geolocator.distanceBetween(
          _currentPosition.latitude, 
          _currentPosition.longitude, 
          lat, 
          lng
        );
        
        if (dist <= maxDistanceMeters) {
          final r = Map<String, dynamic>.from(request);
          r['latitude'] = lat;
          r['longitude'] = lng;
          r['calculated_distance_km'] = dist / 1000;
          r['distance'] = '${(dist / 1000).toStringAsFixed(1)} km';
          r['timeAgo'] = _formatTimeAgo(request['created_at']?.toString());
          filtered.add(r);
        }
      }
    }
    
    filtered.sort((a, b) => (a['calculated_distance_km'] as double).compareTo(b['calculated_distance_km'] as double));
    
    setState(() {
      _filteredRequests = filtered;
      _selectedRequest = _filteredRequests.isNotEmpty ? _filteredRequests.first : null;
      _isCardMinimized = false; 
      _updateRadiusCircle(maxDistanceMeters);
      _createMarkers();
    });
    
    if (_filteredRequests.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
      _animateCameraToRequest(_filteredRequests.first);
    }
  }

  void _updateRadiusCircle(double radiusMeters) {
    _circles = {
      Circle(
        circleId: const CircleId('search_radius'),
        center: _currentPosition,
        radius: radiusMeters,
        fillColor: kTealColor.withValues(alpha: 0.1),
        strokeColor: kTealColor.withValues(alpha: 0.5),
        strokeWidth: 2,
      )
    };
  }

  void _createMarkers() {
    final markers = <Marker>{};
    for (final request in _filteredRequests) {
      var lat = (request['latitude'] as num?)?.toDouble() ?? 0.0;
      var lng = (request['longitude'] as num?)?.toDouble() ?? 0.0;
      final type = (request['type'] as String? ?? 'borrow').toLowerCase();
      final icon = _customIcons[type] ?? _customIcons['default']!;
      
      markers.add(
        Marker(
          markerId: MarkerId(request['id'].toString()),
          position: LatLng(lat, lng),
          icon: icon,
          onTap: () => _onMarkerTapped(request),
        ),
      );
    }
    setState(() => _markers = markers);
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _filteredRequests.length) return;
    final request = _filteredRequests[index];
    setState(() {
      _selectedRequest = request;
    });
    _animateCameraToRequest(request);
  }

  void _onMarkerTapped(Map<String, dynamic> request) {
    final index = _filteredRequests.indexWhere((r) => r['id'] == request['id']);
    if (index != -1) {
      setState(() {
        _selectedRequest = request;
        _isCardMinimized = false;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }
      _animateCameraToRequest(request);
    }
  }

  void _animateCameraToRequest(Map<String, dynamic> request) {
    final lat = (request['latitude'] as num?)?.toDouble();
    final lng = (request['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(lat, lng)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator(color: kTealColor)),
      );
    }
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition, 
              zoom: 13.5
            ),
            markers: _markers,
            circles: _circles,
            style: isDark ? _darkMapStyle : _mapStyle,
            onMapCreated: (c) { 
              _mapController = c; 
            },
            onTap: (_) => setState(() {
              _selectedRequest = null;
              _isCardMinimized = false;
              _searchFocusNode.unfocus(); 
            }),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0, 
            right: 0,
            child: Column(
              children: [
                _buildSearchBar(theme),
                _buildCategoryPills(theme),
                _buildRequestCount(theme),
              ],
            ),
          ),
          
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 130,
            child: _buildRightSideControls(theme),
          ),
          
          if (_selectedRequest != null && _filteredRequests.isNotEmpty)
            Positioned(
              bottom: bottomPadding + 30, 
              left: 0, 
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: _isCardMinimized ? 115 : 260,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _filteredRequests.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final request = _filteredRequests[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GestureDetector(
                        onVerticalDragUpdate: (details) {
                          if (details.delta.dy > 4 && !_isCardMinimized) {
                            HapticFeedback.lightImpact();
                            setState(() => _isCardMinimized = true);
                          }
                          else if (details.delta.dy < -4 && _isCardMinimized) {
                            HapticFeedback.lightImpact();
                            setState(() => _isCardMinimized = false);
                          }
                        },
                        child: _SelectedRequestCard(
                          request: request,
                          isBest: index == 0,
                          isMinimized: _isCardMinimized,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    
    return Padding(
      padding: EdgeInsets.only(left: 16, right: _isSearching ? 8 : 16, bottom: 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: _isSearching ? kTealColor : theme.dividerColor,
            width: _isSearching ? 1.5 : 1.0,
          )
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: _isSearching ? kTealColor : (isDark ? Colors.grey.shade500 : Colors.blueGrey),
              size: 18
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: _allRequests.isEmpty 
                      ? (l10n?.mapNoRequestsAvailable ?? "No requests available") 
                      : (l10n?.mapSearchNearby ?? "Search nearby..."),
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                enabled: _allRequests.isNotEmpty,
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
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPills(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          Color activeColor;
          
          switch(category) {
            case 'Borrow': activeColor = Colors.green.shade400; break;
            case 'Rent': activeColor = Colors.blue.shade400; break;
            case 'Favour': activeColor = Colors.orange.shade400; break;
            case 'Task': activeColor = Colors.purple.shade400; break;
            default: activeColor = kTealColor;
          }
          
          Color unselectedBgColor;
          if (isDark) {
            unselectedBgColor = const Color(0xFF1E293B).withValues(alpha: 0.8);
          } else {
            unselectedBgColor = Colors.white.withValues(alpha: 0.85);
          }
          
          return Expanded(
            child: GestureDetector(
              onTap: () { 
                setState(() => _selectedCategory = category); 
                _applyFilters(); 
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : unselectedBgColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ] : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                  border: Border.all(
                    color: isSelected 
                        ? activeColor 
                        : (isDark 
                            ? const Color(0xFF334155).withValues(alpha: 0.8) 
                            : const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : activeColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestCount(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(20)
          ),
          child: Text(
            '${_filteredRequests.length} ${AppLocalizations.of(context)?.mapRequestsCount ?? 'requests in this area'}',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideControls(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : theme.cardColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12), 
                blurRadius: 8, 
                offset: const Offset(0, 4)
              )
            ],
          ),
          child: Column(
            children: [
              IconButton(
                icon: Icon(Icons.add, size: 20, color: theme.colorScheme.onSurface),
                onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
              ),
              Container(height: 1, width: 24, color: theme.dividerColor),
              IconButton(
                icon: Icon(Icons.remove, size: 20, color: theme.colorScheme.onSurface),
                onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
              ),
              Container(height: 1, width: 24, color: theme.dividerColor),
              IconButton(
                icon: const Icon(Icons.my_location, size: 18, color: kTealColor),
                onPressed: () => _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentPosition, 14),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          height: 160,
          width: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : theme.cardColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12), 
                blurRadius: 8, 
                offset: const Offset(0, 4)
              )
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                '${_radiusValues[_radiusIndex].toInt()}km',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                )
              ),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                      activeTrackColor: kTealColor,
                      inactiveTrackColor: theme.dividerColor,
                      activeTickMarkColor: const ui.Color.fromARGB(255, 109, 218, 207).withValues(alpha: 0.5),
                      inactiveTickMarkColor: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      thumbColor: kTealColor,
                    ),
                    child: Slider(
                      value: _radiusIndex.toDouble(),
                      min: 0,
                      max: (_radiusValues.length - 1).toDouble(),
                      divisions: _radiusValues.length - 1,
                      onChanged: (val) {
                        setState(() => _radiusIndex = val.toInt());
                        _applyFilters();
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Icon(
                  Icons.radar,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class _SelectedRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final bool isBest;
  final bool isMinimized;
  
  const _SelectedRequestCard({
    required this.request,
    this.isBest = false,
    this.isMinimized = false,
  });

  @override
  State<_SelectedRequestCard> createState() => _SelectedRequestCardState();
}

class _SelectedRequestCardState extends State<_SelectedRequestCard> {
  bool _isAccepting = false;
  final RequestService _requestService = RequestService();

  Future<void> _acceptRequest(BuildContext context) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('You must be logged in to chat');
      return;
    }
    
    setState(() => _isAccepting = true);
    try {
      final dynamic rawId = widget.request['id'];
      if (rawId == null) throw Exception("Error: Request ID is missing.");
      
      final int requestId = rawId is int ? rawId : int.parse(rawId.toString());
      int? existingTransactionId = await _requestService.getExistingTransaction(
        requestId, 
        currentUser.id
      );
      
      int transactionId;
      if (existingTransactionId != null) {
        transactionId = existingTransactionId;
      } else {
        transactionId = await _requestService.acceptRequestAndCreateTransaction(requestId);
      }
      
      if (!context.mounted) return;
      
      final transaction = await Supabase.instance.client
          .from('transactions')
          .select('status, requester_id, provider_id')
          .eq('id', transactionId)
          .maybeSingle();
      
      if (transaction == null) {
        throw Exception('Transaction creation failed. Please try again.');
      }
      
      String status = transaction['status'] ?? 'negotiating';
      
      final isProvider = transaction['provider_id'] == currentUser.id;
      final otherUserId = isProvider ? transaction['requester_id'] : transaction['provider_id'];
      
      String otherUserName = 'User';
      if (otherUserId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', otherUserId)
            .maybeSingle();
        if (profile != null && profile['username'] != null) {
          otherUserName = profile['username'];
        }
      }
      
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            transactionId: transactionId,
            name: otherUserName,
            requestTitle: widget.request['title'] ?? 'Request',
            requestType: widget.request['type'] ?? 'borrow',
            transactionStatus: status,
            requestData: widget.request,
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _normalizeAuraLevel(dynamic value) {
    final rawValue = (value ?? '').toString().trim();
    if (rawValue.isEmpty) return 'bronze';
    final normalized = rawValue.toLowerCase();
    if (normalized.contains('platinum')) return 'platinum';
    if (normalized.contains('gold')) return 'gold';
    if (normalized.contains('silver')) return 'silver';
    if (normalized.contains('bronze')) return 'bronze';
    return normalized;
  }

  String _extractAuraLevel(Map<String, dynamic> request) {
    final profileData = request['profiles'];
    final profileMap = profileData is Map ? Map<String, dynamic>.from(profileData) : null;
    return _normalizeAuraLevel(
      profileMap?['aura_level'] ??
      profileMap?['auraLevel'] ??
      request['aura_level'] ??
      request['auraLevel'] ??
      request['aura'] ??
      request['tier'],
    );
  }

  Widget _buildTypeBadge(String type, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    Color bgColor, textColor;
    String label;
    
    switch (type.toLowerCase()) {
      case 'borrow':
        bgColor = isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5);
        textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        label = 'Borrow'; 
        break;
      case 'rent':
        bgColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);
        textColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
        label = 'Rent'; 
        break;
      case 'favour':
        bgColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5);
        textColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
        label = 'Favour'; 
        break;
      case 'task':
      case 'paid':
        bgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
        textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        label = 'Task'; 
        break;
      default:
        bgColor = isDark ? const Color(0xFF1E293B) : theme.cardColor;
        textColor = isDark ? Colors.grey.shade400 : theme.colorScheme.onSurface;
        label = type;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)), 
      child: Text(
        label.toUpperCase(), 
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5),
      ),
    );
  }

  String _getPricingText() {
    final type = widget.request['type']?.toString().toLowerCase() ?? '';
    final maxPrice = widget.request['max_price'];
    final maxDeposit = widget.request['max_deposit'];
    
    if (type == 'favour') {
      return 'Free';
    } else if (type == 'borrow') {
      return maxDeposit != null && maxDeposit.toString() != '0' 
          ? 'Dep: Rs. ${double.parse(maxDeposit.toString()).toStringAsFixed(0)}' 
          : 'Free';
    } else if (type == 'rent') {
      String priceText = maxPrice != null ? 'Rs. ${double.parse(maxPrice.toString()).toStringAsFixed(0)}' : '';
      String depositText = maxDeposit != null && maxDeposit.toString() != '0' ? 'Dep: Rs. ${double.parse(maxDeposit.toString()).toStringAsFixed(0)}' : '';
      return [priceText, depositText].where((e) => e.isNotEmpty).join(' | ');
    } else if (type == 'task' || type == 'paid') {
      return maxPrice != null ? 'Max Rs. ${double.parse(maxPrice.toString()).toStringAsFixed(0)}' : 'Paid';
    }
    return '';
  }

  String _getDurationText() {
    final value = widget.request['duration_value'];
    final unit = widget.request['duration_unit']?.toString() ?? '';
    if (value == null || unit.isEmpty) return '';
    final intVal = value is int ? value : int.tryParse(value.toString()) ?? 0;
    if (intVal == 0) return '';
    return intVal == 1 && unit.endsWith('s') ? '$intVal ${unit.substring(0, unit.length - 1)}' : '$intVal $unit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    
    final type = widget.request['type'] ?? 'borrow';
    final title = widget.request['title'] ?? 'Untitled';
    final description = widget.request['description'] ?? '';
    final distance = widget.request['distance'] ?? '? km';
    final profile = widget.request['profiles'] as Map<String, dynamic>?;
    final user = profile?['username'] ?? widget.request['user'] ?? 'Unknown';
    final avatarUrl = resolveAvatarUrl(profile?['profile_picture_url'] ?? profile?['avatar_url'] ?? widget.request['profile_picture_url'] ?? widget.request['avatar_url'] ?? '');
    final isVerified = profile?['verified'] ?? widget.request['isVerified'] ?? true;
    final timeAgo = widget.request['timeAgo'] ?? 'Just now';
    final rating = profile?['rating']?.toString() ?? widget.request['rating']?.toString() ?? '5.0';
    
    final auraLevel = _extractAuraLevel(widget.request);
    final auraColor = getAuraColor(auraLevel);
    final pricingText = _getPricingText();
    final durationText = _getDurationText();
    
    final isOwnRequest = Supabase.instance.client.auth.currentUser?.id == widget.request['requester_id'];
    
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isBest ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF334155) : theme.dividerColor),
          width: widget.isBest ? 2.0 : 1.0
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15), 
            blurRadius: 20, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeBadge(type, theme),
                  if (widget.isBest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A03) : Colors.amber.shade100, 
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Row(children: [
                        Icon(
                          Icons.star_rounded, 
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706), 
                          size: 12
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "BEST MATCH", 
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold, 
                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)
                          ),
                        ),
                      ]),
                    )
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pricingText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: type == 'favour' ? kTealColor : (isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
                        ),
                      ),
                      if (durationText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(
                            Icons.schedule_rounded, 
                            size: 11, 
                            color: isDark ? Colors.grey.shade600 : const Color(0xFF94A3B8)
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'For $durationText', 
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w600, 
                              color: isDark ? Colors.grey.shade600 : const Color(0xFF94A3B8)
                            ),
                          ),
                        ]),
                      ]
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              if (!widget.isMinimized) ...[
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(
                    color: isDark ? const Color(0xFF334155) : theme.dividerColor, 
                    height: 1
                  ),
                ),
                Row(
                  children: [
                    AuraAvatar(
                      imageUrl: avatarUrl,
                      radius: 18,
                      auraColor: auraColor,
                      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                      fallbackChild: Text(
                        user.isNotEmpty ? user[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.black54, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14
                        )
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(
                                user,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified, color: kTealColor, size: 14)],
                          ]),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  rating, 
                                  style: TextStyle(
                                    fontSize: 11, 
                                    fontWeight: FontWeight.bold, 
                                    color: isDark ? Colors.grey.shade400 : const Color(0xFF475569)
                                  ),
                                ),
                                Text(
                                  ' • $distance', 
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)
                                  ),
                                ),
                                Text(
                                  ' • $timeAgo', 
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 90, 
                          height: 30,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final rawId = widget.request['id'];
                              if (rawId == null) return;
                              
                              final int reqId = rawId is int ? rawId : int.parse(rawId.toString());
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RequestDetailScreen(requestId: reqId),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.visibility_outlined, 
                              size: 14,
                              color: isDark ? Colors.grey.shade300 : Colors.white,
                            ), 
                            label: Text(
                              AppLocalizations.of(context)?.mapViewButton ?? 'View', 
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade300 : Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF26A69A), 
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                        
                        if (!isOwnRequest) ...[
                          const SizedBox(height: 6), 
                          SizedBox(
                            width: 90, 
                            height: 30,
                            child: ElevatedButton.icon(
                              onPressed: _isAccepting ? null : () => _acceptRequest(context),
                              icon: _isAccepting 
                                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(
                                      Icons.chat_bubble_outline_rounded, 
                                      size: 13,
                                      color: isDark ? Colors.grey.shade300 : Colors.white,
                                    ),
                              label: Text(
                                _isAccepting ? '...' : (AppLocalizations.of(context)?.mapChatButton ?? 'Chat'), 
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey.shade300 : Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                                foregroundColor: isDark ? Colors.grey.shade300 : Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 4), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                              ),
                            ),
                          )
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String resolveAvatarUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '';
}

Color getAuraColor(String? auraLevel) {
  if (auraLevel == null) return kTealColor;
  switch (auraLevel.toLowerCase()) {
    case 'gold': return const Color(0xFFF59E0B);
    case 'silver': return const Color(0xFF94A3B8);
    case 'platinum': return const Color(0xFF8B5CF6);
    case 'diamond': return const Color(0xFF06B6D4);
    case 'bronze': return const Color(0xFFCD7F32);
    default: return kTealColor;
  }
}