import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Soft atmospheric backdrop.
///
/// Important for mobile performance:
/// - Never rebuilds [child] on the drift ticker
/// - Avoids [ImageFiltered] blurs (very expensive on phones)
/// - Disables continuous motion on phones so nav stays responsive
class AppAtmosphere extends StatefulWidget {
  final Widget child;
  final bool safeArea;

  const AppAtmosphere({super.key, required this.child, this.safeArea = true});

  @override
  State<AppAtmosphere> createState() => _AppAtmosphereState();
}

class _AppAtmosphereState extends State<AppAtmosphere>
    with SingleTickerProviderStateMixin {
  AnimationController? _drift;

  bool get _shouldAnimate {
    if (kIsWeb) return true;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) return false;
    // Continuous backdrop motion competes with navigation/scroll on phones.
    final view = View.maybeOf(context);
    final shortest = view?.physicalSize.shortestSide;
    final dpr = view?.devicePixelRatio ?? 1.0;
    if (shortest != null && shortest / dpr < 600) return false;
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = _shouldAnimate;
    if (animate && _drift == null) {
      _drift = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 14),
      )..repeat(reverse: true);
    } else if (!animate && _drift != null) {
      _drift!.dispose();
      _drift = null;
    }
  }

  @override
  void dispose() {
    _drift?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.safeArea
        ? SafeArea(child: widget.child)
        : widget.child;

    final backdrop = _drift == null
        ? const _AtmosphereBackdrop(t: 0.35)
        : AnimatedBuilder(
            animation: _drift!,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_drift!.value);
              return _AtmosphereBackdrop(t: t);
            },
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: backdrop),
        content,
      ],
    );
  }
}

class _AtmosphereBackdrop extends StatelessWidget {
  final double t;

  const _AtmosphereBackdrop({required this.t});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.heroOf(context)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.15 + t * 0.2, -0.85),
                radius: 1.2,
                colors: [
                  AppColors.primaryPurple.withValues(
                    alpha: isDark ? 0.22 : 0.12,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            top: -100 + t * 16,
            right: -60 + t * 10,
            child: _GlowOrb(
              size: isDark ? 240 : 200,
              color: AppColors.primaryPurple.withValues(
                alpha: isDark ? 0.34 : 0.14,
              ),
            ),
          ),
          Positioned(
            bottom: 90 - t * 18,
            left: -80,
            child: _GlowOrb(
              size: isDark ? 200 : 160,
              color: AppColors.auroraCyan.withValues(
                alpha: isDark ? 0.18 : 0.08,
              ),
            ),
          ),
          if (isDark)
            Positioned(
              top: 240 + t * 20,
              left: 30,
              child: _GlowOrb(
                size: 140,
                color: AppColors.auroraPink.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
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
      gradient:
          gradient ??
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
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}
