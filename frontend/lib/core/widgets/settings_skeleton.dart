import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shimmer-like loading skeleton for profile cards and stat rows.
class SettingsSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SettingsSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SettingsSkeleton> createState() => _SettingsSkeletonState();
}

class _SettingsSkeletonState extends State<SettingsSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final baseColor = isDark ? const Color(0xFF232038) : const Color(0xFFE4E4EC);
    final highlightColor = isDark ? const Color(0xFF332D52) : const Color(0xFFF3F3FA);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = Color.lerp(baseColor, highlightColor, _controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
