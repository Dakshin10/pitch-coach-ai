import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _enterController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  // Pre-computed per-bar animations — created once, never re-allocated per frame
  late final List<Animation<double>> _barAnimations;
  bool _restoredRouteHandled = false;

  static const List<double> _leftBaseHeights = [22, 32, 45, 38, 58, 72, 88];
  static const List<double> _rightBaseHeights = [88, 72, 58, 38, 45, 32, 22];
  static const List<double> _leftOpacities = [
    0.3,
    0.4,
    0.55,
    0.7,
    0.8,
    0.9,
    1.0,
  ];
  static const List<double> _rightOpacities = [
    1.0,
    0.9,
    0.8,
    0.7,
    0.55,
    0.4,
    0.3,
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Pre-compute all 14 bar animations once — no allocation inside build()
    _barAnimations = List.generate(14, (barIndex) {
      final start = ((barIndex * 0.08) % 0.6);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _waveController,
        curve: Interval(start, end, curve: Curves.easeInOutCubic),
      );
    });

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
        );
    _enterController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_restoredRouteHandled && context.watch<UserProvider>().isLoggedIn) {
      _restoredRouteHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      body: AppAtmosphere(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.topRight,
                        child: ThemeToggleButton(size: 40, compact: true),
                      ),
                      const Spacer(flex: 1),
                      _buildHeroSection(isDark),
                      const Spacer(flex: 1),
                      _buildPageIndicator(isDark),
                      const SizedBox(height: 24),
                      _buildTypographySection(isDark),
                      const Spacer(flex: 2),
                      _buildButtonStack(context, isDark),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow without ImageFiltered blur (expensive on phones).
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryPurple.withValues(
                    alpha: isDark ? 0.40 : 0.26,
                  ),
                  AppColors.primaryPurple.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _waveController,
              // Mic circle is static — pass as child so it is NOT rebuilt each frame
              child: Container(
                width: 114,
                height: 114,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWaveGroup(
                      baseHeights: _leftBaseHeights,
                      opacities: _leftOpacities,
                      startBarIndex: 0,
                    ),
                    const SizedBox(width: 14),
                    child!,
                    const SizedBox(width: 14),
                    _buildWaveGroup(
                      baseHeights: _rightBaseHeights,
                      opacities: _rightOpacities,
                      startBarIndex: 7,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveGroup({
    required List<double> baseHeights,
    required List<double> opacities,
    required int startBarIndex,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(baseHeights.length, (index) {
        final baseH = baseHeights[index];
        final opacity = opacities[index];
        // Uses pre-computed animation — zero allocation per frame
        final animatedHeight =
            baseH * (0.55 + 0.5 * _barAnimations[startBarIndex + index].value);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Container(
            width: 3.5,
            height: animatedHeight,
            decoration: BoxDecoration(
              color: AppColors.primaryPurpleLight.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPageIndicator(bool isDark) {
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.textSecondary.withValues(alpha: 0.35);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 8,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: inactive, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: inactive, shape: BoxShape.circle),
        ),
      ],
    );
  }

  Widget _buildTypographySection(bool isDark) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFFF8F7FF),
                    Color(0xFFB4A9FF),
                    Color(0xFF22D3EE),
                  ]
                : const [Color(0xFF15132A), Color(0xFF8B7CFF)],
          ).createShader(bounds),
          child: Text(
            'Pitch Coach',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingXL.copyWith(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Speak with confidence.\nPresent with clarity.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyM.copyWith(
            color: AppColors.textSecondaryOf(context),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildButtonStack(BuildContext context, bool isDark) {
    final outline = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.cardLightBorder;
    final text = AppColors.textPrimaryOf(context);

    return Column(
      children: [
        GradientButton(
          text: 'Login',
          variant: GradientButtonVariant.primary,
          height: 56,
          onPressed: () => context.push('/login', extra: false),
        ),
        const SizedBox(height: 12),
        GradientButton(
          text: 'Sign Up',
          variant: GradientButtonVariant.secondary,
          height: 56,
          borderColor: outline,
          textColor: text,
          onPressed: () => context.push('/login', extra: true),
        ),
        const SizedBox(height: 12),
        GradientButton(
          text: 'Continue as Guest',
          variant: GradientButtonVariant.tertiary,
          height: 56,
          borderColor: outline,
          textColor: text,
          onPressed: () async {
            await Provider.of<UserProvider>(
              context,
              listen: false,
            ).loginAsGuest();
            if (!context.mounted) return;
            context.go('/home');
          },
        ),
      ],
    );
  }
}
