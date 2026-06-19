import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/wow_theme.dart';
import '../../services/wow_firebase_service.dart';
import '../../widgets/wow_brand_logo.dart';
import '../home/role_home_screen.dart';
import 'splash_screen.dart';

class BrandSplashScreen extends StatefulWidget {
  const BrandSplashScreen({super.key});

  static const routeName = '/';

  @override
  State<BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends State<BrandSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _timer = Timer(
      const Duration(milliseconds: 2600),
      () => unawaited(_continue()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
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
    Navigator.of(context).pushReplacementNamed(SplashScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9A48FF), Color(0xFFE94DA1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const WowBrandLogo(width: 286, height: 172),
                    const SizedBox(height: 26),
                    const Text(
                      'WoW',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'By Women For Women',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: WowColors.purple,
    );
  }
}
