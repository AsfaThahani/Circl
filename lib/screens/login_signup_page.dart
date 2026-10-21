import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/admin_dispute_dashboard.dart';
import '../screens/feed_screen.dart';

class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});

  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSubscription;

  
  bool _rememberMe = false;
  bool _acceptTerms = false;

  
  bool _loginObscurePassword = true;
  bool _signupObscurePassword = true;
  bool _signupObscureConfirmPassword = true;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }
  Future<void> _routeUser(String userId) async {
    try {
      debugPrint('🔍 Routing user: $userId');
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      debugPrint('📋 Profile data: $profile');

      if (!mounted) return;
      if (profile != null && profile['role'] == 'admin') {
        debugPrint('👑 Admin user detected, navigating to Admin Dashboard');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminDisputeDashboard()),
          (route) => false,
        );
      } else {
        debugPrint('👤 Regular user detected, navigating to Feed Screen');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const FeedScreen()), 
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error routing user: $e');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const FeedScreen()), 
          (route) => false,
        );
      }
    }
  }
  void _setupAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final event = data.event;
      
      debugPrint('🔔 Auth event: $event, Session: ${session != null}');
      if (session != null && event == AuthChangeEvent.signedIn && mounted) {
        debugPrint('✅ User signed in, ensuring profile exists...');
        await _ensureProfileExists(session.user.id, session.user.email);
        await Future.delayed(const Duration(milliseconds: 500));
        
        debugPrint('🚀 Routing user...');
        await _routeUser(session.user.id);
      }
    });
    _checkInitialAuth();
  }
  void _checkInitialAuth() async {
    final session = _supabase.auth.currentSession;
    debugPrint('🔍 Checking initial auth: ${session != null}');
    
    if (session != null && mounted) {
      await _ensureProfileExists(session.user.id, session.user.email);
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();
          
      debugPrint('📋 Initial auth profile: $profile');
          
      if (mounted) {
        if (profile != null && profile['role'] == 'admin') {
          debugPrint('👑 Admin user detected on initial auth');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminDisputeDashboard()),
            (route) => false,
          );
        } else {
          debugPrint('👤 Regular user detected on initial auth');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const FeedScreen()),
            (route) => false,
          );
        }
      }
    }
  }
  Future<void> _ensureProfileExists(String userId, String? email) async {
    try {
      debugPrint('📝 Ensuring profile exists for user: $userId');
      
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (existingProfile == null) {
        String username = email?.split('@').first ?? 'User';
        
        debugPrint('🆕 Creating new profile for user: $userId with username: $username');
        
        await _supabase.from('profiles').insert({
          'id': userId,
          'username': username,
          'role': 'user', // 👈 CRITICAL: Set default role for new users
          'location': 'Sri Lanka',
          'circl_points': 0,
          'aura_level': 'Bronze',
          'rating': 0.0,
          'review_count': 0,
          'verified': false,
          'is_nic_verified': false,
          'nic_skipped': false,
          'nic_hash': null,
        });
        
        debugPrint('✅ Fallback profile created for: $userId with role: user');
      } else {
        debugPrint('✅ Profile already exists for user: $userId');
        debugPrint('📋 Existing profile: $existingProfile');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring profile exists: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
  }

  void _toggleLoginPasswordVisibility() {
    setState(() {
      _loginObscurePassword = !_loginObscurePassword;
    });
  }

  void _toggleSignupPasswordVisibility() {
    setState(() {
      _signupObscurePassword = !_signupObscurePassword;
    });
  }

  void _toggleSignupConfirmPasswordVisibility() {
    setState(() {
      _signupObscureConfirmPassword = !_signupObscureConfirmPassword;
    });
  }

  void _switchMode(bool isLoginMode) {
    setState(() {
      _isLoginMode = isLoginMode;
      _clearErrors();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _usernameController.clear();
    });
  }

  String? _validateUsername(String username) {
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > 20) return 'Username must be less than 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (password.length > 15) return 'Password must be less than 15 characters';
    if (!RegExp(r'^(?=.*[a-z])').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'^(?=.*[A-Z])').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'^(?=.*[0-9])').hasMatch(password)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'^(?=.*[!@#$%^&*(),.?":{}|<>])').hasMatch(password)) {
      return 'Password must contain at least one special character (!@#\$%^&*)';
    }
    return null;
  }

  String? _validateConfirmPassword(String confirmPassword, String password) {
    if (confirmPassword.isEmpty) return 'Please confirm your password';
    if (confirmPassword != password) return 'Passwords do not match';
    return null;
  }

  bool _validateSignUpForm() {
    _clearErrors();
    
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    bool isValid = true;
    
    final usernameValidation = _validateUsername(username);
    if (usernameValidation != null) {
      setState(() => _usernameError = usernameValidation);
      isValid = false;
    }
    
    final emailValidation = _validateEmail(email);
    if (emailValidation != null) {
      setState(() => _emailError = emailValidation);
      isValid = false;
    }
    
    final passwordValidation = _validatePassword(password);
    if (passwordValidation != null) {
      setState(() => _passwordError = passwordValidation);
      isValid = false;
    }
    
    final confirmValidation = _validateConfirmPassword(confirmPassword, password);
    if (confirmValidation != null) {
      setState(() => _confirmPasswordError = confirmValidation);
      isValid = false;
    }

    if (!_acceptTerms) {
      _showSnackBar('Please accept the conditions and safety guidelines to proceed.', Colors.orange);
      isValid = false;
    }
    
    return isValid;
  }

  bool _validateLoginForm() {
    _clearErrors();
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    bool isValid = true;
    
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      isValid = false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      isValid = false;
    }
    
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      isValid = false;
    }
    
    return isValid;
  }

  Future<bool> _isUsernameAvailable(String username) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      return existing == null;
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: color, 
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleEmailAuth() async {
    if (!mounted) return;
    
    bool isValid;
    if (_isLoginMode) {
      isValid = _validateLoginForm();
    } else {
      isValid = _validateSignUpForm();
    }
    
    if (!isValid) return;

    setState(() => _isLoading = true);
    
    try {
      if (_isLoginMode) {
        debugPrint('🔐 Attempting login with email: ${_emailController.text.trim()}');
        await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        debugPrint('🔐 User logged in successfully');
      } else {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        final username = _usernameController.text.trim();
        
        debugPrint('📝 Attempting signup with email: $email, username: $username');
        
        final isAvailable = await _isUsernameAvailable(username);
        if (!isAvailable) {
          setState(() {
            _usernameError = 'Username "$username" is already taken';
            _isLoading = false;
          });
          return;
        }

        try {
          final response = await _supabase.auth.signUp(
            email: email,
            password: password,
            data: {
              'username': username,
              'role': 'user', // 👈 CRITICAL: Set default role on signup
            },
            emailRedirectTo: 'com.example.circl://auth-callback',
          );

          if (response.user == null || (response.user?.identities?.isEmpty ?? true)) {
            setState(() {
              _emailError = 'This email is already registered. Please login instead.';
              _isLoginMode = true;
              _passwordController.clear();
              _confirmPasswordController.clear();
            });
            return;
          }

          if (response.user != null) {
            await _supabase.from('profiles').insert({
              'id': response.user!.id,
              'username': username,
              'role': 'user', // 👈 CRITICAL: Set default role for new users
              'location': 'Sri Lanka',
              'circl_points': 0,
              'aura_level': 'Bronze',
              'rating': 0.0,
              'review_count': 0,
              'verified': false,
              'is_nic_verified': false,
              'nic_skipped': false,
              'nic_hash': null,
            });
            debugPrint('✅ Profile created with username: $username and role: user');
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                email: email,
                userId: response.user!.id,
                username: username,
              ),
            ),
          );
          
          setState(() {
            _isLoginMode = true;
            _passwordController.clear();
            _confirmPasswordController.clear();
            _usernameController.clear();
            _emailController.clear();
          });
        } on AuthException catch (e) {
          debugPrint('❌ Signup error: ${e.message}');
          if (e.message.toLowerCase().contains('user already registered')) {
            setState(() {
              _emailError = 'This email is already registered. Please login.';
              _isLoginMode = true;
            });
          } else {
            _showSnackBar('Sign up failed: ${e.message}', Colors.red);
          }
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.toLowerCase().contains('invalid login credentials')) {
        errorMsg = 'Invalid email or password.';
      } else if (errorMsg.toLowerCase().contains('email not confirmed')) {
        errorMsg = 'Please confirm your email before logging in.';
      }
      _showSnackBar(errorMsg, Colors.red);
      debugPrint('❌ Email auth error: $errorMsg');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      debugPrint('🔑 Attempting Google sign in');
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.circl://auth-callback',
        queryParams: {'prompt': 'select_account'},
      );
    } catch (e) {
      _showSnackBar('Google sign in failed: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTermsSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 12, 11, 39),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(content, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I Understand', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal.shade400, const Color.fromARGB(255, 2, 0, 46)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.circle_rounded, size: 45, color: Color.fromARGB(255, 1, 142, 133)),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Circl',
                          style: TextStyle(
                            fontSize: 34, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white,
                            fontFamily: 'Ogelo-DEMO',
                            letterSpacing: 3.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  if (_isLoginMode) ...[
                    const Text(
                      'Welcome back!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect and share resources with your circle',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ] else ...[
                    const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join your local circl under a minute.',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                  
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        _buildToggleButton('Login', true),
                        _buildToggleButton('Sign Up', false),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  if (!_isLoginMode) ...[
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                        prefixIcon: const Icon(Icons.person, color: Colors.white70, size: 18),
                        errorText: _usernameError,
                        errorStyle: const TextStyle(color: Colors.orange, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      prefixIcon: const Icon(Icons.email, color: Colors.white70, size: 18),
                      errorText: _emailError,
                      errorStyle: const TextStyle(color: Colors.orange, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  
                  if (_isLoginMode) ...[
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      obscureText: _loginObscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                        prefixIcon: const Icon(Icons.lock, color: Colors.white70, size: 18),
                        suffixIcon: GestureDetector(
                          onTap: _toggleLoginPasswordVisibility,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _loginObscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                        errorText: _passwordError,
                        errorStyle: const TextStyle(color: Colors.orange, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: Colors.white,
                                checkColor: Color.fromARGB(255, 29, 147, 136),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              child: const Text(
                                'Remember me',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: Color(0xFF26A69A),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      obscureText: _signupObscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                        prefixIcon: const Icon(Icons.lock, color: Colors.white70, size: 18),
                        suffixIcon: GestureDetector(
                          onTap: _toggleSignupPasswordVisibility,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _signupObscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                        errorText: _passwordError,
                        errorStyle: const TextStyle(color: Colors.orange, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0, bottom: 12.0, left: 4.0),
                      child: Text(
                        'Password must be 8-15 characters with mixed case letters, numbers, and symbols.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ),
                    TextField(
                      controller: _confirmPasswordController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      obscureText: _signupObscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Confirm Password',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70, size: 18),
                        suffixIcon: GestureDetector(
                          onTap: _toggleSignupConfirmPasswordVisibility,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _signupObscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                        errorText: _confirmPasswordError,
                        errorStyle: const TextStyle(color: Colors.orange, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _acceptTerms,
                            activeColor: Colors.white,
                            checkColor: Colors.teal.shade900,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.3),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Conditions',
                                  style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontWeight: FontWeight.bold),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => _showTermsSheet('Terms of Conditions', 'By setting up a profile on Circl, you agree to exchange hardware resources, local setups, and compute components securely and within verified network tolerances.'),
                                ),
                                const TextSpan(text: ' and acknowledge the '),
                                TextSpan(
                                  text: 'Community Safety & Trust Guidelines',
                                  style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontWeight: FontWeight.bold),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => _showTermsSheet('Safety & Trust Guidelines', 'Circl enforces hardware integrity matching, zero-tolerance policies for network malicious actions, and local verification checks.'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text(
                        "We'll send a 4 digit code to verify your email.",
                        style: TextStyle(color: Color(0xFF26A69A), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleEmailAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color.fromARGB(255, 29, 147, 136),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color.fromARGB(255, 29, 147, 136)))
                          : Text(_isLoginMode ? 'Login' : 'Sign Up', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (!_isLoading)
                    Row(children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                    ]),
                  
                  const SizedBox(height: 16),
                  
                  if (!_isLoading)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              height: 20,
                              width: 20,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Text('G', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
                            ),
                            const SizedBox(width: 10),
                            Text('Continue with Google', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  if (!_isLoading)
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => _switchMode(!_isLoginMode),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13),
                              children: [
                                TextSpan(
                                  text: _isLoginMode ? 'New to Circl? ' : 'Already on Circl? ',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                ),
                                TextSpan(
                                  text: _isLoginMode ? 'Create account' : 'Login',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isLoginMode) {
    final isActive = (_isLoginMode == isLoginMode);
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(isLoginMode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isActive ? Color.fromARGB(255, 29, 147, 136) : Colors.white.withValues(alpha: 0.7),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  void _sendResetLink() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'com.example.circl://reset-callback',
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link dispatched to your inbox!'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Reset Password', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text('Forgot your password?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text('Don\'t worry, it happens. Enter your email below and we\'ll send you a link to reset it.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
            const SizedBox(height: 32),
            Text('Email Address', style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'name@example.com',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.mail_outline, color: Colors.grey.shade500, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Reset Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.center,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                  children: [
                    const TextSpan(text: 'Remember your password? '),
                    TextSpan(
                      text: 'Log in',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle_rounded, color: Colors.grey.shade400, size: 14),
                    const SizedBox(width: 6),
                    Text('CIRCL', style: TextStyle(color: Colors.grey.shade400, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          ],
         ),
      ),
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String userId;
  final String username;
  const EmailVerificationScreen({super.key, required this.email, required this.userId, required this.username});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _codeControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResendEnabled = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _isResendEnabled = false;
    });
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _isResendEnabled = true;
          timer.cancel();
        }
      });
    });
  }
  Future<void> _resendVerificationEmail() async {
    if (_isResendEnabled && !_isLoading) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client.auth.signInWithOtp(
          email: widget.email,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _startResendTimer();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _verifyOtpAndCreateProfile() async {
    String token = _codeControllers.map((c) => c.text).join();
    if (token.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 4-digit code'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authResponse = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email,
        token: token,
      );

      if (authResponse.session != null) {
        final existingProfile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', widget.userId)
            .maybeSingle();

        if (existingProfile == null) {
          await Supabase.instance.client.from('profiles').insert({
            'id': widget.userId,
            'username': widget.username,
            'role': 'user',
            'location': 'Sri Lanka',
            'circl_points': 0,
            'aura_level': 'Bronze',
            'rating': 0.0,
            'review_count': 0,
            'verified': true,
            'is_nic_verified': false,
            'nic_skipped': false,
            'nic_hash': null,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification successful! Profile activated.'), backgroundColor: Colors.green),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on AuthException catch (e) {
      String errorMessage = 'Verification failed. Please check your code and try again.';
      if (e.message.toLowerCase().contains('invalid')) {
        errorMessage = 'Invalid verification code. Please try again.';
      } else if (e.message.toLowerCase().contains('expired')) {
        errorMessage = 'Verification code has expired. Please request a new one.';
        _startResendTimer();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failure: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Verification', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.mail_outline, size: 40, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            const Text('Verify your email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
                children: [
                  const TextSpan(text: 'We\'ve sent a 4-digit verification code to \n'),
                  TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 55,
                  height: 55,
                  child: TextField(
                    controller: _codeControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: '',
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && index < 3) {
                        _focusNodes[index + 1].requestFocus();
                      } else if (val.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                      if (index == 3 && val.isNotEmpty) {
                        _focusNodes[index].unfocus();
                      }
                    },
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _isResendEnabled ? _resendVerificationEmail : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isResendEnabled ? Colors.black54 : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh, 
                      size: 16, 
                      color: _isResendEnabled ? Colors.black54 : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isResendEnabled 
                        ? 'Resend code' 
                        : 'Resend code in ${(_resendTimer ~/ 60).toString().padLeft(2, '0')}:${(_resendTimer % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: _isResendEnabled ? Colors.black54 : Colors.grey.shade400,
                        fontSize: 12,
                        fontWeight: _isResendEnabled ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            if (_isResendEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Didn\'t receive the email? Click "Resend code" above',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            
            const Spacer(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gpp_good_outlined, color: Colors.grey.shade400, size: 16),
                const SizedBox(width: 6),
                Text('SECURE 256-BIT ENCRYPTION', style: TextStyle(color: Colors.grey.shade400, fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtpAndCreateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                  ? const SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Verify & Continue ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Text('By continuing, you agree to our Security Terms', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}