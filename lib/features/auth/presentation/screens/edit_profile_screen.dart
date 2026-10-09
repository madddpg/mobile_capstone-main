import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/widgets/app_buttons.dart';
import 'package:iconstruct/core/widgets/user_avatar.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/keyboard_form.dart';
import 'package:iconstruct/features/auth/presentation/widgets/account_form_shell.dart';

class EditProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String? profileImg;

  const EditProfileScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    this.profileImg,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _fNameController;
  late final TextEditingController _lNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fNameController = TextEditingController(text: widget.firstName);
    _lNameController = TextEditingController(text: widget.lastName);
  }

  @override
  void dispose() {
    _fNameController.dispose();
    _lNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fName = _fNameController.text.trim();
    final lName = _lNameController.text.trim();

    if (fName.isEmpty || lName.isEmpty) {
      showAppMessage(
        context,
        const SnackBar(content: Text('Please fill out all fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'firstName': fName, 'lastName': lName},
      );

      if (!mounted) return;
      showAppMessage(
        context,
        const SnackBar(content: Text('Profile updated successfully.')),
        kind: AppMessageKind.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppMessage(
        context,
        SnackBar(
          content: Text(firestoreUserMessage(e, action: 'update your profile')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountFormShell(
      title: 'Edit Profile',
      hero: Column(
        children: [
          const Center(child: UserAvatar(size: 100, hasBorder: true)),
          const SizedBox(height: 12),
          Text(
            'Hardware shops see this name on your posted projects and in '
            'chat.',
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
          AccountFormShell.fieldLabel('First Name:'),
          _buildTextField(
            'e.g., Juan',
            controller: _fNameController,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          AccountFormShell.fieldLabel('Last Name:'),
          _buildTextField(
            'e.g., Dela Cruz',
            controller: _lNameController,
            action: TextInputAction.done,
            onSubmitted: (_) => _isLoading ? null : _saveProfile(),
          ),
          const SizedBox(height: 32),
          AppPrimaryButton(
            label: 'Save Changes',
            loading: _isLoading,
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hintText, {
    required TextEditingController controller,
    required TextInputAction action,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      textInputAction: action,
      onSubmitted: onSubmitted,
      scrollPadding: kFieldScrollPadding,
      style: GoogleFonts.poppins(
        color: AccountFormShell.darkBlue,
        fontSize: 15,
      ),
      decoration: AccountFormShell.fieldDecoration(hint: hintText),
    );
  }
}
