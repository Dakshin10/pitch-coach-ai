import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CircularGaugePainter extends CustomPainter {
  final double value; // 0.0 to 100.0
  final double strokeWidth;
  final Color trackColor;
  final List<Color> gradientColors;

  CircularGaugePainter({
    required this.value,
    this.strokeWidth = 12.0,
    this.trackColor = const Color(0xFFEBEBF5),
    this.gradientColors = const [
      AppColors.primaryPurpleLight,
      AppColors.primaryPurple,
    ],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Draw Background Track Ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw Foreground Progress Sweep Arc
    if (value > 0) {
      final sweepAngle = 2 * math.pi * (value.clamp(0.0, 100.0) / 100.0);
      const startAngle = -math.pi / 2; // Start from top (12 o'clock)

      final rect = Rect.fromCircle(center: center, radius: radius);

      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: gradientColors.length >= 2
              ? gradientColors
              : [gradientColors.first, gradientColors.first],
          transform: GradientRotation(startAngle),
        ).createShader(rect);

      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CircularGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}

/// Convenience Widget wrapping [CircularGaugePainter] with centered text.
class CircularGauge extends StatelessWidget {
  final double value; // 0 to 100
  final double size;
  final double strokeWidth;
  final String? centerBigText;
  final String? centerSmallLabel;
  final Color? trackColor;
  final List<Color>? gradientColors;

  const CircularGauge({
    super.key,
    required this.value,
    this.size = 140,
    this.strokeWidth = 12,
    this.centerBigText,
    this.centerSmallLabel,
    this.trackColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTrackColor =
        trackColor ??
        (isDark ? const Color(0xFF262343) : const Color(0xFFEFEFF8));
    final defaultGradient =
        gradientColors ??
        [AppColors.primaryPurpleLight, AppColors.primaryPurple];

    final displayValueText = centerBigText ?? '${value.round()}%';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: CircularGaugePainter(
              value: value,
              strokeWidth: strokeWidth,
              trackColor: defaultTrackColor,
              gradientColors: defaultGradient,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayValueText,
                style: AppTextStyles.displayLarge.copyWith(
                  fontSize: size * 0.24,
                  color: isDark
                      ? AppColors.textOnDark
                      : AppColors.textPrimaryDark,
                ),
              ),
              if (centerSmallLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  centerSmallLabel!,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: math.max(10, size * 0.08),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
