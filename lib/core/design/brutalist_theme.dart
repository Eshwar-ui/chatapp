import 'package:flutter/material.dart';
import 'brutalist_colors.dart';

class BrutalistTheme {
  // Chat-friendly border widths.
  static const double borderWidth = 1.0;
  static const double borderWidthThick = 1.5;
  static const double borderWidthThin = 1.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Curves
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 18.0;
  static const double radiusPill = 999.0;

  // Soft, tinted elevation for chat surfaces (no harsh pure-black drops).
  static List<BoxShadow> getOffsetShadow() {
    return [
      BoxShadow(
        color: BrutalistColors.lightShadow.withValues(alpha: 0.18),
        offset: const Offset(0, 4),
        blurRadius: 16,
        spreadRadius: 0,
      ),
    ];
  }

  // Typography tuned for readable chat UI.
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.15,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.35,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  // App theme - soft chat surfaces with clear contrast.
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: false,
      colorScheme: ColorScheme.light(
        primary: BrutalistColors.primaryAccent,
        onPrimary: BrutalistColors.pureWhite,
        secondary: BrutalistColors.primaryAccent,
        onSecondary: BrutalistColors.pureWhite,
        surface: BrutalistColors.lightSurface,
        onSurface: BrutalistColors.lightText,
        error: BrutalistColors.dangerAccent,
        onError: BrutalistColors.pureWhite,
      ),
      scaffoldBackgroundColor: BrutalistColors.lightBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: BrutalistColors.chatPanel,
        surfaceTintColor: Colors.transparent,
        foregroundColor: BrutalistColors.lightText,
        titleTextStyle: bodyLarge.copyWith(
          color: BrutalistColors.lightText,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: BrutalistColors.lightText),
        shadowColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrutalistColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: BrutalistColors.lightBorder,
            width: borderWidthThin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: BrutalistColors.lightBorder,
            width: borderWidthThin,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: BrutalistColors.primaryAccent,
            width: borderWidthThick,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: BorderSide(
            color: BrutalistColors.dangerAccent,
            width: borderWidth,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingSM,
        ),
        labelStyle: bodyMedium.copyWith(
          color: BrutalistColors.lightTextSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: bodyMedium.copyWith(
          color: BrutalistColors.lightTextSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrutalistColors.primaryAccent,
          foregroundColor: BrutalistColors.pureWhite,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingLG,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          elevation: 0,
          side: BorderSide(
            color: BrutalistColors.primaryAccent,
            width: borderWidthThin,
          ),
          textStyle: bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrutalistColors.lightText,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingLG,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
          side: BorderSide(
            color: BrutalistColors.lightBorder,
            width: borderWidthThin,
          ),
          textStyle: bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrutalistColors.lightText,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingMD,
            vertical: spacingSM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: BrutalistColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          side: BorderSide(
            color: BrutalistColors.lightBorder,
            width: borderWidthThin,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: BrutalistColors.lightBorder,
        thickness: borderWidthThin,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: heading1.copyWith(color: BrutalistColors.lightText),
        displayMedium: heading2.copyWith(color: BrutalistColors.lightText),
        headlineMedium: heading3.copyWith(color: BrutalistColors.lightText),
        bodyLarge: bodyLarge.copyWith(color: BrutalistColors.lightText),
        bodyMedium: bodyMedium.copyWith(color: BrutalistColors.lightText),
        bodySmall: bodySmall.copyWith(
          color: BrutalistColors.lightTextSecondary,
        ),
        labelLarge: label.copyWith(color: BrutalistColors.lightText),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BrutalistColors.primaryAccent;
          }
          return BrutalistColors.concrete500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BrutalistColors.primaryAccent.withValues(alpha: 0.4);
          }
          return BrutalistColors.concrete300;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BrutalistColors.primaryAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(BrutalistColors.pureWhite),
        side: BorderSide(
          color: BrutalistColors.lightBorder,
          width: borderWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
      ),
    );
  }
}
