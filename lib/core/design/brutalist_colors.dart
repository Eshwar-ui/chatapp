import 'package:flutter/material.dart';

/// Chat-focused design system colors.
/// The old brutalist names are kept as compatibility tokens for existing code.
class BrutalistColors {
  // Core neutrals
  static const Color pureBlack = Color(0xFF172033);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Calm blue-gray neutrals
  static const Color concrete900 = Color(0xFF111827);
  static const Color concrete800 = Color(0xFF1F2937);
  static const Color concrete700 = Color(0xFF334155);
  static const Color concrete600 = Color(0xFF475569);
  static const Color concrete500 = Color(0xFF64748B);
  static const Color concrete400 = Color(0xFF94A3B8);
  static const Color concrete300 = Color(0xFFCBD5E1);

  // Light surfaces
  static const Color offWhite = Color(0xFFF8FAFC);
  static const Color cream = Color(0xFFF1F5F9);
  static const Color beige = Color(0xFFE2E8F0);

  // Accent colors
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentYellow = Color(0xFFEAB308);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color accentPurple = Color(0xFF7C3AED);

  // Primary Accent
  static const Color primaryAccent = accentBlue;
  static const Color secondaryAccent = accentRed;
  static const Color dangerAccent = accentRed;
  static const Color successAccent = accentGreen;
  static const Color warningAccent = accentYellow;

  // Chat surfaces
  static const Color chatBackground = Color(0xFFF3F6FB);
  static const Color chatPanel = pureWhite;
  static const Color chatIncoming = pureWhite;
  static const Color chatOutgoing = Color(0xFF2563EB);
  static const Color chatOutgoingPressed = Color(0xFF1D4ED8);
  static const Color chatComposer = pureWhite;

  // Light Theme
  static const Color lightBackground = chatBackground;
  static const Color lightSurface = chatPanel;
  static const Color lightPrimary = pureBlack;
  static const Color lightBorder = Color(0xFFD8E1EC);
  static const Color lightText = pureBlack;
  static const Color lightTextSecondary = concrete600;
  static const Color lightShadow = Color(0xFFCBD5E1);

  // Dark Theme tokens kept for future expansion
  static const Color darkBackground = concrete900;
  static const Color darkSurface = concrete900;
  static const Color darkPrimary = pureWhite;
  static const Color darkBorder = concrete300;
  static const Color darkText = pureWhite;
  static const Color darkTextSecondary = concrete400;
  static const Color darkShadow = concrete700;
}
