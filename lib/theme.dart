import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TradeWorks colour tokens.
///
/// This is the single source of truth. No screen may declare its own
/// `Color(0xFF……)` literal — every colour in the app comes from here.
///
/// The palette is shared with the homeowner web portal. Do not add a colour
/// to this file without adding it to the portal too.
class AppTheme {
  // ---------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------

  /// Every page background. There is no tinted page.
  static const Color pageBackground = Color(0xFFFFFFFF);

  /// The only thing that separates a card from the page.
  static const Color cardBorder = Color(0xFFDDE3EA);

  static const Color white = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------

  /// Headings and primary body text.
  static const Color navy = Color(0xFF12325C);

  /// Supporting text, labels, captions.
  static const Color textSecondary = Color(0xFF5A6B7B);

  /// Metadata, timestamps, placeholder text.
  static const Color textTertiary = Color(0xFF9AA6B2);

  // ---------------------------------------------------------------------
  // Action
  // ---------------------------------------------------------------------

  /// Page-level primary action ONLY — one per screen.
  ///
  /// Not for links, badges, chips, values, icons, spinners, progress bars,
  /// selected states or secondary buttons. If a screen needs a second
  /// emphasised control, it is navy, not orange.
  static const Color orange = Color(0xFFE8792B);

  // ---------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------

  /// Verified, completed, credits applied.
  static const Color green = Color(0xFF17784F);
  static const Color greenTint = Color(0xFFE3F2EA);

  /// Current state, in progress, informational.
  static const Color blue = Color(0xFF1F7A9E);
  static const Color blueTint = Color(0xFFE3F0F5);

  /// Attention and consequence.
  static const Color amber = Color(0xFFC4611A);
  static const Color amberTint = Color(0xFFFDF1E4);

  /// Destructive text links and blocking validation. Text only — no fills.
  static const Color red = Color(0xFFB0233C);

  /// Star glyph only. Never text, never a surface.
  static const Color gold = Color(0xFFC98A1E);

  // ---------------------------------------------------------------------
  // Work-order status chips
  // ---------------------------------------------------------------------
  // Booked, En route and Completed are outlined. In progress is the only
  // filled chip: white text on solid `blue`.

  static const Color chipBooked = Color(0xFF47607A);
  static const Color chipBookedTint = Color(0xFFEDF2F7);

  /// Cancelled and no-show. Always labelled with whose.
  static const Color chipNeutral = Color(0xFF6B7885);
  static const Color chipNeutralTint = Color(0xFFF0F2F5);

  // ---------------------------------------------------------------------
  // Legacy names
  // ---------------------------------------------------------------------
  // Kept so existing call sites compile. They now point at the tokens above.
  // New code uses the token names. These are removed once the per-screen
  // pass has replaced every reference.

  static const Color navy900 = navy;
  static const Color navy700 = navy;
  static const Color navy500 = navy;
  static const Color navyTint = pageBackground;

  static const Color teal700 = blue;
  static const Color teal500 = blue;
  static const Color tealTint = blueTint;

  static const Color orange700 = orange;
  static const Color orange500 = orange;

  /// Was an orange tint. The palette has no orange surface — an orange-tinted
  /// panel is an amber panel, so its foreground should be `amber`, not
  /// `orange`. Those sites are corrected in the per-screen pass.
  static const Color orangeTint = amberTint;

  static const Color ink = navy;
  static const Color gray = textSecondary;
  static const Color line = cardBorder;
  static const Color pageAlt = pageBackground;

  static const Color success = green;
  static const Color error = red;
  static const Color warning = amber;
  static const Color info = blue;

  // ---------------------------------------------------------------------
  // Type
  // ---------------------------------------------------------------------

  static TextStyle get headingStyle => GoogleFonts.poppins(
        color: navy,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get bodyStyle => GoogleFonts.inter(
        color: navy,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: navy,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: navy,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: navy,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          height: 1.5,
          color: navy,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: navy,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: textSecondary,
        ),
      );

  // ---------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: blue,
        tertiary: orange,
        surface: pageBackground,
        error: red,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(
        weight: 600,
        opticalSize: 24,
      ),
      dividerTheme: const DividerThemeData(color: cardBorder, thickness: 1),
      scaffoldBackgroundColor: pageBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: IconThemeData(
          color: navy,
          weight: 600,
          opticalSize: 24,
        ),
      ),
    );
  }
}
