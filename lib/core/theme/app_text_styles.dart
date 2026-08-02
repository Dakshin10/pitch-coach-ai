import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized typography hierarchy using Inter font.
abstract class AppTextStyles {
  /// Display Large: 32 / Bold — used for big score numbers ("82%", "76")
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
        height: 1.2,
      );

  /// Heading XL: 26 / w700 — "Pitch Coach", "Hello, Nihil"
  static TextStyle get headingXL => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
        height: 1.25,
      );

  /// Heading L: 20 / w700 — section headers "Choose Your Practice Mode", "Session Results"
  static TextStyle get headingL => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
        height: 1.3,
      );

  /// Heading M: 17 / w600 — card titles "Interview Practice", "Overall Score"
  static TextStyle get headingM => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark,
        height: 1.35,
      );

  /// Body M: 14 / w400 — subtitles and descriptions, color textSecondary
  static TextStyle get bodyM => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  /// Body Small Bold: 13 / w600 — stat labels "Filler Words", "Pauses"
  static TextStyle get bodySmallBold => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  /// Caption: 12 / w500 — small muted labels, timestamps
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.4,
      );
}
