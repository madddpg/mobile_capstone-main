import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The navy-and-cream palette used across iConstruct.
///
/// Screens historically hardcoded these hex values individually; new work
/// should reference these constants (or `Theme.of(context)`) instead.
class AppColors {
  const AppColors._();

  static const Color navy = Color(0xFF1E3042);
  static const Color navyDeep = Color(0xFF22384C);
  static const Color navySoft = Color(0xFF2C3E50);
  static const Color slate = Color(0xFF42566C);
  static const Color steel = Color(0xFF78A0CA);

  static const Color cream = Color(0xFFEDE4D4);
  static const Color creamLight = Color(0xFFF1E7D6);
  static const Color creamWarm = Color(0xFFF4E7CB);

  static const Color textDark = Color(0xFF1F2933);
  static const Color textMuted = Color(0xFF5C6F84);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB26A00);
  static const Color danger = Color(0xFFC62828);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        secondary: AppColors.steel,
        surface: AppColors.cream,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.creamLight,
        elevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFFFF4D6),
        contentTextStyle: GoogleFonts.poppins(
          color: AppColors.warning,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.up,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.creamLight,
          // Meets the 48dp minimum touch target.
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size(48, 44),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.creamLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navy,
      ),
    );
  }
}
