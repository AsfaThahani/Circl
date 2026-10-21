import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:circl/providers/app_lock_provider.dart';
import 'package:flutter/services.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _hasTriggeredAuth = false;

  @override
  void initState() {
    super.initState();
    _triggerAuthentication();
  }

  Future<void> _triggerAuthentication() async {
    if (_hasTriggeredAuth) return;
    _hasTriggeredAuth = true;
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final appLock = context.read<AppLockProvider>();
    final success = await appLock.authenticateAndUnlock();
    
    if (!success && mounted) {
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: const Text('Please authenticate to access the app.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _hasTriggeredAuth = false;
              _triggerAuthentication();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLock = context.watch<AppLockProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9E75).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.circle_rounded,
                  size: 64,
                  color: Color(0xFF1D9E75),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Circl',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                appLock.isAuthenticating 
                    ? 'Authenticating...' 
                    : 'Touch to unlock',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: appLock.isAuthenticating 
                    ? null 
                    : () {
                        _hasTriggeredAuth = false;
                        _triggerAuthentication();
                      },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: appLock.isAuthenticating
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: Color(0xFF1D9E75),
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(
                          Icons.fingerprint,
                          size: 48,
                          color: Color(0xFF1D9E75),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              TextButton(
                onPressed: () {
                  if (Theme.of(context).platform == TargetPlatform.android) {
                    SystemNavigator.pop();
                  }
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}