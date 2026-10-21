import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_signup_page.dart';
import '../screens/nic_verification_screen.dart';
import '../screens/admin_dispute_dashboard.dart';
import '../main_shell.dart';
import '../services/nic_verification_service.dart';
import '../services/request_service.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  final _supabase = Supabase.instance.client;
  late final NICVerificationService _nicService;
  late final RequestService _requestService;
  final _secureStorage = const FlutterSecureStorage();
  
  StreamSubscription<AuthState>? _authSubscription;
  
  bool _isInitializing = true;
  bool _hasSeenOnboarding = false;
  bool _isAuthenticated = false;
  bool _needsNICVerification = false;
  bool _isVerificationPending = false;
  
  User? _currentUser;
  
  Map<String, dynamic>? _preloadedProfile;
  List<Map<String, dynamic>> _preloadedRequests = [];

  @override
  void initState() {
    super.initState();
    _nicService = NICVerificationService();
    _requestService = RequestService();
    _initializeApp();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    debugPrint('⏱️ Splash started at: $startTime');
    
    await Future.wait([
      _checkOnboardingStatus(),
      _initializeAuthAndPreloadData(),
    ]);
    
    final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    const targetMs = 3000;
    
    if (elapsedMs < targetMs) {
      final remainingMs = targetMs - elapsedMs;
      debugPrint('⏱️ Initialization took ${elapsedMs}ms, waiting ${remainingMs}ms more');
      await Future.delayed(Duration(milliseconds: remainingMs));
    } else {
      debugPrint('⏱️ Initialization took ${elapsedMs}ms (already at/over 3 seconds)');
    }
    
    final totalMs = DateTime.now().difference(startTime).inMilliseconds;
    debugPrint('⏱️ Total splash time: ${totalMs}ms (${totalMs/1000} seconds)');
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }

    _authSubscription ??= _supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _currentUser = null;
            _needsNICVerification = false;
            _isVerificationPending = false;
            _preloadedProfile = null;
            _preloadedRequests = [];
          });
        }
      } else if (!_isInitializing) {
        await _handleAuthenticatedUser(user);
        if (mounted) {
          setState(() {}); 
        }
      }
    });
  }

  Future<void> _checkOnboardingStatus() async {
    // Force onboarding display for preview
    _hasSeenOnboarding = false; 
  }

  Future<void> _initializeAuthAndPreloadData() async {
    final currentSession = _supabase.auth.currentSession;
    
    if (currentSession?.user != null) {
      await _handleAuthenticatedUser(currentSession!.user);
    } else {
      _isAuthenticated = false;
      _currentUser = null;
    }
  }

  Future<void> _handleAuthenticatedUser(User user) async {
    try {
      final hideNicPrompt = await _secureStorage.read(key: 'hide_nic_prompt');

      final results = await Future.wait([
        _ensureProfileExists(user.id, user.email),
        _nicService.checkVerificationStatus().timeout(
          const Duration(seconds: 4),
          onTimeout: () => VerificationRequired.required,
        ),
        _requestService.fetchRequests().catchError((e) {
          debugPrint('Error preloading requests: $e');
          return <Map<String, dynamic>>[];
        }),
      ]);

      _currentUser = user;
      _isAuthenticated = true;
      _preloadedProfile = results[0] as Map<String, dynamic>?;
      final status = results[1] as VerificationRequired;
      _preloadedRequests = results[2] as List<Map<String, dynamic>>;
      
      _needsNICVerification = (status == VerificationRequired.required) && (hideNicPrompt != 'true');
      _isVerificationPending = (status == VerificationRequired.pending);

    } catch (e) {
      debugPrint('Error handling authenticated user: $e');
      _currentUser = user;
      _isAuthenticated = true;
      _needsNICVerification = true;
      _isVerificationPending = false;
    }
  }

  Future<Map<String, dynamic>?> _ensureProfileExists(String userId, String? email) async {
    try {
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (existingProfile == null) {
        final newProfile = {
          'id': userId,
          'username': email?.split('@').first ?? 'User',
          'location': 'Sri Lanka',
          'circl_points': 0,
          'aura_level': 'Bronze',
          'rating': 0.0,
          'review_count': 0,
          'verified': false,
          'is_nic_verified': false,
          'nic_skipped': false,
          'verification_status': 'none',
          'role': 'user',
        };
        
        await _supabase.from('profiles').insert(newProfile).timeout(const Duration(seconds: 4));
        debugPrint('Profile created for user: $userId with role: user');
        return newProfile;
      }
      return existingProfile;
    } catch (e) {
      debugPrint('Profile creation/fetch error: $e');
      return null;
    }
  }

  void completeOnboardingEvent() async {
    try {
      await _secureStorage.write(key: 'has_seen_onboarding_v1', value: 'true');
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = true;
        });
      }
    } catch (e) {
      debugPrint('Secure storage write error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const SplashScreen();
    }

    if (!_hasSeenOnboarding) {
      return OnboardingScreen(onFinishedCallback: completeOnboardingEvent);
    }

    if (!_isAuthenticated) {
      return const LoginSignupPage();
    }

    final String role = _preloadedProfile?['role'] ?? 'user';
    debugPrint('🔐 AppWrapper build - User role: $role');
    
    if (role == 'admin') {
      debugPrint('👑 Admin user detected in AppWrapper! Showing AdminDisputeDashboard');
      return const AdminDisputeDashboard();
    }

    if (_needsNICVerification) {
      return FirstTimeNICVerificationScreen(
        onVerificationComplete: () async {
          if (_currentUser != null) {
            await _handleAuthenticatedUser(_currentUser!);
            if (mounted) {
              setState(() {});
            }
          }
        },
        onSkip: (bool dontShowAgain) async {
          if (dontShowAgain) {
            await _secureStorage.write(key: 'hide_nic_prompt', value: 'true');
          }
          
          if (mounted) {
            setState(() {
              _needsNICVerification = false;
            });
          }
        },
      );
    }

    if (_isVerificationPending) {
      return _buildPendingVerificationScreen();
    }

    debugPrint('👤 Regular user detected in AppWrapper! Showing MainShell');
    return MainShell(
      preloadedRequests: _preloadedRequests,
      hasPreloadedData: true,
      preloadedProfile: _preloadedProfile,
      hasPreloadedProfile: _preloadedProfile != null,
    );
  }

  Widget _buildPendingVerificationScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 40,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verification Pending',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your NIC verification is being reviewed by our team.\nYou will be notified once approved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_currentUser != null) {
                    await _handleAuthenticatedUser(_currentUser!);
                    if (mounted) {
                      setState(() {});
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Check Status'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _isVerificationPending = false;
                    });
                  }
                },
                child: const Text(
                  'Continue to App',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
