import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import '../widgets/tamil_text.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../l10n/app_localizations.dart';

const Color kTealColor = Color(0xFF26A69A);
const Color kSystemBlack = Color(0xFF18181B); // Sleek dark system color

List<BoxShadow> getActiveShadow(bool isDark) {
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
      blurRadius: 12,
      offset: const Offset(0, 6),
    )
  ];
}

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _timeCommitmentController = TextEditingController();
  
  final _priceController = TextEditingController(text: '500');
  final _depositController = TextEditingController(text: '1000');
  final _durationController = TextEditingController(text: '1');

  String _selectedType = 'borrow';
  double _radius = 5.0;
  
  double _maxPrice = 500;
  double _maxDeposit = 1000;
  int _durationValue = 1;
  
  String _durationUnit = 'days';
  final List<String> _durationUnits = ['hours', 'days', 'weeks', 'months'];
  
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isPosting = false;
  int _currentStep = 0;
  String? _homeAddress;
  String? _gpsAddress;
  List<String> _savedAddresses = [];
  
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _depositFocusNode = FocusNode();
  
  final Map<String, String> _addressCache = {};

  bool _showResult = false;
  Map<String, dynamic>? _bestMatch;

  bool _hasWarnedDescription = false;
  String _locationPreference = 'in_person'; 

  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearchingSuggestions = false;
  Timer? _autocompleteDebounce;
  String? _verifiedAddress;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  String? _systemMessage;
  IconData _systemMessageIcon = Icons.info_outline;
  Timer? _systemMessageTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _addressFocusNode.addListener(_onAddressFocusChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    _addressFocusNode.removeListener(_onAddressFocusChanged);
    _autocompleteDebounce?.cancel();
    _systemMessageTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _timeCommitmentController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _durationController.dispose();
    
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _addressFocusNode.dispose();
    _priceFocusNode.dispose();
    _depositFocusNode.dispose();
    super.dispose();
  }
  void _showSystemMessage(String message, {IconData icon = Icons.info_outline}) {
    setState(() {
      _systemMessage = message;
      _systemMessageIcon = icon;
    });
    
    _systemMessageTimer?.cancel();
    _systemMessageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _systemMessage = null;
        });
      }
    });
  }

  void _hideSystemMessage() {
    setState(() {
      _systemMessage = null;
    });
    _systemMessageTimer?.cancel();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('profiles')
            .select('home_address, saved_addresses')
            .eq('id', user.id)
            .maybeSingle();
        
        if (response != null) {
          if (response['home_address'] != null && response['home_address'].toString().isNotEmpty) {
            setState(() {
              _homeAddress = response['home_address'].toString();
            });
          }
          if (response['saved_addresses'] != null) {
            final addresses = response['saved_addresses'] as List?;
            if (addresses != null) {
              setState(() {
                _savedAddresses = addresses.map((e) => e.toString()).toList();
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved addresses: $e');
    }
  }

  Future<void> _saveNewAddress(String address) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      setState(() => _savedAddresses.add(address));
      await _supabase.from('profiles').update({'saved_addresses': _savedAddresses}).eq('id', user.id);
      _showSystemMessage('Address saved!', icon: Icons.check_circle_outline);
    } catch (e) {
      debugPrint('Error saving address: $e');
      _showSystemMessage('Failed to save address', icon: Icons.error_outline);
    }
  }

  Future<void> _showAddAddressDialog() async {
    final TextEditingController newAddressController = TextEditingController();
    final theme = Theme.of(context);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_location_rounded, color: kTealColor, size: 24),
            const SizedBox(width: 8),
            Text('Save New Address', style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Save this address for quick access in future requests.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor, 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor, width: 1.5),
              ),
              child: TextField(
                controller: newAddressController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Enter address or landmark',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8)),
                ),
                maxLines: 2,
                autofocus: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newAddressController.text.trim().isNotEmpty) {
                await _saveNewAddress(newAddressController.text.trim());
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Address', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(String title, String message) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.bottomSheetTheme.backgroundColor ?? theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: kTealColor, size: 28),
                  const SizedBox(width: 12),
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 16),
              Text(message, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), height: 1.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTealColor,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    if (_addressCache.containsKey(cacheKey)) return _addressCache[cacheKey]!;
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        Set<String> addressParts = {};
        if (place.name != null && place.name!.isNotEmpty) addressParts.add(place.name!);
        if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) addressParts.add(place.subThoroughfare!);
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) addressParts.add(place.thoroughfare!);
        if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
        
        final address = addressParts.isNotEmpty ? addressParts.join(', ') : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        _addressCache[cacheKey] = address;
        return address;
      }
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    } catch (e) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSystemMessage('Location services are disabled.', icon: Icons.location_off_outlined);
        setState(() => _isLoadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSystemMessage('Location permissions are denied.', icon: Icons.block);
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSystemMessage('Location permissions are permanently denied.', icon: Icons.block);
        setState(() => _isLoadingLocation = false);
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      setState(() {
        _currentPosition = position;
        _gpsAddress = 'Loading address...';
      });
      _getAddressFromLatLng(position.latitude, position.longitude).then((address) {
        if (mounted) {
          setState(() {
            _gpsAddress = address;
            _verifiedAddress = address;
          });
          _showSystemMessage('Location captured!', icon: Icons.my_location);
        }
      });
    } catch (e) {
      _showSystemMessage('Could not get location', icon: Icons.error_outline);
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _onAddressFocusChanged() {
    if (!_addressFocusNode.hasFocus) {
      _hideOverlay();
    } else {
      if (_addressController.text.trim().length >= 3) {
        _showOverlay();
      }
    }
  }

  void _showOverlay() {
    _hideOverlay();
    final theme = Theme.of(context);
    final renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.cardColor,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: _isSearchingSuggestions
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kTealColor),
                        ),
                      ),
                    )
                  : _suggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off_outlined, color: Color(0xFF94A3B8), size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No locations found. Keep typing...',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) => Divider(color: theme.dividerColor, height: 1),
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined, color: kTealColor, size: 18),
                              title: Text(
                                suggestion['display_name'],
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                              onTap: () => _selectSuggestion(suggestion),
                            );
                          },
                        ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  String _stripHouseNumber(String query) {
    final regex = RegExp(r'^(?:No\.?\s*)?\d+[\d\s/A-Za-z-]*[,\s]\s*', caseSensitive: false);
    if (regex.hasMatch(query)) {
      return query.replaceFirst(regex, '');
    }
    return query;
  }

  Future<List<Map<String, dynamic>>> _queryNominatim(String query) async {
    try {
      final client = HttpClient();
      client.userAgent = 'circl-app/1.0.0 (contact: support@circl.com)';
      String url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1&countrycodes=lk';
      if (_currentPosition != null) {
        final lat = _currentPosition!.latitude;
        final lng = _currentPosition!.longitude;
        const delta = 2.0; 
        url += '&viewbox=${lng - delta},${lat + delta},${lng + delta},${lat - delta}';
      }
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> data = json.decode(responseBody);
        return data.map((item) {
          return {
            'display_name': item['display_name'] as String,
            'lat': double.parse(item['lat'].toString()),
            'lon': double.parse(item['lon'].toString()),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Nominatim query error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getAddressSuggestions(String query) async {
    if (query.trim().length < 3) return [];
    List<Map<String, dynamic>> results = await _queryNominatim(query);
    if (results.isEmpty) {
      final cleanedQuery = _stripHouseNumber(query);
      if (cleanedQuery != query && cleanedQuery.trim().length >= 3) {
        results = await _queryNominatim(cleanedQuery);
      }
    }
    return results;
  }

  void _fetchAddressSuggestions(String query) {
    if (_autocompleteDebounce?.isActive ?? false) _autocompleteDebounce!.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      _hideOverlay();
      return;
    }
    _autocompleteDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearchingSuggestions = true);
      _showOverlay();
      final results = await _getAddressSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearchingSuggestions = false;
        });
        _showOverlay();
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    String finalName = suggestion['display_name'];
    final originalQuery = _addressController.text.trim();
    final prefixRegex = RegExp(r'^(?:No\.?\s*)?\d+[\d\s/A-Za-z-]*[,\s]\s*', caseSensitive: false);
    final prefixMatch = prefixRegex.firstMatch(originalQuery);
    if (prefixMatch != null) {
      final prefix = prefixMatch.group(0)!;
      if (!finalName.toLowerCase().startsWith(prefix.trim().toLowerCase())) {
        finalName = '$prefix$finalName';
      }
    }

    setState(() {
      _addressController.text = finalName;
      _currentPosition = Position(
        latitude: suggestion['lat'],
        longitude: suggestion['lon'],
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      _verifiedAddress = finalName;
      _suggestions = [];
    });
    _hideOverlay();
    _addressFocusNode.unfocus();
  }

  void _validateAndNextStep() {
    if (_currentStep == 0) {
      if (_titleController.text.trim().isEmpty) {
        _showSystemMessage('Title is a required field. Please enter a title.', icon: Icons.warning_amber_rounded);
        _titleFocusNode.requestFocus();
        return;
      }
      if (_descriptionController.text.isEmpty && !_hasWarnedDescription) {
        _showSystemMessage('Pro tip: Adding a description gets more responses!', icon: Icons.lightbulb_outline);
        _hasWarnedDescription = true;
        return;
      }
      _nextStep();
    } else if (_currentStep == 1) {
      if (_locationPreference != 'remote' && _addressController.text.trim().isEmpty && _gpsAddress == null) {
        _showSystemMessage('Please provide a location or select "Remote"', icon: Icons.location_off_outlined);
        return;
      }
      _nextStep();
    } else {
      if (!_isPosting) _submitRequest();
    }
  }

  Future<void> _submitRequest() async {
    _hideOverlay();
    if (!_formKey.currentState!.validate()) return;
    
    final address = _addressController.text.trim().isEmpty ? (_gpsAddress) : _addressController.text.trim();
    final isStrictlyRemote = _locationPreference == 'remote';
    final finalAddress = isStrictlyRemote ? 'Remote / Online Task' : address;
    final finalRadius = isStrictlyRemote ? 0 : _radius.round();

    if (finalAddress == null && !isStrictlyRemote) {
      _showSystemMessage('Please provide an address or select "Remote".', icon: Icons.warning_amber_rounded);
      return;
    }
    
    _maxPrice = double.tryParse(_priceController.text) ?? 0;
    _maxDeposit = double.tryParse(_depositController.text) ?? 0;
    _durationValue = int.tryParse(_durationController.text) ?? 1;

    setState(() => _isPosting = true);

    double resolvedLat = 7.8731;
    double resolvedLng = 80.7718;

    if (!isStrictlyRemote) {
      if (finalAddress == _verifiedAddress && _currentPosition != null) {
        resolvedLat = _currentPosition!.latitude;
        resolvedLng = _currentPosition!.longitude;
      } else if (finalAddress == _gpsAddress && _currentPosition != null) {
        resolvedLat = _currentPosition!.latitude;
        resolvedLng = _currentPosition!.longitude;
        _verifiedAddress = finalAddress;
      } else {
        try {
          final locations = await locationFromAddress(finalAddress!);
          if (locations.isNotEmpty) {
            resolvedLat = locations.first.latitude;
            resolvedLng = locations.first.longitude;
            _verifiedAddress = finalAddress;
            _currentPosition = Position(
              latitude: resolvedLat,
              longitude: resolvedLng,
              timestamp: DateTime.now(),
              accuracy: 1.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            );
          } else {
            _showSystemMessage('Could not resolve address. Please check spelling.', icon: Icons.warning_amber_rounded);
            setState(() => _isPosting = false);
            return;
          }
        } catch (e) {
          debugPrint('Geocoding error for address "$finalAddress": $e');
          _showSystemMessage('Could not resolve address. Please check spelling.', icon: Icons.warning_amber_rounded);
          setState(() => _isPosting = false);
          return;
        }
      }
    } else {
      resolvedLat = 0.0;
      resolvedLng = 0.0;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showSystemMessage('Please log in to post a request', icon: Icons.lock_outline);
        return;
      }

      final requestData = {
        'requester_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType,
        'location_preference': _locationPreference, 
        'latitude': resolvedLat,
        'longitude': resolvedLng,
        'radius_km': finalRadius,
        'address': finalAddress,
        'status': 'open',
        'is_available': true,
        'created_at': DateTime.now().toIso8601String(),
        'duration_value': _durationValue,
        'duration_unit': _durationUnit,
      };

      if (_selectedType == 'borrow') {
        requestData['max_deposit'] = _maxDeposit;
      } else if (_selectedType == 'rent') {
        requestData['max_price'] = _maxPrice;
        requestData['max_deposit'] = _maxDeposit;
        requestData['price_unit'] = 'day';
      } else if (_selectedType == 'paid') {
        requestData['max_price'] = _maxPrice;
        requestData['price_unit'] = 'one_time';
      }

      await _supabase.from('requests').insert(requestData).select();
      setState(() { _showResult = true; });
      _clearForm();
    } catch (e) {
      _showSystemMessage('Failed to post request: ${e.toString()}', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _clearForm() {
    _hideOverlay();
    _titleController.clear();
    _descriptionController.clear();
    _addressController.clear();
    _priceController.text = '500';
    _depositController.text = '1000';
    _durationController.text = '1';
    _currentPosition = null;
    _gpsAddress = null;
    _radius = 5.0;
    _selectedType = 'borrow';
    _currentStep = 0;
    _locationPreference = 'in_person';
    _hasWarnedDescription = false;
  }

  void _nextStep() {
    _hideOverlay();
    if (_currentStep < 2) {
      setState(() {
        _maxPrice = double.tryParse(_priceController.text) ?? 0;
        _maxDeposit = double.tryParse(_depositController.text) ?? 0;
        _durationValue = int.tryParse(_durationController.text) ?? 1;
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    _hideOverlay();
    setState(() => _currentStep > 0 ? _currentStep-- : null);
  }

  String _getFormattedDuration() {
    String unit = _durationUnit;
    if (_durationValue == 1) {
      unit = unit.substring(0, unit.length - 1);
    }
    return '$_durationValue $unit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (_showResult) return _buildResultScreen(theme);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.postTitle ?? 'Create Request',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.colorScheme.onSurface)),
        leading: _currentStep > 0
            ? IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface), onPressed: _prevStep)
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: _buildStepLoader(theme),
        ),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              key: _formKey,
              child: _buildStepContent(theme, isDark),
            ),
          ),
          if (_systemMessage != null)
            Positioned(
              bottom: isKeyboardOpen ? 16 : 90,
              left: 24,
              right: 24,
              child: Material(
                color: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: kSystemBlack,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(_systemMessageIcon, color: kTealColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _systemMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _hideSystemMessage,
                        child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepLoader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          _buildStepBar(0, theme), const SizedBox(width: 8),
          _buildStepBar(1, theme), const SizedBox(width: 8),
          _buildStepBar(2, theme),
        ],
      ),
    );
  }

  Widget _buildStepBar(int stepIndex, ThemeData theme) {
    final isCompleted = _currentStep >= stepIndex;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut, 
        height: 3,
        decoration: BoxDecoration(
          color: isCompleted ? kTealColor : theme.dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme, bool isDark) {
    if (_currentStep == 1) {
      return _buildStepLocation(theme, isDark);
    } else if (_currentStep == 2) {
      return _buildStepPreview(theme);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)?.postQuestion ?? 'What do you need?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(child: _buildTypeCard('Borrow', 'Free of charge', 'borrow', Icons.volunteer_activism_outlined, theme, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildTypeCard('Rent', 'Paid item rental', 'rent', Icons.vpn_key_outlined, theme, isDark)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTypeCard('Favour', 'Free community help', 'favour', Icons.favorite_border_rounded, theme, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildTypeCard('Task', 'Paid service request', 'paid', Icons.assignment_outlined, theme, isDark)),
            ],
          ),
          
          const SizedBox(height: 36),
          if (_selectedType != 'favour') ...[
            _buildRangeFieldsBasedOnType(theme, isDark),
            const SizedBox(height: 32),
          ],
          _buildDurationFields(theme),
          const SizedBox(height: 36),
          Text(AppLocalizations.of(context)?.postDetails ?? 'Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 16),
          _buildTextField(
            theme: theme,
            controller: _titleController,
            label: AppLocalizations.of(context)?.postFieldTitle ?? 'Title',
            hint: AppLocalizations.of(context)?.postFieldTitleHint ?? 'e.g., Need a pressure washer',
            icon: Icons.title_rounded,
            focusNode: _titleFocusNode,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            theme: theme,
            controller: _descriptionController,
            label: AppLocalizations.of(context)?.postFieldDescription ?? 'Description',
            hint: AppLocalizations.of(context)?.postFieldDescHint ?? 'Describe condition, requirements...',
            icon: Icons.notes_rounded,
            maxLines: 4,
            focusNode: _descriptionFocusNode,
          ),
          const SizedBox(height: 40),
          _buildInlineButtons(theme),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String title, String subtitle, String type, IconData icon, ThemeData theme, bool isDark) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () { 
        HapticFeedback.lightImpact(); 
        setState(() => _selectedType = type); 
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kTealColor : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? Border.all(color: Colors.transparent, width: 1.5) 
              : Border.all(color: theme.dividerColor, width: 1.5),
          boxShadow: isSelected ? getActiveShadow(isDark) : [], 
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : theme.inputDecorationTheme.fillColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : kTealColor, size: 24),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(AppLocalizations.of(context)?.postDuration ?? 'Expected Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showInfoSheet('Expected Duration', 'Exact duration and dates will be finalized in chat.'),
              child: const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
            )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor, 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepperButton(Icons.remove, () {
                      int current = int.tryParse(_durationController.text) ?? 1;
                      if (current > 1) setState(() => _durationController.text = (current - 1).toString());
                    }),
                    Container(
                      width: 64,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: theme.dividerColor, width: 1.5),
                      ),
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        decoration: const InputDecoration(
                          border: InputBorder.none, 
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          filled: false,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _durationValue = int.tryParse(val) ?? 1;
                          });
                        },
                      ),
                    ),
                    _buildStepperButton(Icons.add, () {
                      int current = int.tryParse(_durationController.text) ?? 1;
                      setState(() => _durationController.text = (current + 1).toString());
                    }),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: theme.dividerColor),
              Expanded(
                flex: 4,
                child: PopupMenuButton<String>(
                  initialValue: _durationUnit,
                  position: PopupMenuPosition.under,
                  elevation: 4,
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (String newValue) {
                    setState(() => _durationUnit = newValue);
                  },
                  itemBuilder: (BuildContext context) {
                    return _durationUnits.map((String unit) {
                      bool isSelected = _durationUnit == unit;
                      return PopupMenuItem<String>(
                        value: unit,
                        child: Text(
                          unit[0].toUpperCase() + unit.substring(1),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? kTealColor : theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_durationUnit[0].toUpperCase() + _durationUnit.substring(1),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: kTealColor, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildRangeFieldsBasedOnType(ThemeData theme, bool isDark) {
    if (_selectedType == 'borrow') return _buildDepositInput(theme, isDark);
    if (_selectedType == 'rent') return Column(children: [_buildPriceInput(theme, isDark), const SizedBox(height: 32), _buildDepositInput(theme, isDark)]);
    if (_selectedType == 'paid') return Column(children: [_buildPriceInput(theme, isDark), const SizedBox(height: 16), _buildEscrowInfoCard(theme)]);
    return const SizedBox();
  }

  Widget _buildEscrowInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kTealColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.security_rounded, size: 20, color: kTealColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)?.postEscrowTitle ?? 'Payment Protection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)?.postEscrowDesc ?? 'Payment held in escrow. Released only when you confirm completion.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInput(ThemeData theme, bool isDark) {
    final isFocused = _priceFocusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(AppLocalizations.of(context)?.postBudget ?? 'Maximum Budget', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.colorScheme.onSurface)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showInfoSheet('Maximum Budget', 'Set the absolute maximum you are willing to pay. Providers can offer to do it for less.'),
              child: const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
            )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor, 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isFocused ? kTealColor : theme.dividerColor, width: isFocused ? 2.0 : 1.5),
          ),
          child: TextField(
            controller: _priceController,
            focusNode: _priceFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            decoration: const InputDecoration(
              prefixText: 'LKR ',
              prefixStyle: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w600),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: false,
            ),
            onChanged: (val) => setState(() => _maxPrice = double.tryParse(val) ?? 0),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: [500, 1000, 2500, 5000].map((amount) {
            bool isSelected = _priceController.text == amount.toString();
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() { _priceController.text = amount.toString(); _maxPrice = amount.toDouble(); });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? kTealColor : theme.cardColor,
                  borderRadius: BorderRadius.circular(19),
                  border: isSelected ? Border.all(color: Colors.transparent, width: 1.5) : Border.all(color: theme.dividerColor, width: 1.5),
                ),
                child: Text('$amount', style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDepositInput(ThemeData theme, bool isDark) {
    final isFocused = _depositFocusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(AppLocalizations.of(context)?.postDeposit ?? 'Security Deposit Limit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.colorScheme.onSurface)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showInfoSheet('Security Deposit', '100% refunded to you as soon as the item is returned.'),
              child: const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
            )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor, 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isFocused ? kTealColor : theme.dividerColor, width: isFocused ? 2.0 : 1.5),
          ),
          child: TextField(
            controller: _depositController,
            focusNode: _depositFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            decoration: const InputDecoration(
              prefixText: 'LKR ',
              prefixStyle: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w600),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: false,
            ),
            onChanged: (val) => setState(() => _maxDeposit = double.tryParse(val) ?? 0),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: [0, 1000, 5000, 10000].map((amount) {
            bool isSelected = _depositController.text == amount.toString();
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() { _depositController.text = amount.toString(); _maxDeposit = amount.toDouble(); });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? kTealColor : theme.cardColor,
                  borderRadius: BorderRadius.circular(19),
                  border: isSelected ? Border.all(color: Colors.transparent, width: 1.5) : Border.all(color: theme.dividerColor, width: 1.5),
                ),
                child: Text(amount == 0 ? 'None' : '$amount', style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrefSegment(String title, String value, IconData icon, ThemeData theme, bool isDark) {
    bool isSelected = _locationPreference == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _locationPreference = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? kTealColor : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: Colors.transparent, width: 1.5) : Border.all(color: theme.dividerColor, width: 1.5),
            boxShadow: isSelected ? getActiveShadow(isDark) : [],
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepLocation(ThemeData theme, bool isDark) {
    final isAddressFocused = _addressFocusNode.hasFocus;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)?.postHowDone ?? 'How do you need this done?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildPrefSegment('In-Person', 'in_person', Icons.location_on_rounded, theme, isDark),
              const SizedBox(width: 12),
              _buildPrefSegment('Flexible', 'flexible', Icons.video_call_rounded, theme, isDark),
              const SizedBox(width: 12),
              _buildPrefSegment('Remote', 'remote', Icons.language_rounded, theme, isDark),
            ],
          ),
          const SizedBox(height: 36),

          if (_locationPreference != 'remote') ...[
            Text(AppLocalizations.of(context)?.postWhereDone ?? 'Where do you need this?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.my_location_rounded, color: kTealColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)?.postCurrentLocation ?? 'Current Location', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 4),
                            Text(_gpsAddress ?? (AppLocalizations.of(context)?.postDetectLocation ?? 'Tap to detect location'), style: TextStyle(fontSize: 12, color: _gpsAddress != null ? Colors.green.shade500 : const Color(0xFF94A3B8))),
                          ],
                        )
                      ),
                      if (_isLoadingLocation)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kTealColor))
                      else
                        IconButton(icon: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF94A3B8)), onPressed: _getCurrentLocation)
                    ],
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(color: theme.dividerColor, height: 1)),
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: Container(
                      key: _textFieldKey,
                      decoration: BoxDecoration(
                        color: theme.inputDecorationTheme.fillColor, 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isAddressFocused ? kTealColor : theme.dividerColor, width: isAddressFocused ? 2.0 : 1.5),
                      ),
                      child: TextField(
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onChanged: (val) {
                          if (_verifiedAddress != val) _verifiedAddress = null;
                          _fetchAddressSuggestions(val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Type address or select saved...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 20),
                          suffixIcon: PopupMenuButton<String>(
                            icon: const Icon(Icons.bookmark_border_rounded, color: kTealColor),
                            tooltip: 'Saved Addresses',
                            color: theme.cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (val) async {
                              if (val == '__add_new__') { 
                                await _showAddAddressDialog(); 
                              } else { 
                                setState(() { _addressController.text = val; _verifiedAddress = null; }); 
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(enabled: false, child: Text('Saved Locations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)))),
                              if (_homeAddress?.isNotEmpty ?? false) 
                                PopupMenuItem(value: _homeAddress, child: Row(children: [const Icon(Icons.home_rounded, size: 18, color: kTealColor), const SizedBox(width: 12), Expanded(child: Text('Home', style: TextStyle(fontWeight: FontWeight.w500)))])),
                              for (var addr in _savedAddresses)
                                PopupMenuItem(value: addr, child: Row(children: [const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF64748B)), const SizedBox(width: 12), Expanded(child: Text(addr, overflow: TextOverflow.ellipsis))])),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: '__add_new__',
                                child: Row(children: [Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: kTealColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.add, size: 16, color: kTealColor)), const SizedBox(width: 12), const Text('Save new address', style: TextStyle(color: kTealColor, fontWeight: FontWeight.w600))]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(AppLocalizations.of(context)?.postSearchRangeTitle ?? 'How far are you searching?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Maximum Distance', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)), Text('${_radius.round()} km', style: const TextStyle(color: kTealColor, fontWeight: FontWeight.w700, fontSize: 16))]),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderThemeData(activeTrackColor: kTealColor, inactiveTrackColor: theme.dividerColor, thumbColor: kTealColor, overlayColor: kTealColor.withValues(alpha: 0.1), trackHeight: 6),
                    child: Slider(value: _radius, min: 1, max: 50, onChanged: (val) => setState(() => _radius = val)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [5, 10, 25, 50].map((amount) {
                      bool isSelected = _radius.round() == amount;
                      return GestureDetector(
                        onTap: () { HapticFeedback.lightImpact(); setState(() => _radius = amount.toDouble()); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: isSelected ? kTealColor : theme.cardColor, borderRadius: BorderRadius.circular(19), border: Border.all(color: isSelected ? Colors.transparent : theme.dividerColor)),
                          child: Text('$amount km', style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kTealColor.withValues(alpha: 0.3))),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kTealColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.language_rounded, color: kTealColor, size: 24)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Remote Task', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)), const SizedBox(height: 4), const Text('This task will be posted for remote/online completion. No physical location needed.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4))])),
                ],
              ),
            )
          ],
          const SizedBox(height: 40),
          _buildInlineButtons(theme),
        ],
      ),
    );
  }

  Widget _buildStepPreview(ThemeData theme) {
    final isStrictlyRemote = _locationPreference == 'remote';
    final displayAddress = isStrictlyRemote 
        ? 'Remote / Online Task'
        : (_addressController.text.isNotEmpty ? _addressController.text : (_gpsAddress ?? (_currentPosition != null ? 'Current location (GPS)' : 'No address provided')));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)?.postReviewDetailsTitle ?? 'Review Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: kTealColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_selectedType.toUpperCase(), style: const TextStyle(color: kTealColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
                    if (_locationPreference == 'remote' || _locationPreference == 'flexible')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _locationPreference == 'remote' ? kTealColor.withValues(alpha: 0.1) : theme.inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            Icon(_locationPreference == 'remote' ? Icons.language_rounded : Icons.video_call_rounded, size: 14, color: _locationPreference == 'remote' ? kTealColor : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(_locationPreference == 'remote' ? 'REMOTE' : 'FLEXIBLE', style: TextStyle(color: _locationPreference == 'remote' ? kTealColor : const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(_titleController.text.isEmpty ? 'Untitled Request' : _titleController.text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 12),
                Text(_descriptionController.text.isEmpty ? 'No description provided.' : _descriptionController.text, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), height: 1.6, fontSize: 14)),
                Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Divider(color: theme.dividerColor, height: 1)),
                _buildPreviewRow(theme, Icons.access_time_rounded, _getFormattedDuration()),
                const SizedBox(height: 16),
                if (_selectedType == 'rent' || _selectedType == 'paid')
                  _buildPreviewRow(theme, Icons.account_balance_wallet_rounded, 'Budget: LKR ${_maxPrice.toStringAsFixed(0)}${_selectedType == 'rent' ? '/day' : ''}'),
                if (_selectedType == 'borrow' || _selectedType == 'rent') ...[
                  const SizedBox(height: 16),
                  _buildPreviewRow(theme, Icons.shield_rounded, 'Deposit limit: LKR ${_maxDeposit.toStringAsFixed(0)}'),
                ],
                const SizedBox(height: 16),
                _buildPreviewRow(theme, isStrictlyRemote ? Icons.language_rounded : Icons.location_on_rounded, displayAddress),
                if (!isStrictlyRemote) ...[
                  const SizedBox(height: 16),
                  _buildPreviewRow(theme, Icons.radar_rounded, 'Search within ${_radius.round()} km'),
                ]
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildInlineButtons(theme),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: kTealColor)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w500))),
      ],
    );
  }
  Widget _buildInlineButtons(ThemeData theme) {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: _prevStep,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.cardColor,
                side: BorderSide(color: theme.dividerColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _validateAndNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealColor,
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isPosting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_currentStep == 2 ? 'Post Request' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required ThemeData theme, required TextEditingController controller, required String label, required String hint, required IconData icon, int maxLines = 1, FocusNode? focusNode}) {
    final focusNodeLocal = focusNode ?? FocusNode();
    final isFocused = focusNodeLocal.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor, 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isFocused ? kTealColor : theme.dividerColor, width: isFocused ? 2.0 : 1.5),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            focusNode: focusNodeLocal,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen(ThemeData theme) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Container(
                padding: const EdgeInsets.all(16), 
                decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.2), width: 2)), 
                child: const Icon(Icons.check_circle_rounded, size: 56, color: Color(0xFF26A69A))
              ),
              const SizedBox(height: 24),
              Text('Request Posted', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 15),
              const Text('All set! Your request is live and the community will reach out soon.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() { _showResult = false; _clearForm(); }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTealColor,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Create Another', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}