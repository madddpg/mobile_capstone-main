import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/features/auth/data/email_service.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/features/auth/data/otp_send_policy.dart';
import 'package:iconstruct/features/auth/data/auth_login_error.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class OtpDialog extends StatefulWidget {
  final String email;
  final String? uid;
  final String? firstName;
  final String? lastName;
  final String? password;

  const OtpDialog({
    super.key,
    required this.email,
    this.uid,
    this.firstName,
    this.lastName,
    this.password,
  });

  bool get isPendingSignup =>
      password != null &&
      password!.isNotEmpty &&
      firstName != null &&
      firstName!.isNotEmpty;

  @override
  State<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<OtpDialog> {
  final EmailService _emailService = EmailService();
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  bool _checkingVerification = false;
  bool _resendingEmail = false;
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
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _otpControllers.map((c) {
        final digits = c.text.replaceAll(RegExp(r'\D'), '');
        return digits.isEmpty ? '' : digits[digits.length - 1];
      }).join();

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _resendingEmail) return;

    FocusScope.of(context).unfocus();
    setState(() => _resendingEmail = true);

    try {
      final result = await _emailService.sendOtp(email: widget.email);
      if (!mounted) return;
      showAppMessage(
        context,
        SnackBar(content: Text(result.message)),
        kind: AppMessageKind.success,
      );
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      showAppMessage(
        context,
        SnackBar(content: Text(stripAuthExceptionPrefix(e))),
      );
    } finally {
      if (mounted) setState(() => _resendingEmail = false);
    }
  }

  Future<void> _checkVerification() async {
    FocusScope.of(context).unfocus();
    if (_enteredOtp.length < 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() {
      _checkingVerification = true;
      _errorMessage = null;
    });

    try {
      final result = await _emailService.verifyOtp(
        email: widget.email,
        otp: _enteredOtp,
        uid: widget.uid,
      );

      if (!mounted) return;

      if (!result.success) return;

      if (widget.isPendingSignup) {
        final token = result.verificationToken;
        if (token == null || token.isEmpty) {
          setState(() {
            _errorMessage =
                'Could not finish registration. Request a new code.';
          });
          return;
        }
        await _emailService.completeVerifiedRegistration(
          email: widget.email,
          password: widget.password!,
          firstName: widget.firstName!,
          lastName: widget.lastName ?? '',
          verificationToken: token,
        );
        if (!mounted) return;
      }

      showAppMessage(
        context,
        const SnackBar(
          content: Text('Verification successful. Please login.'),
        ),
        kind: AppMessageKind.success,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = stripAuthExceptionPrefix(e);
      });
    } finally {
      if (mounted) setState(() => _checkingVerification = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFE9DECC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'OTP Verification',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF24384C),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 36,
                  height: 48,
                  child: TextFormField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF24384C),
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF24384C),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (value) => _onOtpChanged(index, value),
                  ),
                );
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Did not receive the OTP? ",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF24384C),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: _canResend && !_resendingEmail
                      ? _resendVerificationEmail
                      : null,
                  child: _resendingEmail
                      ? const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF24384C),
                          ),
                        )
                      : Text(
                          _canResend
                              ? 'Resend'
                              : 'Resend in ${_resendCountdown}s',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF24384C),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            decoration: _canResend
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _checkingVerification ? null : _checkVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E455E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _checkingVerification
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Submit',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
