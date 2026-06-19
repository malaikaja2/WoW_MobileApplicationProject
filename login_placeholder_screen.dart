import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/wow_theme.dart';
import '../../services/wow_firebase_service.dart';
import '../../widgets/wow_brand_logo.dart';
import '../home/role_home_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginPlaceholderScreen extends StatefulWidget {
  const LoginPlaceholderScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginPlaceholderScreen> createState() => _LoginPlaceholderScreenState();
}

class _LoginPlaceholderScreenState extends State<LoginPlaceholderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _service = WowFirebaseService();

  bool _loadingEmail = false;
  bool _loadingGoogle = false;
  bool _obscurePassword = true;

  bool get _busy => _loadingEmail || _loadingGoogle;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loadingEmail = true);
    try {
      final profile = await _service.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      _goHome(profile);
    } catch (error) {
      _showError(_messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _loadingEmail = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final profile = await _service.signInWithGoogle();
      if (!mounted) {
        return;
      }
      _goHome(profile);
    } catch (error) {
      final message = _messageFor(error);
      if (message.isNotEmpty) {
        _showError(message);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGoogle = false);
      }
    }
  }

  void _goHome(WowUserProfile profile) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoleHomeScreen.routeName,
      (_) => false,
      arguments: profile,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: WowColors.danger),
    );
  }

  String _messageFor(Object error) {
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return '';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password. Try again or reset password.';
        case 'network-request-failed':
          return 'Network error. Check your internet and retry.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'missing-google-token':
          return 'Google Sign-In needs the updated Firebase Android configuration.';
        case 'operation-not-allowed':
          return 'Enable the Google provider in Firebase Authentication.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return '';
        case 'popup-blocked':
          return 'Chrome blocked the Google sign-in popup. Allow popups and try again.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }
    return 'Authentication failed. Please try again.';
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB34DE8), Color(0xFFE94DA1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    const WowBrandLogo(width: 190, height: 112),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(32)),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Welcome Back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: WowColors.ink,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const _PassengerOnlyCard(),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: _emailValidator,
                              decoration: const InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_busy,
                              obscureText: _obscurePassword,
                              validator: _passwordValidator,
                              onFieldSubmitted: (_) =>
                                  _busy ? null : _loginWithEmail(),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).pushNamed(
                                        ForgotPasswordScreen.routeName,
                                      ),
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                            _GradientButton(
                              label: 'Sign In',
                              loading: _loadingEmail,
                              onPressed: _busy ? null : _loginWithEmail,
                            ),
                            const SizedBox(height: 16),
                            _AuthDivider(),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _loginWithGoogle,
                              icon: _loadingGoogle
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : const Icon(Icons.g_mobiledata_rounded),
                              label: const Text('Sign in with Google'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: WowColors.ink,
                                minimumSize: const Size.fromHeight(54),
                                side: const BorderSide(color: WowColors.line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Flexible(
                                  child: Text(
                                    "Don't have an account?",
                                    style: TextStyle(color: WowColors.muted),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => Navigator.of(
                                          context,
                                        ).pushNamed(SignupScreen.routeName),
                                  child: const Text('Sign Up'),
                                ),
                              ],
                            ),
                          ],
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
    );
  }
}

class _PassengerOnlyCard extends StatelessWidget {
  const _PassengerOnlyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA64DE8), Color(0xFFE94DA1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: WowColors.pink.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_pin_circle_outlined, color: Colors.white, size: 30),
          SizedBox(height: 8),
          Text(
            'Passenger',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Book safe rides',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [Color(0xFFA64DE8), Color(0xFFE94DA1)],
              ),
        color: onPressed == null ? WowColors.line : null,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        height: 56,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: WowColors.line)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              color: WowColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: WowColors.line)),
      ],
    );
  }
}
