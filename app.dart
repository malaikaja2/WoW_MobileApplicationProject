import 'package:flutter/material.dart';

import 'wow_theme.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_placeholder_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/role_home_screen.dart';
import '../features/passenger/assignment_records.dart';
import '../features/passenger/passenger_flow.dart';
import '../features/splash/brand_splash_screen.dart';
import '../features/splash/splash_screen.dart';
import '../services/wow_firebase_service.dart';

class WomenOnWheelsApp extends StatelessWidget {
  const WomenOnWheelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women On Wheels',
      debugShowCheckedModeBanner: false,
      theme: WowTheme.light(),
      initialRoute: BrandSplashScreen.routeName,
      routes: {
        AdminDirectScreen.routeName: (_) => const AdminDirectScreen(),
        BrandSplashScreen.routeName: (_) => const BrandSplashScreen(),
        SplashScreen.routeName: (_) => const SplashScreen(),
        LoginPlaceholderScreen.routeName: (_) => const LoginPlaceholderScreen(),
        SignupScreen.routeName: (_) => const SignupScreen(),
        ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == RoleHomeScreen.routeName &&
            settings.arguments is WowUserProfile) {
          final profile = settings.arguments! as WowUserProfile;
          if (profile.role == WowRole.passenger) {
            return MaterialPageRoute(
              builder: (_) => PassengerShell(profile: profile),
            );
          }
          if (profile.role == WowRole.admin) {
            return MaterialPageRoute(
              builder: (_) => AdminAssignmentShell(profile: profile),
            );
          }
          return MaterialPageRoute(
            builder: (_) => RoleHomeScreen(profile: profile),
          );
        }
        if (settings.name == PassengerShell.routeName &&
            settings.arguments is WowUserProfile) {
          return MaterialPageRoute(
            builder: (_) =>
                PassengerShell(profile: settings.arguments! as WowUserProfile),
          );
        }
        return null;
      },
    );
  }
}
