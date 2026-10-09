import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/core/widgets/keyboard_form.dart';

/// Frame shared by Edit Profile and Change Password.
///
/// A navy band holds the back button, the title and a [hero]. The form sits
/// in a cream panel laid out *below* that band. The panel used to be painted
/// behind the form at a fixed offset, so on some phones its top edge cut
/// through the first field's label.
class AccountFormShell extends StatelessWidget {
  final String title;
  final Widget hero;

  /// Fields followed by the screen's main button, top to bottom.
  final Widget form;

  const AccountFormShell({
    super.key,
    required this.title,
    required this.hero,
    required this.form,
  });

  static const Color cream = Color(0xFFEDE4D4);
  static const Color darkBlue = Color(0xFF2C3E50);

  /// A field name above its box, on the cream panel.
  static Widget fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: darkBlue.withAlpha(220),
        ),
      ),
    );
  }

  /// The white rounded box the account fields are typed into.
  static InputDecoration fieldDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    final rounded = BorderRadius.circular(16);
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: Colors.grey.shade500,
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: rounded,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: rounded,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: rounded,
        borderSide: const BorderSide(color: Color(0xFF648DB6), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The hero gives its room to the form while the keyboard is up, so a
    // small phone still shows the field being typed in.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: darkBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Material(
                    color: cream.withAlpha(50),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => AppNav.back(context),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: cream,
                          size: 20,
                          semanticLabel: 'Back',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: cream,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (keyboardOpen)
              const SizedBox(height: 8)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                child: hero,
              ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: cream,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(40),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: KeyboardForm(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
                    child: form,
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
