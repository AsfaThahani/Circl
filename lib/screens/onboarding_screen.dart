import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinishedCallback;
  
  const OnboardingScreen({super.key, required this.onFinishedCallback});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.handshake_rounded,
      title: 'Share Things.\nTrade Tasks.',
      description: 'From free borrowing and friendly favours to paid rentals and micro-tasks, Circl brings your community\'s resources straight to your fingertips.',
      gradientColors: [const Color(0xFFB4D3D9), const Color(0xFFB4D3D9)], // Muted Teal
      iconBgColor: Colors.white,
      iconColor: const Color(0xFF1F2937), 
      textColor: const Color(0xFF1F2937), 
      buttonColor: const Color(0xFF1F2937), 
      buttonTextColor: Colors.white,
      textAlign: TextAlign.left, 
      crossAxisAlignment: CrossAxisAlignment.start, 
    ),
    OnboardingPageData(
      icon: Icons.map_rounded,
      title: 'Search Nearby.\nDiscover Community.',
      description: 'Discover helpers, gear, and services just around the corner. Our smart map and matching algorithm connect you instantly with what you need.',
      gradientColors: [const Color(0xFFD2DCB6), const Color(0xFFD2DCB6)], // Soft Olive
      iconBgColor: Colors.white,
      iconColor: const Color(0xFF1F2937), 
      textColor: const Color(0xFF1F2937), 
      buttonColor: const Color(0xFF1F2937), 
      buttonTextColor: Colors.white,
      textAlign: TextAlign.left, 
      crossAxisAlignment: CrossAxisAlignment.start,
    ),
    OnboardingPageData(
      icon: Icons.message_rounded,
      title: 'Start a Chat.\nGrow Your Circle.',
      description: 'Reach out to neighbours instantly with our secure chat. Ask questions, set pickup times, and arrange services to make community coordination simpler than ever.',
      gradientColors: [const Color(0xFFFFF8DE), const Color(0xFFFFF8DE)], // Warm Cream
      iconBgColor: Colors.white,
      iconColor: const Color(0xFF1F2937), 
      textColor: const Color(0xFF1F2937), 
      buttonColor: const Color(0xFF1F2937), 
      buttonTextColor: Colors.white,
      textAlign: TextAlign.left, 
      crossAxisAlignment: CrossAxisAlignment.start,
    ),
    OnboardingPageData(
      icon: Icons.verified_user_rounded, 
      title: 'Build Trust.\nEarn Aura.',
      description: 'Enjoy peace of mind with verified profiles and secure deposits. Collect great reviews to level up your Aura, earn points, and unlock perks.',
      gradientColors: [const Color(0xFFFFCDC9), const Color(0xFFFFCDC9)], // Soft Peach
      iconBgColor: Colors.white,
      iconColor: const Color(0xFF1F2937), 
      textColor: const Color(0xFF1F2937), 
      buttonColor: const Color(0xFF1F2937), 
      buttonTextColor: Colors.white,
      textAlign: TextAlign.left, 
      crossAxisAlignment: CrossAxisAlignment.start,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600), // Smooth 600ms duration
        curve: Curves.easeInOutCubic, // Premium easing curve
      );
    } else {
      widget.onFinishedCallback(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPageData = _pages[_currentPage];

    return Scaffold(
      backgroundColor: currentPageData.gradientColors.last,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _pages.asMap().entries.map((entry) => _buildPage(entry.value, entry.key)).toList(),
          ),
          Positioned(
            top: 50, right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _currentPage < _pages.length - 1 ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: _currentPage == _pages.length - 1,
                child: TextButton(
                  onPressed: widget.onFinishedCallback,
                  child: Text(
                    'Skip', 
                    style: TextStyle(
                      color: currentPageData.textColor.withValues(alpha: 0.8), 
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: 0, right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _pages.length,
                effect: WormEffect(
                  activeDotColor: currentPageData.textColor, 
                  dotColor: currentPageData.textColor.withValues(alpha: 0.3),
                  dotHeight: 10, dotWidth: 10,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: ElevatedButton(
              onPressed: _goToNextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: currentPageData.buttonColor,
                foregroundColor: currentPageData.buttonTextColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
                splashFactory: NoSplash.splashFactory, // Removes cheap grey tap flash
                shadowColor: Colors.transparent,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  key: ValueKey<bool>(_currentPage == _pages.length - 1), 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPageData page, int index) {
    bool isActive = _currentPage == index; 

    return Container(
      width: double.infinity, 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: page.gradientColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: page.crossAxisAlignment, 
            children: [
              Center(
                child: FloatingWidget(
                  child: Container(
                    width: 128, height: 128,
                    decoration: BoxDecoration(
                      color: page.iconBgColor, 
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ]
                    ),
                    child: Icon(page.icon, size: 64, color: page.iconColor),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              EntranceAnimator(
                isActive: isActive,
                delay: const Duration(milliseconds: 100), 
                child: Text(
                  page.title, 
                  textAlign: page.textAlign, 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: page.textColor, 
                  ),
                ),
              ),
              const SizedBox(height: 16),
              EntranceAnimator(
                isActive: isActive,
                delay: const Duration(milliseconds: 250), 
                child: Text(
                  page.description,
                  textAlign: page.textAlign, 
                  style: TextStyle(
                    fontSize: 16, 
                    color: page.textColor.withValues(alpha: 0.85), 
                    height: 1.5,
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
class EntranceAnimator extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Duration delay;
  final Offset startOffset;

  const EntranceAnimator({
    super.key,
    required this.child,
    required this.isActive,
    this.delay = Duration.zero,
    this.startOffset = const Offset(0, 0.2), 
  });

  @override
  State<EntranceAnimator> createState() => _EntranceAnimatorState();
}

class _EntranceAnimatorState extends State<EntranceAnimator> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  @override
  void didUpdateWidget(EntranceAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _checkState();
    }
  }

  void _checkState() {
    if (widget.isActive) {
      Future.delayed(widget.delay, () {
        if (mounted && widget.isActive) { 
          setState(() => _show = true);
        }
      });
    } else {
      setState(() => _show = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      opacity: _show ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        offset: _show ? Offset.zero : widget.startOffset,
        child: widget.child,
      ),
    );
  }
}
class FloatingWidget extends StatefulWidget {
  final Widget child;
  const FloatingWidget({super.key, required this.child});

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true); 

  late final Animation<Offset> _animation = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0, 0.08), 
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }
}
class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final Color iconBgColor;
  final Color iconColor;
  final Color textColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;

  OnboardingPageData({
    required this.icon, 
    required this.title, 
    required this.description,
    required this.gradientColors, 
    required this.iconBgColor, 
    required this.iconColor,
    required this.textColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.textAlign,
    required this.crossAxisAlignment,
  });
}