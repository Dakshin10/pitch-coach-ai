import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/circular_gauge_painter.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/stat_card.dart';

class DesignSystemDemoPage extends StatefulWidget {
  const DesignSystemDemoPage({super.key});

  @override
  State<DesignSystemDemoPage> createState() => _DesignSystemDemoPageState();
}

class _DesignSystemDemoPageState extends State<DesignSystemDemoPage> {
  int _navIndex = 0;
  double _gaugeValue = 82;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pitch Coach Design System'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.route_rounded),
            tooltip: 'Go to Onboarding',
            onPressed: () => context.push('/onboarding'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text('Typography & Theme', style: AppTextStyles.headingXL),
            const SizedBox(height: 8),
            Text('Dark Indigo/Violet palette preview and design tokens.', style: AppTextStyles.bodyM),
            const SizedBox(height: 20),

            // Color Palette Swatches
            Text('Color Palette', style: AppTextStyles.headingL),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildColorSwatch('Primary Purple', AppColors.primaryPurple),
                _buildColorSwatch('Purple Light', AppColors.primaryPurpleLight),
                _buildColorSwatch('Card Dark', AppColors.cardDark),
                _buildColorSwatch('Accent Blue', AppColors.accentBlue),
                _buildColorSwatch('Accent Green', AppColors.accentGreen),
                _buildColorSwatch('Success', AppColors.successGreen),
                _buildColorSwatch('Warning', AppColors.warningAmber),
                _buildColorSwatch('Danger', AppColors.dangerRed),
              ],
            ),
            const SizedBox(height: 32),

            // 1. GradientButton Component
            Text('1. GradientButton Variants', style: AppTextStyles.headingL),
            const SizedBox(height: 12),
            GradientButton(
              text: 'Primary CTA Button',
              icon: Icons.play_arrow_rounded,
              variant: GradientButtonVariant.primary,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            GradientButton(
              text: 'Secondary Dark Button',
              icon: Icons.mic_rounded,
              variant: GradientButtonVariant.secondary,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            GradientButton(
              text: 'Tertiary Outlined Button',
              variant: GradientButtonVariant.tertiary,
              onPressed: () {},
            ),
            const SizedBox(height: 32),

            // 2. StatCard Component
            Text('2. StatCard Component', style: AppTextStyles.headingL),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Filler Words',
                    value: '3',
                    status: 'Optimal',
                    statusColor: AppColors.successGreen,
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Pace Speed',
                    value: '142 wpm',
                    status: 'Great',
                    statusColor: AppColors.accentGreen,
                    icon: Icons.speed_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Long Pauses',
                    value: '7',
                    status: 'Needs Work',
                    statusColor: AppColors.warningAmber,
                    icon: Icons.pause_circle_outline_rounded,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Tone Variety',
                    value: '88%',
                    status: 'Optimal',
                    statusColor: AppColors.successGreen,
                    icon: Icons.graphic_eq_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 3. CircularGaugePainter Component
            Text('3. CircularGaugePainter Component', style: AppTextStyles.headingL),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  CircularGauge(
                    value: _gaugeValue,
                    size: 160,
                    strokeWidth: 14,
                    centerBigText: '${_gaugeValue.round()}%',
                    centerSmallLabel: 'Overall Score',
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _gaugeValue,
                    min: 0,
                    max: 100,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (val) {
                      setState(() {
                        _gaugeValue = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 4. Route Navigation Shortcuts
            Text('4. Screen Navigation Routes', style: AppTextStyles.headingL),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('/onboarding'),
                  avatar: const Icon(Icons.launch, size: 16),
                  onPressed: () => context.push('/onboarding'),
                ),
                ActionChip(
                  label: const Text('/home'),
                  avatar: const Icon(Icons.home, size: 16),
                  onPressed: () => context.push('/home'),
                ),
                ActionChip(
                  label: const Text('/interview'),
                  avatar: const Icon(Icons.mic, size: 16),
                  onPressed: () => context.push('/interview'),
                ),
                ActionChip(
                  label: const Text('/results'),
                  avatar: const Icon(Icons.assessment, size: 16),
                  onPressed: () => context.push('/results'),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _navIndex,
        onTap: (idx) {
          setState(() {
            _navIndex = idx;
          });
        },
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildColorSwatch(String name, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
