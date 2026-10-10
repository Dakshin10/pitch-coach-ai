import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// Standard, consistent toast notification system using AppIcon SVGs (no emojis).
class AppToast {
  static void success(BuildContext context, String message) => showSuccess(context, message);
  static void error(BuildContext context, String message) => showError(context, message);
  static void info(BuildContext context, String message) => showInfo(context, message);

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      iconName: AppIcons.checkCircle,
      iconColor: AppColors.successGreen,
      backgroundColor: AppColors.isDark(context)
          ? const Color(0xFF1E2620)
          : const Color(0xFFEAF8EE),
      borderColor: AppColors.successGreen.withValues(alpha: 0.4),
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      iconName: AppIcons.info,
      iconColor: AppColors.dangerRed,
      backgroundColor: AppColors.isDark(context)
          ? const Color(0xFF28181A)
          : const Color(0xFFFDF0F0),
      borderColor: AppColors.dangerRed.withValues(alpha: 0.4),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      iconName: AppIcons.info,
      iconColor: AppColors.accentBlue,
      backgroundColor: AppColors.isDark(context)
          ? const Color(0xFF152233)
          : const Color(0xFFEDF5FD),
      borderColor: AppColors.accentBlue.withValues(alpha: 0.4),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required String iconName,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(milliseconds: 3200),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              AppIcon(iconName, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
