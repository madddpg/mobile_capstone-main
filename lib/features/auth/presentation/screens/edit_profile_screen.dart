import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/widgets/user_avatar.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

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
      showAppMessage(context, 
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
      showAppMessage(context, 
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
    const creamBg = Color(0xFFEDE4D4);
    const darkBlue = Color(0xFF2C3E50);

    return Scaffold(
      backgroundColor: darkBlue,
      body: Stack(
        children: [
          // Background Panel
          Positioned(
            left: 0,
            right: 0,
            top: 250,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: creamBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Area
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: creamBg.withAlpha(50),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: creamBg,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Edit Profile',
                          style: GoogleFonts.poppins(
                            color: creamBg,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Editable Fields Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar Thumbnail Preview
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                const UserAvatar(size: 100, hasBorder: true),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF648DB6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: creamBg,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 48),

                          _buildInputLabel('First Name:'),
                          _buildTextField(
                            'e.g., John',
                            controller: _fNameController,
                          ),

                          const SizedBox(height: 24),

                          _buildInputLabel('Last Name:'),
                          _buildTextField(
                            'e.g., Doe',
                            controller: _lNameController,
                          ),

                          const SizedBox(height: 50),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkBlue,
                                foregroundColor: creamBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: Colors.black.withAlpha(80),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: creamBg,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Save Changes',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF2C3E50).withAlpha(200),
        ),
      ),
    );
  }

  Widget _buildTextField(String hintText, {TextEditingController? controller}) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(
          color: const Color(0xFF2C3E50),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
