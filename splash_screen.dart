import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/login_placeholder_screen.dart';
import '../home/role_home_screen.dart';
import '../../services/wow_firebase_service.dart';
import '../../widgets/wow_brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/onboarding';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _slides = [
    _SplashSlide(
      icon: Icons.shield_outlined,
      title: '100% Women Safety',
      body:
          'All our drivers are verified women. Your safety is our top priority with real-time tracking and emergency support.',
      colors: [Color(0xFF9C4EEA), Color(0xFFE94DA1)],
    ),
    _SplashSlide(
      icon: Icons.phone_in_talk_outlined,
      title: 'Instant SOS Alert',
      body:
          'One-tap emergency button connects you to authorities and shares your live location with family instantly.',
      colors: [Color(0xFFE94DA1), Color(0xFFE93678)],
    ),
    _SplashSlide(
      icon: Icons.location_on_outlined,
      title: 'Easy Ride Booking',
      body:
          'Book your ride in seconds with AI-powered matching for the nearest driver and safest routes in Karachi.',
      colors: [Color(0xFFE93678), Color(0xFFFF6845)],
    ),
  ];

  late final PageController _pageController;
  late final AnimationController _logoController;
  Timer? _routeTimer;
  Timer? _autoTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _routeTimer = Timer(
      const Duration(milliseconds: 1100),
      () => unawaited(_routeAfterSplash()),
    );
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _autoTimer?.cancel();
    _pageController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _routeAfterSplash() async {
    _autoTimer?.cancel();
    WowUserProfile? profile;
    try {
      profile = await WowFirebaseService().currentProfile();
    } catch (_) {
      profile = null;
    }
    if (!mounted) {
      return;
    }
    if (profile != null) {
      Navigator.of(
        context,
      ).pushReplacementNamed(RoleHomeScreen.routeName, arguments: profile);
      return;
    }
    _startAutoNavigation();
  }

  void _startAutoNavigation() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) => _goNext());
  }

  void _goNext() {
    if (!mounted) {
      return;
    }

    if (_currentPage == _slides.length - 1) {
      Navigator.of(
        context,
      ).pushReplacementNamed(LoginPlaceholderScreen.routeName);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _logoController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAFD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 34),
          child: Column(
            children: [
              Align(
                alignment: Alignment.center,
                child: Row(
                  children: [
                    const WowBrandLogo(width: 156, height: 66, compact: true),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushReplacementNamed(LoginPlaceholderScreen.routeName),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF766783),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return _SplashSlideView(
                      slide: _slides[index],
                      logoAnimation: _logoController,
                    );
                  },
                ),
              ),
              _PageDots(
                currentPage: _currentPage,
                pageCount: _slides.length,
                activeColor: slide.colors.last,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: AnimatedOpacity(
                      opacity: isFirstPage ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: _BackButton(
                        onPressed: isFirstPage ? null : _goBack,
                      ),
                    ),
                  ),
                  SizedBox(width: isFirstPage ? 6 : 7),
                  Expanded(
                    child: _NextButton(
                      label: isLastPage ? 'Get Started' : 'Next',
                      colors: const [Color(0xFFA64DE8), Color(0xFFE94DA1)],
                      onPressed: _goNext,
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
}

class _SplashSlide {
  const _SplashSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Color> colors;
}

class _SplashSlideView extends StatelessWidget {
  const _SplashSlideView({required this.slide, required this.logoAnimation});

  final _SplashSlide slide;
  final Animation<double> logoAnimation;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: logoAnimation, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: logoAnimation, curve: Curves.easeOutBack),
    );

    return Column(
      children: [
        const Spacer(flex: 24),
        FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: slide.colors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: slide.colors.last.withValues(alpha: 0.22),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Icon(slide.icon, color: Colors.white, size: 52),
            ),
          ),
        ),
        const SizedBox(height: 27),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF2B1C3C),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF74677F),
              fontSize: 13.6,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
        ),
        const Spacer(flex: 31),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.currentPage,
    required this.pageCount,
    required this.activeColor,
  });

  final int currentPage;
  final int pageCount;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: isActive ? 27 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? activeColor : const Color(0xFFEFEAF2),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF9F4DFF),
          side: const BorderSide(color: Color(0xFF9F4DFF), width: 1.6),
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: const Icon(Icons.chevron_left_rounded, size: 20),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final List<Color> colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 48,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
