import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../app/wow_theme.dart';
import '../../firebase_options.dart';
import '../../services/wow_firebase_service.dart';
import '../../widgets/wow_brand_logo.dart';
import '../home/role_home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static const routeName = '/signup';

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _ensureFirebaseInitialized();
      final profile = await WowFirebaseService().createPassenger(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        RoleHomeScreen.routeName,
        (_) => false,
        arguments: profile,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _errorMessage = _friendlyAuthMessage(error));
    } on FirebaseException catch (error) {
      setState(
        () => _errorMessage = error.message ?? 'Firebase request failed.',
      );
    } catch (_) {
      setState(() => _errorMessage = 'Signup failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _requiredValidator(value, 'Email');
    if (required != null) {
      return required;
    }
    final email = value!.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Use at least 8 characters';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final required = _requiredValidator(value, 'Phone number');
    if (required != null) {
      return required;
    }
    final phone = value!.trim();
    if (!RegExp(r'^[0-9+\-\s()]{10,}$').hasMatch(phone)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String _friendlyAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return error.message ?? 'Signup failed. Please try again.';
    }
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
                              'Create Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: WowColors.ink,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Passenger account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: WowColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _SignupTextField(
                              controller: _nameController,
                              hintText: 'Full name',
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  _requiredValidator(value, 'Full name'),
                            ),
                            _SignupTextField(
                              controller: _emailController,
                              hintText: 'Email address',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: _emailValidator,
                            ),
                            _SignupTextField(
                              controller: _phoneController,
                              hintText: 'Phone number',
                              icon: Icons.phone_iphone_rounded,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              validator: _phoneValidator,
                            ),
                            _SignupTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
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
                              validator: _passwordValidator,
                            ),
                            _SignupTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Confirm password',
                              icon: Icons.lock_reset_rounded,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                              onFieldSubmitted: (_) =>
                                  _isSubmitting ? null : _submit(),
                              validator: _confirmPasswordValidator,
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: WowColors.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 8),
                            _GradientButton(
                              label: 'Create Account',
                              loading: _isSubmitting,
                              onPressed: _isSubmitting ? null : _submit,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Already have an account?',
                                    style: TextStyle(color: WowColors.muted),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Sign In'),
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

class _SignupTextField extends StatelessWidget {
  const _SignupTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          errorMaxLines: 2,
        ),
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
