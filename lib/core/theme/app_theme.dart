import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surfaceLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPurple,
        secondary: AppColors.accentBlue,
        surface: AppColors.surfaceLight,
        error: AppColors.dangerRed,
        onPrimary: AppColors.textOnDark,
        onSecondary: AppColors.textOnDark,
        onSurface: AppColors.textPrimaryDark,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        headlineLarge: AppTextStyles.headingXL,
        headlineMedium: AppTextStyles.headingL,
        titleMedium: AppTextStyles.headingM,
        bodyMedium: AppTextStyles.bodyM,
        bodySmall: AppTextStyles.bodySmallBold,
        labelSmall: AppTextStyles.caption,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPurple,
        secondary: AppColors.accentBlue,
        surface: AppColors.cardDark,
        error: AppColors.dangerRed,
        onPrimary: AppColors.textOnDark,
        onSecondary: AppColors.textOnDark,
        onSurface: AppColors.textOnDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF262343),
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.textOnDark),
        headlineLarge: AppTextStyles.headingXL.copyWith(color: AppColors.textOnDark),
        headlineMedium: AppTextStyles.headingL.copyWith(color: AppColors.textOnDark),
        titleMedium: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
        bodyMedium: AppTextStyles.bodyM,
        bodySmall: AppTextStyles.bodySmallBold,
        labelSmall: AppTextStyles.caption,
      ),
    );
  }
}
