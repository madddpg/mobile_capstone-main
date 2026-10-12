import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/features/auth/data/terms_content.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEDE4D4);
    const darkBlue = Color(0xFF2C3E50);
    const midBlue = Color(0xFF648DB6);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => AppNav.back(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(128),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: darkBlue,
              size: 20,
            ),
          ),
        ),
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.poppins(
            color: darkBlue,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: iconstructTerms.length,
          itemBuilder: (context, index) {
            final term = iconstructTerms[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: midBlue.withAlpha(70), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    term['title'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    term['body'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.55,
                      color: const Color(0xFF4D5F70),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
