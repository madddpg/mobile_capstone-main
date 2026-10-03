import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/features/auth/data/email_service.dart';
import 'package:iconstruct/features/auth/data/auth_login_error.dart';
import 'package:iconstruct/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/landing_screen.dart';
import 'package:iconstruct/features/auth/presentation/widgets/otp_dialog.dart';
import 'package:iconstruct/core/widgets/app_buttons.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/keyboard_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Created on first use, so the screen can be built without Firebase.
  late final EmailService _emailService = EmailService();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    final trimmed = value.trim();
    const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    setState(() {
      if (trimmed.isEmpty) {
        _emailError = 'Email is required';
      } else if (!RegExp(emailPattern).hasMatch(trimmed)) {
        _emailError = 'Enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required';
      } else if (value.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }
    });
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    _validateEmail(email);
    _validatePassword(password);
    if (_emailError != null || _passwordError != null) return;

    setState(() => _loading = true);

    try {
      final credential = await _emailService.login(
        email: email,
        password: password,
      );
      final uid = credential.user?.uid;

      if (!mounted) return;

      if (uid == null) {
        showAppMessage(
          context,
          const SnackBar(content: Text('Failed to retrieve Firebase UID.')),
        );
        return;
      }

      debugPrint('Logged in successfully. Firebase UID: $uid');

      // Nothing from before sign-in stays under home, so back from home
      // cannot land on the landing or sign-in screen.
      Navigator.of(context)
          .pushAndRemoveUntil(AppNav.homeRoute(), (route) => false);
    } on EmailNotVerifiedException catch (e) {
      if (!mounted) return;
      // Credentials were right, so let them finish verification here instead of
      // bouncing them back with an error they cannot act on.
      showAppMessage(context, SnackBar(content: Text(e.message)));
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OtpDialog(email: e.email, uid: e.uid),
      );
    } catch (e) {
      if (!mounted) return;
      final message = stripAuthExceptionPrefix(e);
      setState(() => _passwordError = message);
      showAppMessage(context, SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RootBackFallback(
      fallback: (_) => const LandingScreen(),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF22384C), Color(0xFF334F6E), Color(0xFF78A0CA)],
            stops: [0, 0.58, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button pinned top-left
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1E7D6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                    color: const Color(0xFF32465C),
                    onPressed: () => AppNav.back(
                      context,
                      rootFallback: (_) => const LandingScreen(),
                    ),
                  ),
                ),
                Expanded(
                  child: KeyboardForm(
                    alignFieldsAboveAction: true,
                    action: AppPrimaryButton(
                      label: 'Login',
                      loading: _loading,
                      onPressed: _loading ? null : _handleLogin,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF1E7D6),
                            shadows: const [
                              Shadow(
                                color: Color(0x5C000000),
                                offset: Offset(0, 5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Welcome back—let's build smarter.",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFFEADFD0),
                          ),
                        ),
                        const SizedBox(height: 36),
                        _LoginField(
                          label: 'Email Address',
                          controller: _emailController,
                          errorText: _emailError,
                          onChanged: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _LoginField(
                          label: 'Password',
                          obscureText: _obscurePassword,
                          controller: _passwordController,
                          errorText: _passwordError,
                          onChanged: _validatePassword,
                          textInputAction: TextInputAction.done,
                          trailing: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: const Color(0xFF42566C),
                              size: 22,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFF6F0E5),
                              ),
                            ),
                          ),
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
    );
  }
}

class _LoginField extends StatelessWidget {
  final String label;
  final bool obscureText;
  final Widget? trailing;
  final TextEditingController? controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  const _LoginField({
    required this.label,
    this.obscureText = false,
    this.trailing,
    this.controller,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      scrollPadding: kFieldScrollPadding,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E242B)),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF6F665A),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        error: warningFieldError(errorText),
        filled: true,
        fillColor: const Color(0xFFE9DECC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x00FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8DB3E0), width: 1.5),
        ),
        errorBorder: warningErrorBorder(),
        focusedErrorBorder: warningErrorBorder(width: 1.5),
        suffixIcon: trailing,
      ),
    );
  }
}
