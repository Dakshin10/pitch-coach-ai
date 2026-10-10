import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/slide_coach_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class SlideProcessingScreen extends StatefulWidget {
  const SlideProcessingScreen({super.key});

  @override
  State<SlideProcessingScreen> createState() => _SlideProcessingScreenState();
}

class _SlideProcessingScreenState extends State<SlideProcessingScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<SlideCoachProvider>();
    if (provider.status?.status == 'done' && provider.deck != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/slide-coach/review');
      });
    }
  }

  String _getStageTitle(String? stage) {
    switch (stage) {
      case 'rendering':
        return 'Stage 1: Rendering High-Res Slides';
      case 'reading_slides':
        return 'Stage 2: Vision Model Scanning Diagrams';
      case 'writing_coaching':
        return 'Stage 3: Synthesizing Pitch Script & Timing';
      default:
        return 'Analyzing Presentation...';
    }
  }

  String _getStageSubtitle(String? stage) {
    switch (stage) {
      case 'rendering':
        return 'Extracting vector pages and rendering crisp slide thumbnails...';
      case 'reading_slides':
        return 'Detecting charts, KPIs, visual density, and readability friction...';
      case 'writing_coaching':
        return 'Crafting tailored talking points, transition hooks, and duration budgets...';
      default:
        return 'Preparing your personalized presentation coaching plan...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlideCoachProvider>();
    final st = provider.status;
    final progress = (st?.progress ?? 10) / 100.0;
    final stage = st?.stage;
    final error = provider.pollError;

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('AI Analysis in Progress'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: 'Minimize & Run in Background',
          onPressed: () => context.go('/home'),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ThemeToggleButton(size: 38, compact: true),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (error != null) ...[
                const Icon(Icons.error_outline, size: 64, color: AppColors.dangerRed),
                const SizedBox(height: 18),
                Text('Analysis Error', style: AppTextStyles.headingMOf(context)),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryOf(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (provider.activeDeckId != null) {
                      provider.startPolling(provider.activeDeckId!);
                    } else {
                      context.pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
                  child: const Text('Retry Analysis', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ] else ...[
                // Glowing Animated Spinner
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        color: AppColors.primaryPurple,
                        backgroundColor: AppColors.cardOf(context),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: AppTextStyles.headingL.copyWith(color: AppColors.primaryPurple),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                Text(
                  _getStageTitle(stage),
                  style: AppTextStyles.headingMOf(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _getStageSubtitle(stage),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Pipeline Step Indicators
                _buildStepRow(
                  context,
                  stepNumber: 1,
                  title: 'Page Rendering',
                  isDone: progress >= 0.35,
                  isActive: stage == 'rendering',
                ),
                const SizedBox(height: 12),
                _buildStepRow(
                  context,
                  stepNumber: 2,
                  title: 'Multimodal Vision Scan',
                  isDone: progress >= 0.75,
                  isActive: stage == 'reading_slides',
                ),
                const SizedBox(height: 12),
                _buildStepRow(
                  context,
                  stepNumber: 3,
                  title: 'Speech Coaching & Timing',
                  isDone: progress >= 1.0,
                  isActive: stage == 'writing_coaching',
                ),

                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.downloading_rounded, size: 18),
                  label: const Text('Minimize & Run in Background'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context, {
    required int stepNumber,
    required String title,
    required bool isDone,
    required bool isActive,
  }) {
    Color iconColor;
    IconData icon;
    if (isDone) {
      iconColor = AppColors.successGreen;
      icon = Icons.check_circle;
    } else if (isActive) {
      iconColor = AppColors.primaryPurple;
      icon = Icons.radio_button_checked;
    } else {
      iconColor = AppColors.textSecondaryOf(context).withValues(alpha: 0.4);
      icon = Icons.radio_button_unchecked;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.primaryPurple.withValues(alpha: 0.5) : AppColors.borderOf(context),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.bodyBold.copyWith(
              color: isDone || isActive ? AppColors.textPrimaryOf(context) : AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
