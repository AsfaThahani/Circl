import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/nic_verification_service.dart';

const Color kTealColor = Color(0xFF26A69A);

class FirstTimeNICVerificationScreen extends StatefulWidget {
  final VoidCallback onVerificationComplete;
 
  final void Function(bool dontShowAgain) onSkip; 
  
  final bool isFromProfile; 

  const FirstTimeNICVerificationScreen({
    super.key,
    required this.onVerificationComplete,
    required this.onSkip,
    this.isFromProfile = false, // Defaults to false for normal onboarding flow
  });

  @override
  State<FirstTimeNICVerificationScreen> createState() => _FirstTimeNICVerificationScreenState();
}

class _FirstTimeNICVerificationScreenState extends State<FirstTimeNICVerificationScreen> {
  final _service = NICVerificationService();
  
 
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  File? _nicImage;
  String? _detectedNIC;
  bool _isProcessing = false;
  
  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }
  
  Future<void> _scanNIC() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    
    if (pickedFile == null) return;
    
    setState(() {
      _nicImage = File(pickedFile.path);
      _isProcessing = true;
    });
    
    try {
      final inputImage = InputImage.fromFile(_nicImage!);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      final text = recognizedText.text;
      final nicPattern = RegExp(r'[0-9]{9}[VvXx]|[0-9]{12}');
      final match = nicPattern.firstMatch(text);
      
      if (match != null) {
        setState(() {
          _detectedNIC = match.group(0)!.toUpperCase();
        });
      } else {
        _showErrorDialog('Could not detect a valid NIC format. Please try scanning again in good lighting.');
      }
    } catch (e) {
      _showErrorDialog('OCR execution error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  Future<void> _submitVerification() async {
    if (_detectedNIC == null || _nicImage == null) {
      _showErrorDialog('Please capture your NIC via camera first.');
      return;
    }
    
    final String nicNumber = _detectedNIC!;
    
    setState(() => _isProcessing = true);
    
    try {
      await _service.submitVerification(nicNumber, nicImage: _nicImage);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Icon(Icons.check_circle_rounded, color: kTealColor, size: 52),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Awesome!', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))
                ),
                SizedBox(height: 12),
                Text(
                  'Your NIC has been securely uploaded and is pending review. Once approved, you\'ll get a verified badge to show the community you\'re a trusted member!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.4),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onVerificationComplete();
                    if (widget.isFromProfile && mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTealColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorDialog(e.toString().replaceAll('Exception:', ''));
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  void _skipForNow() async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verify to Build Trust', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'No worries! You can always verify your profile later in the Settings menu. Members are more likely to trust and interact with verified profiles. Would you like to skip this for now?',
          style: TextStyle(color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Verifying', style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), // Pill shape
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (shouldSkip == true) {
      setState(() => _isProcessing = true);
      try {
        await _service.skipVerification();

        widget.onSkip(false); 
      } catch (e) {
        _showErrorDialog(e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Oops!'),
        content: Text(message, style: const TextStyle(color: Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again', style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.isFromProfile,
        leading: widget.isFromProfile
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
            
        actions: [
          if (!widget.isFromProfile) ...[
            TextButton(
              onPressed: _isProcessing ? null : _skipForNow,
              child: const Text('Skip', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: kTealColor.withValues(alpha: 0.1), 
                  shape: BoxShape.circle
                ),
                child: const Icon(Icons.verified_user_rounded, size: 44, color: kTealColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'Become a Trusted Member', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))
              ),
              const SizedBox(height: 12),
              const Text(
                'A verified profile lets the community know you\'re a real person. Get a verified badge to stand out and help everyone feel more secure.', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4)
              ),
              const SizedBox(height: 32),
              
              if (_nicImage == null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.badge_rounded, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 16),
                      const Text(
                        'We need a clear photo of your NIC', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Place your ID on a flat surface in good lighting.', 
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _scanNIC,
                        icon: const Icon(Icons.camera_alt_rounded, size: 20),
                        label: const Text('Take a Photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTealColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  height: 220, width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    image: DecorationImage(image: FileImage(_nicImage!), fit: BoxFit.cover),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 12, right: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() {
                              _nicImage = null;
                              _detectedNIC = null;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (_detectedNIC != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: kTealColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kTealColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: kTealColor, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'ID Scanned: $_detectedNIC', 
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTealColor)
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, 
                height: 56, // Increased height prevents text cutoff
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTealColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20, 
                          width: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)
                        )
                      : const Text(
                          'Verify My Identity', 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}