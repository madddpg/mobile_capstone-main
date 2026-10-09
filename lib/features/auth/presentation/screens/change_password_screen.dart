import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/validation/password_policy.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/core/widgets/app_buttons.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/keyboard_form.dart';
import 'package:iconstruct/features/auth/presentation/widgets/account_form_shell.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();
    // Not trimmed: sign-in and registration take the password exactly as
    // typed, so trimming here rejected a correct current password that
    // starts or ends with a space, and quietly changed the new one.
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      showAppMessage(
        context,
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    final policyError = PasswordPolicy.validate(newPassword);
    if (policyError != null) {
      showAppMessage(context, SnackBar(content: Text('$policyError.')));
      return;
    }

    if (newPassword != confirmPassword) {
      showAppMessage(
        context,
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return;
    }

    if (newPassword == currentPassword) {
      showAppMessage(
        context,
        const SnackBar(
          content: Text(
            'Your new password must be different from your current one.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) {
        if (!mounted) return;
        showAppMessage(
          context,
          const SnackBar(content: Text('No logged-in user found.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      // Best effort. The password has already changed by this point, so a
      // failed timestamp must not be reported as a failed change.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'passwordUpdatedAt': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('passwordUpdatedAt not saved: $e');
      }

      if (!mounted) return;

      showAppMessage(
        context,
        const SnackBar(
          content: Text('Password changed. Please sign in again.'),
          backgroundColor: Colors.green,
        ),
        kind: AppMessageKind.success,
      );

      // Force a fresh session after a credential change.
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to change password.';

      if (e.code == 'wrong-password') {
        message = 'Your current password is incorrect.';
      } else if (e.code == 'weak-password') {
        message = 'Your new password is too weak.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please log in again before changing your password.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid current password. Please try again.';
      } else if (e.code == 'user-mismatch') {
        message = 'The current password does not match this account.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Wait a few minutes, then try again.';
      } else if (e.code == 'network-request-failed') {
        message = 'No connection. Check your internet and try again.';
      }

      if (mounted) {
        showAppMessage(
          context,
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          SnackBar(
            content: Text(
              firestoreUserMessage(e, action: 'change your password'),
            ),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required TextInputAction action,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountFormShell.fieldLabel(label),
        TextField(
          controller: controller,
          obscureText: obscureText,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: action,
          onSubmitted: onSubmitted,
          scrollPadding: kFieldScrollPadding,
          style: GoogleFonts.poppins(
            color: AccountFormShell.darkBlue,
            fontSize: 14,
          ),
          decoration: AccountFormShell.fieldDecoration(
            hint: hint,
            suffixIcon: IconButton(
              tooltip: obscureText ? 'Show password' : 'Hide password',
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF648DB6),
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccountFormShell(
      title: 'Change Password',
      hero: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AccountFormShell.cream.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: AccountFormShell.cream, width: 1.5),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: AccountFormShell.cream,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create a new strong password to secure your account. You will '
            'sign in again with it afterwards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.4,
              color: AccountFormShell.cream.withAlpha(200),
            ),
          ),
        ],
      ),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPasswordField(
            controller: _currentPasswordController,
            label: 'Current Password:',
            hint: 'Your current password',
            obscureText: _obscureCurrent,
            action: TextInputAction.next,
            onToggleVisibility: () {
              setState(() {
                _obscureCurrent = !_obscureCurrent;
              });
            },
          ),
          const SizedBox(height: 18),
          _buildPasswordField(
            controller: _newPasswordController,
            label: 'New Password:',
            hint: 'Your new password',
            obscureText: _obscureNew,
            action: TextInputAction.next,
            onToggleVisibility: () {
              setState(() {
                _obscureNew = !_obscureNew;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            PasswordPolicy.hint,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: const Color(0xFF5C6F84),
            ),
          ),
          const SizedBox(height: 18),
          _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password:',
            hint: 'Type the new password again',
            obscureText: _obscureConfirm,
            action: TextInputAction.done,
            onSubmitted: (_) => _isLoading ? null : _updatePassword(),
            onToggleVisibility: () {
              setState(() {
                _obscureConfirm = !_obscureConfirm;
              });
            },
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            label: 'Update Password',
            loading: _isLoading,
            onPressed: _isLoading ? null : _updatePassword,
          ),
        ],
      ),
    );
  }
}
