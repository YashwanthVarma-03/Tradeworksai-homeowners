import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TradeWorks colour and type tokens — design standard v3.3.
class AppTheme {
  static const categoryRoofing = Color(0xFFFFEBEE);
  static const categoryHandyman = Color(0xFFF3E5F5);
  static const Color pageBackground = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE6E8EC);
  static const Color border = Color(0xFFD0D5DD);
  static const Color subtle = Color(0xFFF6F7F9);
  static const Color white = Color(0xFFFFFFFF);
  static const Color navy = Color(0xFF16233F);
  static const Color body = Color(0xFF3B4456);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textTertiary = Color(0xFF98A2B3);
  static const Color orange = Color(0xFFE8761E);
  static const Color onOrange = navy;
  static const Color blue = Color(0xFF1F5BD6);
  static const Color blueTint = Color(0xFFEBF1FD);
  static const Color green = Color(0xFF067647);
  static const Color greenMark = Color(0xFF17B26A);
  static const Color greenTint = Color(0xFFECFDF3);
  static const Color amber = Color(0xFFB45309);
  static const Color amberTint = Color(0xFFFEF3E2);
  static const Color red = Color(0xFFB42318);
  static const Color purple = Color(0xFF6D28D9);
  static const Color purpleTint = Color(0xFFF4EFFE);
  static const Color gold = Color(0xFFE9A23B);
  static const Color ratingTint = Color(0xFFFEF6E7);
  static const Color ratingText = Color(0xFF7A4A06);
  static const Color chipBooked = textSecondary;
  static const Color chipBookedTint = pageBackground;
  static const Color chipNeutral = textSecondary;
  static const Color chipNeutralTint = pageBackground;

  // Compatibility aliases retained while authenticated screens move to v3.3.
  static const Color navy900 = navy;
  static const Color navy700 = navy;
  static const Color navy500 = navy;
  static const Color navyTint = pageBackground;
  static const Color teal700 = blue;
  static const Color teal500 = blue;
  static const Color tealTint = blueTint;
  static const Color orange700 = orange;
  static const Color orange500 = orange;
  static const Color orangeTint = amberTint;
  static const Color ink = navy;
  static const Color gray = textSecondary;
  static const Color line = cardBorder;
  static const Color pageAlt = pageBackground;
  static const Color success = green;
  static const Color error = red;
  static const Color warning = amber;
  static const Color info = blue;

  static const double radius = 12;
  static const List<BoxShadow> floatShadow = [
    BoxShadow(color: Color(0x14101828), blurRadius: 20, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0F101828), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static TextStyle get headingStyle => GoogleFonts.outfit(
        color: navy,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get bodyStyle => GoogleFonts.inter(
        color: body,
        fontSize: 16,
        height: 1.5,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: GoogleFonts.outfit(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.17,
            color: navy),
        displayMedium: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.19,
            color: navy),
        headlineLarge: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.23,
            color: navy),
        headlineMedium: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: navy),
        titleLarge: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: navy),
        titleMedium: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.41,
            color: navy),
        bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: body),
        bodyMedium: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.47,
            color: body),
        bodySmall:
            GoogleFonts.inter(fontSize: 14, height: 1.43, color: textSecondary),
        labelLarge: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: navy),
        labelMedium: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
      );

  static ThemeData get lightTheme {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      fontFamily: GoogleFonts.inter().fontFamily,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: blue,
        onPrimary: white,
        secondary: blue,
        tertiary: orange,
        onTertiary: onOrange,
        surface: pageBackground,
        error: red,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: pageBackground,
      iconTheme: const IconThemeData(color: navy, weight: 500, opticalSize: 24),
      dividerTheme: const DividerThemeData(color: cardBorder, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: pageBackground,
        surfaceTintColor: pageBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: navy, weight: 500, opticalSize: 24),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: onOrange,
          disabledBackgroundColor: subtle,
          disabledForegroundColor: textTertiary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: shape,
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: onOrange,
          minimumSize: const Size(64, 52),
          shape: shape,
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          backgroundColor: white,
          side: const BorderSide(color: border),
          minimumSize: const Size(64, 50),
          shape: shape,
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          minimumSize: const Size(44, 44),
          textStyle:
              GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? blue : null,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: navy),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: subtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: textTertiary, fontSize: 15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        indicatorColor: blueTint,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? blue : body,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? blue : body,
          ),
        ),
      ),
    );
  }
}
