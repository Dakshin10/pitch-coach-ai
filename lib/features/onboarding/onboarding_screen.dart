import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // 1. Center Hero Area (Mic + Sound Waves + Glow)
                  _buildHeroSection(constraints),

                  const Spacer(flex: 1),

                  // 2. Page Indicator Dots
                  _buildPageIndicator(),

                  const SizedBox(height: 24),

                  // 3. Headline & Subheadline
                  _buildTypographySection(),

                  const Spacer(flex: 2),

                  // 4. Bottom Button Stack
                  _buildButtonStack(context),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroSection(BoxConstraints constraints) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Soft Radial Glow
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryPurple.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                  stops: const [0.25, 1.0],
                ),
              ),
            ),
          ),

          // Row with Left Waves, Center Mic Circle, Right Waves
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left 7 Sound Wave Bars (outer to inner)
                  _buildWaveGroup(
                    baseHeights: [22, 32, 45, 38, 58, 72, 88],
                    opacities: [0.3, 0.4, 0.55, 0.7, 0.8, 0.9, 1.0],
                    isLeft: true,
                  ),

                  const SizedBox(width: 12),

                  // Center Mic Circle Icon
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurpleLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right 7 Sound Wave Bars (inner to outer)
                  _buildWaveGroup(
                    baseHeights: [88, 72, 58, 38, 45, 32, 22],
                    opacities: [1.0, 0.9, 0.8, 0.7, 0.55, 0.4, 0.3],
                    isLeft: false,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaveGroup({
    required List<double> baseHeights,
    required List<double> opacities,
    required bool isLeft,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(baseHeights.length, (index) {
        final double baseH = baseHeights[index];
        final double opacity = opacities[index];

        // Staggered interval calculation per bar index
        final barIndex = isLeft ? index : (index + 7);
        final start = ((barIndex * 0.08) % 0.6);
        final end = (start + 0.4).clamp(0.0, 1.0);

        final barAnimation = CurvedAnimation(
          parent: _waveController,
          curve: Interval(start, end, curve: Curves.easeInOutCubic),
        );

        final animatedHeight = baseH * (0.55 + 0.5 * barAnimation.value);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Container(
            width: 3.5,
            height: animatedHeight,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Active dot
        Container(
          width: 24,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryPurpleLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        // Inactive dot 1
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        // Inactive dot 2
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildTypographySection() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Pitch ',
                style: AppTextStyles.headingXL.copyWith(
                  color: AppColors.textOnDark,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: 'Coach',
                style: AppTextStyles.headingXL.copyWith(
                  color: AppColors.primaryPurpleLight,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Speak with confidence.\nPresent with clarity.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyM.copyWith(
            color: const Color(0xFFB8B6CE),
            fontSize: 16,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildButtonStack(BuildContext context) {
    return Column(
      children: [
        // 1. Login - Primary purple gradient
        GradientButton(
          text: 'Login',
          variant: GradientButtonVariant.primary,
          height: 56,
          onPressed: () => context.push('/login', extra: false),
        ),
        const SizedBox(height: 12),

        // 2. Sign Up - Secondary dark card with 10% white border
        GradientButton(
          text: 'Sign Up',
          variant: GradientButtonVariant.secondary,
          height: 56,
          borderColor: Colors.white.withValues(alpha: 0.1),
          textColor: Colors.white,
          onPressed: () => context.push('/login', extra: true),
        ),
        const SizedBox(height: 12),

        // 3. Continue as Guest - Tertiary transparent with 20% white border
        GradientButton(
          text: 'Continue as Guest',
          variant: GradientButtonVariant.tertiary,
          height: 56,
          borderColor: Colors.white.withValues(alpha: 0.2),
          textColor: Colors.white,
          onPressed: () {
            Provider.of<UserProvider>(context, listen: false).loginAsGuest();
            context.go('/home');
          },
        ),
      ],
    );
  }
}
