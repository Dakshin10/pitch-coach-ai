import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum GradientButtonVariant {
  primary,
  secondary,
  tertiary,
}

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final GradientButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final Color? borderColor;
  final Color? textColor;
  final bool enableScaleAnimation;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = GradientButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 56,
    this.borderColor,
    this.textColor,
    this.enableScaleAnimation = true,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    BoxDecoration decoration;
    TextStyle textStyle;

    switch (widget.variant) {
      case GradientButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: isDisabled
              ? LinearGradient(
                  colors: [
                    AppColors.gradientPurpleStart.withValues(alpha: 0.5),
                    AppColors.gradientPurpleEnd.withValues(alpha: 0.5),
                  ],
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        );
        textStyle = AppTextStyles.headingM.copyWith(
          color: widget.textColor ?? AppColors.textOnDark,
        );
        break;

      case GradientButtonVariant.secondary:
        decoration = BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: widget.borderColor ?? AppColors.primaryPurple.withValues(alpha: 0.4),
            width: 1,
          ),
        );
        textStyle = AppTextStyles.headingM.copyWith(
          color: widget.textColor ?? AppColors.textOnDark,
        );
        break;

      case GradientButtonVariant.tertiary:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: widget.borderColor ?? AppColors.textSecondary.withValues(alpha: 0.4),
            width: 1,
          ),
        );
        textStyle = AppTextStyles.headingM.copyWith(
          color: widget.textColor ?? AppColors.textOnDark,
        );
        break;
    }

    final buttonContent = Container(
      width: widget.width ?? double.infinity,
      height: widget.height,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : widget.onPressed,
          onTapDown: widget.enableScaleAnimation && !isDisabled
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: widget.enableScaleAnimation && !isDisabled
              ? (_) => setState(() => _isPressed = false)
              : null,
          onTapCancel: widget.enableScaleAnimation && !isDisabled
              ? () => setState(() => _isPressed = false)
              : null,
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white10,
          highlightColor: Colors.white12,
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.textColor ??
                            (widget.variant == GradientButtonVariant.tertiary
                                ? AppColors.primaryPurple
                                : AppColors.textOnDark),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 20,
                          color: textStyle.color,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: textStyle,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!widget.enableScaleAnimation || isDisabled) {
      return buttonContent;
    }

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: buttonContent,
    );
  }
}
