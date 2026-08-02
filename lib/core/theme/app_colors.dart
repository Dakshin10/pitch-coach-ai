import 'package:flutter/material.dart';

/// Centralized color palette for Pitch Coach design system.
abstract class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0F0F1A);     // dark navy-black
  static const Color surfaceLight = Color(0xFFF5F6FA);   // off-white background for light screens
  static const Color cardDark = Color(0xFF17152E);

  // Primary Purples & Gradients (#6C5CE7 -> #8B5CF6)
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color primaryPurpleLight = Color(0xFF8B5CF6);
  static const Color gradientPurpleStart = Color(0xFF6C5CE7);
  static const Color gradientPurpleEnd = Color(0xFF8B5CF6);

  // Linear Gradient helper
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientPurpleStart, gradientPurpleEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Secondary Blue (#3B82F6 -> #2563EB)
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentBlueDark = Color(0xFF2563EB);

  // Accent Green (#10B981 -> #059669)
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentGreenLight = Color(0xFF059669);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFF14142B); // main text on light screens
  static const Color textSecondary = Color(0xFF6E7191);   // subtitles, muted labels
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Status Colors
  static const Color successGreen = Color(0xFF10B981);   // "Good"/"Great" status text
  static const Color warningAmber = Color(0xFFF5A623);
  static const Color dangerRed = Color(0xFFE85C5C);

  // UI Element Colors
  static const Color divider = Color(0xFFE7E7F0);
  static const Color cardShadow = Color(0x0C0C1A1D);
}
