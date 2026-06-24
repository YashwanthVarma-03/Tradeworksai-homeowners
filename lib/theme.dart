import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Palette (Matching tradeworksai.com exactly)
  static const Color navy900 = Color(0xFF0F2B46); // --bg-dark
  static const Color navy700 = Color(0xFF1A1A2E); // --text-primary (Midnight Blue/Navy)
  static const Color navy500 = Color(0xFF132F4C); // --bg-dark-lighter
  static const Color navyTint = Color(0xFFF5F7FA); // --bg-light

  static const Color teal700 = Color(0xFF0077B6); // Darker teal
  static const Color teal500 = Color(0xFF00B4D8); // --color-teal - Secondary
  static const Color tealTint = Color(0xFFE6F8FC); // Light teal tint

  static const Color orange700 = Color(0xFFEA580C); // Darker orange
  static const Color orange500 = Color(0xFFF97316); // --color-orange - Accent / CTA
  static const Color orangeTint = Color(0xFFFFF7ED); // Light orange tint

  // Neutral Colors
  static const Color ink = Color(0xFF1A1A2E); // Midnight Blue for body text to match brand
  static const Color gray = Color(0xFF6B7280); // Slate gray
  static const Color line = Color(0xFFE2E8F0); // Border line color (Slate 200)
  static const Color pageAlt = Color(0xFFF8FAFC); // Alternate background (Slate 50)
  static const Color white = Color(0xFFFFFFFF);

  // Status/Feedback
  static const Color success = Color(0xFF10B981); // Emerald green
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color info = Color(0xFF00B4D8); // Teal

  // Google Fonts
  static TextStyle get headingStyle => GoogleFonts.poppins(
        color: navy700,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get bodyStyle => GoogleFonts.inter(
        color: ink,
      );

  // Custom Text Themes
  static TextTheme get textTheme => TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: navy700,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: navy700,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: navy700,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: navy700,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: navy700,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          height: 1.5,
          color: ink,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: ink,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: navy700,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: gray,
        ),
      );

  // Theme Data Setup
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy700,
        primary: navy700,
        secondary: teal500,
        tertiary: orange500,
        surface: white,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      scaffoldBackgroundColor: white,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        elevation: 0,
        iconTheme: IconThemeData(color: navy700),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy700,
        primary: const Color(0xFF4D7FBE),
        secondary: const Color(0xFF4FA8CC),
        tertiary: const Color(0xFFF2902F),
        surface: const Color(0xFF16263D),
        brightness: Brightness.dark,
      ),
      textTheme: textTheme.apply(
        bodyColor: const Color(0xFFF2F5F9),
        displayColor: const Color(0xFFF2F5F9),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF26384F), thickness: 1),
      scaffoldBackgroundColor: const Color(0xFF0F1A2B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F1A2B),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }
}
