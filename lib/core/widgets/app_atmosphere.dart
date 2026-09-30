import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Soft atmospheric backdrop with drifting aurora orbs (stronger in dark mode).
class AppAtmosphere extends StatefulWidget {
  final Widget child;
  final bool safeArea;

  const AppAtmosphere({
    super.key,
    required this.child,
    this.safeArea = true,
  });

  @override
  State<AppAtmosphere> createState() => _AppAtmosphereState();
}

class _AppAtmosphereState extends State<AppAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_drift.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.heroOf(context)),
            ),
            if (isDark)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.2 + t * 0.3, -0.8),
                    radius: 1.15,
                    colors: [
                      AppColors.primaryPurple.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            Positioned(
              top: -90 + t * 24,
              right: -50 + t * 18,
              child: _GlowOrb(
                size: isDark ? 260 : 210,
                color: AppColors.primaryPurple.withValues(
                  alpha: isDark ? 0.38 : 0.16,
                ),
              ),
            ),
            Positioned(
              bottom: 80 - t * 30,
              left: -70 - t * 10,
              child: _GlowOrb(
                size: isDark ? 220 : 170,
                color: AppColors.auroraCyan.withValues(
                  alpha: isDark ? 0.22 : 0.10,
                ),
              ),
            ),
            if (isDark)
              Positioned(
                top: 220 + t * 40,
                left: 40,
                child: _GlowOrb(
                  size: 160,
                  color: AppColors.auroraPink.withValues(alpha: 0.14),
                ),
              ),
            if (widget.safeArea)
              SafeArea(child: widget.child)
            else
              widget.child,
          ],
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Theme-aware frosted / elevated surface used by cards and panels.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool elevated;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.gradient,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final decoration = BoxDecoration(
      color: gradient == null
          ? (elevated
              ? AppColors.elevatedCardOf(context)
              : AppColors.glassOf(context))
          : null,
      gradient: gradient ??
          (isDark
              ? LinearGradient(
                  colors: [
                    AppColors.cardDarkElevated.withValues(alpha: 0.92),
                    AppColors.cardDark.withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null),
      borderRadius: borderRadius,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.cardLightBorder,
      ),
      boxShadow: AppColors.softShadowOf(context),
    );

    final content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}
