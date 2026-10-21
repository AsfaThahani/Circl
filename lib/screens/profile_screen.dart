import 'package:flutter/material.dart' hide Text;
import '../widgets/tamil_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../services/profile_service.dart';
import '../providers/settings_provider.dart';
import '../screens/wallet_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/reviews_screen.dart';
import '../screens/aura_points_screen.dart';
import '../screens/dispute_center_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/my_requests_screen.dart';
import 'accepted_requests_screen.dart';
import '../widgets/aura_avatar.dart';
import '../screens/nic_verification_screen.dart';
import '../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  late TabController _tabController;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _isUpdatingLocation = false;
  bool _isUploadingPicture = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _locationController.dispose();
    _homeAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final results = await Future.wait([
        _profileService.fetchProfile(user.id),
        _profileService.fetchMyRequests(user.id),
        _profileService.fetchMyReviews(user.id),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _myRequests = results[1] as List<Map<String, dynamic>>;
          _reviews = results[2] as List<Map<String, dynamic>>;
          _isLoading = false;

          _usernameController.text = _profile?['username'] ?? '';
          _locationController.text = _profile?['location'] ?? 'Sri Lanka';
          _homeAddressController.text = _profile?['home_address'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadProfilePicture() async {
    try {
      setState(() => _isUploadingPicture = true);

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) {
        setState(() => _isUploadingPicture = false);
        return;
      }

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final fileName =
          'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'profile-pictures/$fileName';

      await _supabase.storage.from('avatars').upload(
            filePath,
            File(pickedFile.path),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      await _supabase.from('profiles').update({
        'profile_picture_url': publicUrl,
      }).eq('id', user.id);

      setState(() {
        _profile?['profile_picture_url'] = publicUrl;
        _isUploadingPicture = false;
      });

      _showSnackBar('✅ Profile picture updated!');
    } catch (e) {
      debugPrint('Error uploading picture: $e');
      
      String errorMessage = 'Failed to upload picture';
      if (e.toString().contains('payload too large')) {
        errorMessage = '📸 Image too large! Please choose a smaller image.';
      } else if (e.toString().contains('Bucket not found')) {
        errorMessage = '📁 Storage bucket not found. Please contact support.';
      } else if (e.toString().contains('row-level security')) {
        errorMessage = '🔒 Permission denied. Please try again.';
      }
      
      _showSnackBar('$errorMessage: $e', isError: true);
      setState(() => _isUploadingPicture = false);
    }
  }

  Future<void> _getLocationFromGPS() async {
    try {
      setState(() => _isUpdatingLocation = true);

      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showSnackBar('Please login first', isError: true);
        setState(() => _isUpdatingLocation = false);
        return;
      }

      final status = await Permission.location.status;
      if (!status.isGranted) {
        final requested = await Permission.location.request();
        if (!requested.isGranted) {
          _showSnackBar('Location permission denied', isError: true);
          setState(() => _isUpdatingLocation = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _profileService.updateUserLocation(
        user.id,
        position.latitude,
        position.longitude,
      );

      setState(() {
        _locationController.text =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _profile?['location'] = _locationController.text;
        _profile?['latitude'] = position.latitude;
        _profile?['longitude'] = position.longitude;
        _isUpdatingLocation = false;
      });

      _showSnackBar('Location updated via GPS!');
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackBar('Error getting location: $e', isError: true);
      setState(() => _isUpdatingLocation = false);
    }
  }

  void _showLocationPickerDialog() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26A69A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF26A69A), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Set Your Location',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                InkWell(
                  onTap: _isUpdatingLocation
                      ? null
                      : () async {
                          setModalState(() => _isUpdatingLocation = true);
                          setState(() => _isUpdatingLocation = true);
                          await _getLocationFromGPS();
                          if (mounted) Navigator.pop(context);
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded, color: Color(0xFF26A69A)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Use Current Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 2),
                              const Text('Find location via GPS', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        if (_isUpdatingLocation)
                          const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF26A69A)),
                          )
                        else
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showManualLocationDialog();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_location_alt_rounded, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Enter Manually', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 2),
                              const Text('Type your city or address', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showManualLocationDialog() {
    final TextEditingController manualController = TextEditingController(text: _profile?['location'] ?? '');
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48, height: 5,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.edit_location_alt_rounded, color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 12),
                Text('Enter Location', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: manualController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'e.g., Colombo, Sri Lanka',
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.location_city_rounded, color: Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  final location = manualController.text.trim();
                  if (location.isNotEmpty) {
                    final user = _supabase.auth.currentUser;
                    if (user != null) {
                      await _supabase.from('profiles').update({'location': location}).eq('id', user.id);
                      setState(() {
                        _locationController.text = location;
                        _profile?['location'] = location;
                      });
                      _showSnackBar('Location updated!');
                    }
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    _usernameController.text = _profile?['username'] ?? '';
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 24),
                Text('Edit Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 24),
                
                Center(
                  child: Stack(
                    children: [
                      AuraAvatar(
                        imageUrl: _profile?['profile_picture_url'],
                        radius: 54,
                        auraColor: getAuraColor(_profile?['aura_level']), 
                        backgroundColor: theme.cardColor,
                        borderWidth: 2.0,
                        gapWidth: 4.0,
                      ),
                      Positioned(
                        bottom: 0, 
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            setModalState(() => _isUploadingPicture = true);
                            await _uploadProfilePicture();
                            setModalState(() => _isUploadingPicture = false);
                          },
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF26A69A),
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))
                              ],
                            ),
                            child: _isUploadingPicture
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                  )
                                : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                TextField(
                  controller: _usernameController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8)),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final user = _supabase.auth.currentUser;
                      if (user != null) {
                        await _supabase.from('profiles').update({
                          'username': _usernameController.text.trim(),
                        }).eq('id', user.id);
                        setState(() {
                          _profile?['username'] = _usernameController.text.trim();
                        });
                        _showSnackBar('✅ Profile updated');
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLogoutConfirmation() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.grey.shade300 : const Color(0xFF64748B),
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade700 : const Color(0xFFE2E8F0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _supabase.auth.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF26A69A))),
      );
    }

    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;
    
    final shadowOpacity = theme.brightness == Brightness.dark ? 0.02 : 0.0;
    final cardBorder = theme.brightness == Brightness.dark 
        ? Border.all(color: Colors.transparent) 
        : Border.all(color: Colors.grey.shade200, width: 1);

    final user = _supabase.auth.currentUser;
    final username = _profile?['username'] ?? user?.email?.split('@').first ?? 'User';
    final firstLetter = username.substring(0, 1).toUpperCase();
    final currentPoints = _profile?['circl_points'] ?? 0;
    final auraLevel = _profile?['aura_level'] ?? 'Bronze';
    final rating = (_profile?['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = _profile?['review_count'] ?? 0;
    final isVerified = _profile?['verified'] ?? false;
    final profilePictureUrl = _profile?['profile_picture_url'] as String?;
    
    final isNicVerified = _profile?['is_nic_verified'] ?? false;
    final verificationStatus = _profile?['verification_status'] ?? 'required';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 20, left: 4),
                child: Text(
                  l10n?.profileTitle ?? 'Profile & Settings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: cardBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: shadowOpacity),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        AuraAvatar(
                          imageUrl: profilePictureUrl,
                          radius: 40,
                          auraColor: getAuraColor(auraLevel),
                          backgroundColor: cardColor,
                          fallbackChild: Text(
                            firstLetter,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF26A69A),
                            ),
                          ),
                          borderWidth: 1.0,
                          glowOpacity: 0.16,
                          gapWidth: 4.0,
                        ),
                        if (isVerified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF26A69A),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.verified,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(username,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: textColor,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              Text('($reviewCount reviews)',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionHeader(l10n?.profileAccountHeader ?? 'Account', textColor),
              _buildSettingsCard(cardColor, cardBorder, shadowOpacity, [
                _buildSettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: l10n?.profileEditProfile ?? 'Edit Profile',
                  textColor: textColor,
                  onTap: _showEditProfileDialog,
                ),
                _buildDivider(),
                
                _buildSettingsTile(
                  icon: Icons.verified_user_outlined,
                  title: l10n?.profileIdentityVerification ?? 'Identity Verification',
                  textColor: textColor,
                  iconColor: isNicVerified 
                      ? Colors.green 
                      : (verificationStatus == 'pending' ? Colors.orange : const Color(0xFF26A69A)),
                  onTap: () {
                    if (isNicVerified) {
                      _showSnackBar('✅ ${l10n?.profileIdentityVerifiedToast ?? "Your identity is already verified."}');
                    } else if (verificationStatus == 'pending') {
                      _showSnackBar('⏳ ${l10n?.profileIdentityPendingToast ?? "Your verification is pending review."}');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FirstTimeNICVerificationScreen(
                            isFromProfile: true,
                            onVerificationComplete: () {
                              _loadData(); 
                            },
                            onSkip: (dontShowAgain) {
                              _loadData();
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildDivider(),
                
                _buildSettingsTile(
                  icon: Icons.location_on_outlined,
                  title: l10n?.profileLocationAddress ?? 'Location & Address',
                  textColor: textColor,
                  onTap: _showLocationPickerDialog,
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n?.profileWallet ?? 'Wallet',
                  trailingText: '',
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionHeader(l10n?.profileActivityHeader ?? 'Activity & Reputation', textColor),
              _buildSettingsCard(cardColor, cardBorder, shadowOpacity, [
                _buildSettingsTile(
                  icon: Icons.auto_awesome,
                  title: l10n?.profileAuraPointsTile ?? 'Aura & Circl Points',
                  subtitle: '$auraLevel • $currentPoints Points',
                  iconColor: const Color(0xFF26A69A),
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AuraPointsScreen(profile: _profile),
                    ),
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.list_alt_rounded,
                  title: l10n?.profilePostedRequestsTile ?? 'My Posted Requests',
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyRequestsScreen(),
                    ),
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.handshake_outlined,
                  title: l10n?.profileAcceptedRequestsTile ?? 'Accepted Requests',
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AcceptedRequestsScreen(),
                    ),
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.star_outline_rounded,
                  title: l10n?.profileReviewsTile ?? 'My Reviews',
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewsScreen(
                        userId: _supabase.auth.currentUser!.id, 
                        username: username,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionHeader(l10n?.profilePreferencesHeader ?? 'Preferences', textColor),
              _buildSettingsCard(cardColor, cardBorder, shadowOpacity, [
                _buildSettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: l10n?.profileDarkModeTile ?? 'Dark Mode',
                  textColor: textColor,
                  trailingWidget: Switch(
                    value: settings.isDarkMode,
                    activeThumbColor: const Color(0xFF26A69A),
                    onChanged: (val) => settings.toggleDarkMode(val),
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.language_rounded,
                  title: l10n?.profileLanguageTile ?? 'Language',
                  trailingText: settings.languageCode == 'en'
                      ? (l10n?.profileEnglish ?? 'English')
                      : settings.languageCode == 'si'
                          ? (l10n?.profileSinhala ?? 'සිංහල')
                          : (l10n?.profileTamil ?? 'தமிழ்'),
                  textColor: textColor,
                  onTap: () => _showLanguagePicker(context, settings),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.face_retouching_natural,
                  title: l10n?.profileBiometricsTile ?? 'Face ID / Biometrics',
                  subtitle: l10n?.profileBiometricsSubtitle ?? 'Verify identity for payments',
                  textColor: textColor,
                  trailingWidget: Switch(
                    value: settings.faceIdEnabled,
                    activeThumbColor: const Color(0xFF26A69A),
                    onChanged: (val) async {
                      final success = await settings.toggleBiometrics(val);
                      if (!success && val) {
                        _showSnackBar('Failed to enable biometrics',
                            isError: true);
                      } else if (success && val) {
                        _showSnackBar('✅ Biometrics enabled for payments');
                      }
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionHeader(l10n?.profileSupportHeader ?? 'Support & Security', textColor),
              _buildSettingsCard(cardColor, cardBorder, shadowOpacity, [
                _buildSettingsTile(
                  icon: Icons.gavel_rounded,
                  title: l10n?.profileDisputeTile ?? 'Dispute Center',
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DisputeCenterScreen(),
                    ),
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: l10n?.profileHelpFAQTile ?? 'Help & FAQ',
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FAQScreen()),
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.shield_outlined,
                  title: l10n?.profilePrivacyTile ?? 'Privacy Policy',
                  textColor: textColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
              ]),

              const SizedBox(height: 12),
              _buildSettingsCard(cardColor, cardBorder, shadowOpacity, [
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: l10n?.profileLogoutTile ?? 'Logout',
                  titleColor: Colors.redAccent,
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                  showTrailingArrow: false,
                  onTap: _showLogoutConfirmation,
                ),
              ]),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 16), 
      child: Text(title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7))),
    );
  }

  Widget _buildSettingsCard(Color cardColor, BoxBorder border, double shadowOpacity, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Color textColor,
    String? subtitle,
    String? trailingText,
    Widget? trailingWidget,
    Color? titleColor,
    Color? iconColor,
    bool showTrailingArrow = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF26A69A)).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? const Color(0xFF26A69A), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? textColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))
          : null,
      trailing: trailingWidget ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B)),
                ),
              if (trailingText != null && showTrailingArrow)
                const SizedBox(width: 8),
              if (showTrailingArrow)
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1), size: 22),
            ],
          ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor,
        indent: 56);
  }

  void _showLanguagePicker(BuildContext context, SettingsProvider settings) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n?.profileSelectLanguage ?? 'Select Language',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(l10n?.profileEnglish ?? 'English'),
              trailing: settings.languageCode == 'en'
                  ? const Icon(Icons.check, color: Color(0xFF26A69A))
                  : null,
              onTap: () {
                settings.changeLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n?.profileSinhala ?? 'සිංහල (Sinhala)'),
              trailing: settings.languageCode == 'si'
                  ? const Icon(Icons.check, color: Color(0xFF26A69A))
                  : null,
              onTap: () {
                settings.changeLanguage('si');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n?.profileTamil ?? 'தமிழ் (Tamil)'),
              trailing: settings.languageCode == 'ta'
                  ? const Icon(Icons.check, color: Color(0xFF26A69A))
                  : null,
              onTap: () {
                settings.changeLanguage('ta');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}