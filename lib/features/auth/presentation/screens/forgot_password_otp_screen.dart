import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/features/auth/data/email_service.dart';
import 'package:iconstruct/features/auth/data/otp_send_policy.dart';
import 'package:iconstruct/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final String email;

  const ForgotPasswordOtpScreen({super.key, required this.email});

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final EmailService _emailService = EmailService();
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  bool _verifying = false;
  bool _resending = false;
  String? _errorMessage;
  int _resendCountdown = otpResendCooldownSeconds;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(6, (_) => TextEditingController());
    _otpFocusNodes = List.generate(6, (_) => FocusNode());
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _resendCountdown = otpResendCooldownSeconds;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        if (mounted) setState(() => _canResend = true);
        timer.cancel();
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _otpControllers.map((c) {
        final digits = c.text.replaceAll(RegExp(r'\D'), '');
        return digits.isEmpty ? '' : digits[digits.length - 1];
      }).join();

  void _onOtpChanged(int index, String value) {
    final sanitized = value.replaceAll(RegExp(r'\D'), '');
    if (sanitized != value) {
      _otpControllers[index].text = sanitized;
      _otpControllers[index].selection = TextSelection.collapsed(
        offset: sanitized.length,
      );
    }
    if (sanitized.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (sanitized.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _resend() async {
    if (!_canResend || _resending) return;
    FocusScope.of(context).unfocus();
    setState(() => _resending = true);
    try {
      final result = await _emailService.sendOtp(
        email: widget.email,
        isPasswordReset: true,
      );
      if (!mounted) return;
      _startCountdown();
      showAppMessage(
        context,
        SnackBar(content: Text(result.message)),
        kind: AppMessageKind.success,
      );
    } on EmailApiException catch (e) {
      if (!mounted) return;
      showAppMessage(context, SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      showAppMessage(context, 
        const SnackBar(content: Text('Failed to resend the code.')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!RegExp(r'^\d{6}$').hasMatch(_enteredOtp)) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });
    try {
      final result = await _emailService.verifyOtp(
        email: widget.email,
        otp: _enteredOtp,
      );
      if (!mounted) return;
      final verificationToken = result.verificationToken;
      if (verificationToken == null || verificationToken.isEmpty) {
        setState(
          () => _errorMessage = 'Verification failed. Please try again.',
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            verificationToken: verificationToken,
          ),
        ),
      );
    } on EmailApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Could not verify the code. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verify OTP',
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
                            'Receive a one-time password (OTP) via email to confirm your identity.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFFEADFD0),
                            ),
                          ),
                          const SizedBox(height: 36),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EBDC),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3F0E1B29),
                                  blurRadius: 24,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // scaleDown = no change on phones wide enough
                                // for the 6 boxes; shrinks the whole row to fit
                                // on narrow screens instead of overflowing.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      6,
                                      (i) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: _OtpBox(
                                          controller: _otpControllers[i],
                                          focusNode: _otpFocusNodes[i],
                                          onChanged: (v) => _onOtpChanged(i, v),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4D6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE0A84A),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: AppColors.warning,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            textAlign: TextAlign.left,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  children: [
                                    Text(
                                      'Did not receive the code?',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF556273),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _canResend && !_resending
                                          ? _resend
                                          : null,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: _resending
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF243749)),
                                              ),
                                            )
                                          : Text(
                                              _canResend
                                                  ? 'Resend'
                                                  : 'Resend in ${_resendCountdown}s',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF243749),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Minimum height, not fixed: the label grows
                                // with the text scale.
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: double.infinity,
                                    minHeight: 48,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF263646),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: TextButton(
                                      onPressed: _verifying ? null : _verify,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: _verifying
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      Colors.white,
                                                    ),
                                              ),
                                            )
                                          : Text(
                                              'Enter',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed width so the six boxes line up, minimum height so an enlarged
    // digit is not cropped.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 44,
        maxWidth: 44,
        minHeight: 52,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF243749),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFE9DECC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF648DB6), width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
