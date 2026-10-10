import 'package:flutter/material.dart';

/// TradeWorks colour and type tokens — design standard v3.3.
///
/// Type families are the bundled assets declared in pubspec.yaml ('Inter'
/// 400–700, 'Outfit' 600–700), so every inline `TextStyle(fontWeight: …)`
/// that inherits the family gets the real weight, not a synthesised one.
/// Sizes and line heights live in `lib/ui/tw.dart` (`TwType`).
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

  /// Tint behind a red icon (error notification, destructive confirm).
  static const Color redTint = Color(0xFFFEF3F2);
  static const Color purple = Color(0xFF6D28D9);
  static const Color purpleTint = Color(0xFFF4EFFE);
  static const Color gold = Color(0xFFE9A23B);
  static const Color ratingTint = Color(0xFFFEF6E7);
  static const Color ratingText = Color(0xFF7A4A06);
  static const Color chipBooked = textSecondary;
  static const Color chipBookedTint = pageBackground;
  static const Color chipNeutral = textSecondary;
  static const Color chipNeutralTint = pageBackground;

  /// Modal barrier behind sheets and dialogs (#101828 at 45%).
  static const Color scrim = Color(0x73101828);

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

  /// Bundled font families (pubspec.yaml `fonts:`).
  static const String fontInter = 'Inter';
  static const String fontOutfit = 'Outfit';

  static TextStyle get headingStyle => const TextStyle(
        fontFamily: fontOutfit,
        color: navy,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get bodyStyle => const TextStyle(
        fontFamily: fontInter,
        color: body,
        fontSize: 16,
        height: 1.5,
      );

  static TextTheme get textTheme => const TextTheme(
        displayLarge: TextStyle(
            fontFamily: fontOutfit,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.17,
            color: navy),
        displayMedium: TextStyle(
            fontFamily: fontOutfit,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.19,
            color: navy),
        displaySmall: TextStyle(
            fontFamily: fontOutfit,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 34 / 28,
            color: navy),
        headlineLarge: TextStyle(
            fontFamily: fontOutfit,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.23,
            color: navy),
        headlineMedium: TextStyle(
            fontFamily: fontOutfit,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: navy),
        // E04 report headline uses headlineSmall: Outfit 24/30 700.
        headlineSmall: TextStyle(
            fontFamily: fontOutfit,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 30 / 24,
            color: navy),
        titleLarge: TextStyle(
            fontFamily: fontOutfit,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 24 / 18,
            color: navy),
        titleMedium: TextStyle(
            fontFamily: fontInter,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 22 / 16,
            color: navy),
        titleSmall: TextStyle(
            fontFamily: fontInter,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
            color: navy),
        bodyLarge: TextStyle(
            fontFamily: fontInter,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: body),
        bodyMedium: TextStyle(
            fontFamily: fontInter,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 22 / 15,
            color: body),
        bodySmall: TextStyle(
            fontFamily: fontInter,
            fontSize: 14,
            height: 20 / 14,
            color: textSecondary),
        labelLarge: TextStyle(
            fontFamily: fontInter,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: navy),
        labelMedium: TextStyle(
            fontFamily: fontInter,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSecondary),
        labelSmall: TextStyle(
            fontFamily: fontInter,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 18 / 13,
            color: textSecondary),
      );

  static OutlineInputBorder _inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );

  static ThemeData get lightTheme {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      // DefaultTextStyle for every Text without a family: bundled Inter.
      fontFamily: fontInter,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: blue,
        onPrimary: white,
        secondary: blue,
        tertiary: orange,
        onTertiary: onOrange,
        surface: pageBackground,
        surfaceTint: Colors.transparent,
        error: red,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: pageBackground,
      iconTheme: const IconThemeData(color: navy, weight: 500, opticalSize: 24),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        titleTextStyle: TextStyle(
          fontFamily: fontOutfit,
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        iconTheme: IconThemeData(color: navy, weight: 500, opticalSize: 24),
        actionsIconTheme: IconThemeData(color: navy, size: 22),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: onOrange,
          // v3.3: disabled is orange at 40% with the navy label at 60%.
          disabledBackgroundColor: orange.withOpacity(0.4),
          disabledForegroundColor: onOrange.withOpacity(0.6),
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: fontInter,
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: onOrange,
          disabledBackgroundColor: orange.withOpacity(0.4),
          disabledForegroundColor: onOrange.withOpacity(0.6),
          minimumSize: const Size(64, 52),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: fontInter,
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          backgroundColor: white,
          side: const BorderSide(color: border),
          minimumSize: const Size(64, 48),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: fontInter,
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(
            fontFamily: fontInter,
            fontSize: 15,
            height: 22 / 15,
            fontWeight: FontWeight.w600,
          ),
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
        // Rest: subtle fill. Focus: white fill with the blue ring.
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? white : subtle,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: _inputBorder(cardBorder, 1),
        enabledBorder: _inputBorder(cardBorder, 1),
        disabledBorder: _inputBorder(cardBorder, 1),
        focusedBorder: _inputBorder(blue, 1.5),
        errorBorder: _inputBorder(red, 1.5),
        focusedErrorBorder: _inputBorder(red, 1.5),
        hintStyle: const TextStyle(
          fontFamily: fontInter,
          color: textTertiary,
          fontSize: 16,
          height: 24 / 16,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontInter,
          color: textSecondary,
          fontSize: 16,
        ),
        errorStyle: const TextStyle(
          fontFamily: fontInter,
          color: red,
          fontSize: 13,
          height: 18 / 13,
        ),
        helperStyle: const TextStyle(
          fontFamily: fontInter,
          color: textSecondary,
          fontSize: 13,
          height: 18 / 13,
        ),
        counterStyle: const TextStyle(
          fontFamily: fontInter,
          color: textSecondary,
          fontSize: 13,
          height: 18 / 13,
        ),
        errorMaxLines: 3,
      ),
      // §1.5: sheets are white, top radius 20, centred max 560 on Wide.
      // The grabber is drawn by TwSheet / the sheet itself, so the theme's
      // own drag handle stays off (no double handles).
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        modalBackgroundColor: white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: scrim,
        showDragHandle: false,
        dragHandleColor: border,
        dragHandleSize: Size(36, 4),
        clipBehavior: Clip.antiAlias,
        constraints: BoxConstraints(maxWidth: 560),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      // §4 Dialogs: radius 20, inset 24, Outfit h3 title, bodySm content.
      dialogTheme: const DialogTheme(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: scrim,
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontOutfit,
          fontSize: 17,
          height: 22 / 17,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontInter,
          fontSize: 15,
          height: 22 / 15,
          color: body,
        ),
        actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 24),
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
          (states) => TextStyle(
            fontFamily: fontInter,
            fontSize: 11.5,
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
