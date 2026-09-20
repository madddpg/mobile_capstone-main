import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/state/onboarding_preferences.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/core/widgets/user_avatar.dart';
import 'package:iconstruct/features/auth/presentation/screens/change_password_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/edit_profile_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/main_home_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/terms_conditions_screen.dart';
import 'package:iconstruct/features/chat/screens/chat_inbox_screen.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _cream = Color(0xFFEBE0CC);
  static const Color _darkBlue = Color(0xFF2C3E50);
  static const Color _midBlue = Color(0xFF648DB6);

  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 72,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      // Bytes, not a path: a picked file has no path in a browser.
      final bytes = await pickedFile.readAsBytes();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final Reference storageRef = FirebaseStorage.instance.ref().child(
        'user_profile_images/${user.uid}/$timestamp.jpg',
      );

      final UploadTask uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'profileImage': downloadUrl,
          'profileImageUpdatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (mounted) {
        showAppMessage(
          context,
          const SnackBar(content: Text('Profile image updated successfully.')),
          kind: AppMessageKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, 
          SnackBar(
            content: Text(
              firestoreUserMessage(e, action: 'update your profile photo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _cream.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: _cream),
                title: Text(
                  'Take a photo',
                  style: GoogleFonts.poppins(color: _cream),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: _cream),
                title: Text(
                  'Choose from gallery',
                  style: GoogleFonts.poppins(color: _cream),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_darkBlue, _midBlue],
                  stops: [0.3, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 320,
              decoration: const BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                final currentUserModel = userProvider.currentUser;

                if (user == null) {
                  return const Center(child: Text('User not logged in.'));
                }

                if (currentUserModel == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: _darkBlue),
                  );
                }

                final firstName = currentUserModel.firstName;
                final lastName = currentUserModel.lastName;
                final fullName = currentUserModel.fullName;
                final email = currentUserModel.email;
                final profileImg = currentUserModel.profileImageUrl;

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                              child: Row(
                                children: [
                                  Material(
                                    color: _darkBlue,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => Navigator.pop(context),
                                      child: const SizedBox(
                                        width: 38,
                                        height: 38,
                                        child: Icon(
                                          Icons.arrow_back_ios_new,
                                          color: _cream,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2C3E50),
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    UserAvatar(
                                      size: 96,
                                      hasBorder: true,
                                      onTap: _isUploading
                                          ? null
                                          : _showImagePickerOptions,
                                    ),
                                    if (_isUploading)
                                      const CircularProgressIndicator(
                                        color: _darkBlue,
                                      ),
                                  ],
                                ),
                                if (!_isUploading)
                                  GestureDetector(
                                    onTap: _showImagePickerOptions,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _darkBlue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _cream,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: _cream,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              fullName.isEmpty
                                  ? 'iConstruct Builder'
                                  : fullName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2C3E50),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: _darkBlue.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      _ProfileCard(
                        children: [
                          _ProfileAction(
                            icon: Icons.edit_outlined,
                            title: 'Edit Profile',
                            subtitle: 'Update your first and last name.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(
                                    firstName: firstName,
                                    lastName: lastName,
                                    profileImg: profileImg,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'First Name',
                            value: firstName,
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Last Name',
                            value: lastName,
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: email,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ProfileCard(
                        children: [
                          _ProfileAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Shop messages',
                            subtitle:
                                'Chat with a hardware shop after you select their quotation.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChatInboxScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileAction(
                            icon: Icons.lock_outline_rounded,
                            title: 'Change Password',
                            subtitle: 'Set a new password for this account.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChangePasswordScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileAction(
                            icon: Icons.description_outlined,
                            title: 'Terms & Conditions',
                            subtitle: 'Read how iConstruct handles your data.',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TermsConditionsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileAction(
                            icon: Icons.explore_outlined,
                            title: 'Home guide',
                            subtitle:
                                'Replay the short tour of estimates, quotations, and tracking.',
                            onTap: () async {
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid ?? '';
                              await OnboardingPreferences.clearHomeGuide(uid);
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const MainHomeScreen(
                                    forceHomeGuide: true,
                                  ),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileAction(
                            icon: Icons.menu_book_outlined,
                            title: 'Shop chat guide',
                            subtitle:
                                'Replay how live chat works after you select a supplier.',
                            onTap: () async {
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid ?? '';
                              await OnboardingPreferences.clearChatGuide(uid);
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChatInboxScreen(
                                    forceChatGuide: true,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileAction(
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            subtitle: 'Sign out of this builder account.',
                            isDestructive: true,
                            onTap: () => _logout(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final List<Widget> children;

  const _ProfileCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Fill the width like the rest of the app, leaving an even ~20 dp gutter;
      // capped so it never gets unwieldy on a very wide phone.
      width: (MediaQuery.sizeOf(context).width - 40).clamp(0.0, 380.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEBE0CC);
    final accent = isDestructive ? const Color(0xFFFF8A80) : cream;

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: cream.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: cream.withValues(alpha: 0.22),
          highlightColor: cream.withValues(alpha: 0.12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cream.withValues(alpha: 0.32)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cream.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                            color: cream.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cream.withValues(alpha: 0.9),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEBE0CC);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: cream.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cream.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cream.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cream, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cream.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cream,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
