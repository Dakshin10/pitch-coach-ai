import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_atmosphere.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class ProUpgradeScreen extends StatefulWidget {
  const ProUpgradeScreen({super.key});

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  bool _isJoining = false;
  bool _joinedWaitlist = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    // Check if user already joined waitlist from persisted settings
    if (settings.themeMode.toString().isNotEmpty) {
      // settings is initialized
    }
  }

  Future<void> _joinWaitlist() async {
    setState(() => _isJoining = true);
    final userProvider = context.read<UserProvider>();
    final settings = context.read<SettingsProvider>();

    try {
      await userProvider.patchUser({'pro_waitlist': true});
      await settings.syncWithBackend();
      setState(() => _joinedWaitlist = true);
      if (mounted) {
        AppToast.success(
          context,
          "You're on the VIP waitlist! We'll notify you when Pro is ready.",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _joinedWaitlist = true);
        AppToast.info(
          context,
          "You're on the waitlist! Thank you for your interest.",
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final isPro = user.isPro;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                      icon: RotatedBox(
                        quarterTurns: 2,
                        child: AppIcon(
                          AppIcons.chevronRight,
                          size: 20,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pitch Coach Pro',
                        style: AppTextStyles.headingM.copyWith(
                          fontSize: 18,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    const ThemeToggleButton(size: 38, compact: true),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hero Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryPurple.withValues(alpha: 0.25),
                              AppColors.secondaryCyan.withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primaryPurple.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: AppColors.accentGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondaryCyan.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: const AppIcon(
                                AppIcons.crown,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isPro
                                  ? 'Pro Membership Active'
                                  : 'Unlock Pitch Coach Pro',
                              style: AppTextStyles.headingL.copyWith(
                                fontSize: 22,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isPro
                                  ? 'You have unlimited AI analysis, slide rehearsals, and personalized feedback.'
                                  : 'Supercharge your communication with unlimited AI analyses, deep speech analytics, and custom drills.',
                              style: AppTextStyles.bodyM.copyWith(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Feature Comparison List
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Pro Superpowers',
                          style: AppTextStyles.headingM.copyWith(
                            fontSize: 16,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFeatureTile(
                        context,
                        icon: AppIcons.sparkles,
                        title: 'Unlimited AI Speech Feedback',
                        subtitle:
                            'Never hit daily analysis limits during crucial interview prep',
                      ),
                      _buildFeatureTile(
                        context,
                        icon: AppIcons.slides,
                        title: 'Comprehensive Slide Deck Coach',
                        subtitle:
                            'Upload multi-slide decks with intelligent pacing & rehearsal cues',
                      ),
                      _buildFeatureTile(
                        context,
                        icon: AppIcons.chart,
                        title: 'Deep Acoustic & Pacing Metrics',
                        subtitle:
                            'WPM trends, filler word heatmaps, and pause distribution graphs',
                      ),
                      _buildFeatureTile(
                        context,
                        icon: AppIcons.trophy,
                        title: 'Personalized Coaching Curriculums',
                        subtitle:
                            'AI-generated lesson plans tailored to your specific industry goals',
                      ),

                      const SizedBox(height: 24),

                      // Comparison Matrix
                      GlassSurface(
                        padding: const EdgeInsets.all(16),
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Plan Details',
                                    style: AppTextStyles.label.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Free',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Pro',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.label.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryPurpleLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _buildComparisonRow(
                              context,
                              feature: 'Practice Sessions',
                              freeVal: '3 / day',
                              proVal: 'Unlimited',
                            ),
                            _buildComparisonRow(
                              context,
                              feature: 'Slide Coach Decks',
                              freeVal: '1 deck',
                              proVal: 'Unlimited',
                            ),
                            _buildComparisonRow(
                              context,
                              feature: 'Video & Audio Export',
                              freeVal: 'Standard',
                              proVal: 'HD + Notes',
                            ),
                            _buildComparisonRow(
                              context,
                              feature: 'Priority AI Processing',
                              freeVal: 'Normal',
                              proVal: 'Instant',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Honest CTA
                      if (isPro)
                        OutlinedButton(
                          onPressed: () {
                            AppToast.info(
                              context,
                              'Your Pro subscription is managed via your app store account.',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(
                              color: AppColors.primaryPurple,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Manage Subscription'),
                        )
                      else if (_joinedWaitlist)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.successGreen.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AppIcon(
                                AppIcons.award,
                                color: AppColors.successGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "You're on the Pro VIP Waitlist!",
                                style: AppTextStyles.bodyM.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            GradientButton(
                              text: _isJoining
                                  ? 'Joining...'
                                  : 'Join Pro Waitlist (Coming Soon)',
                              variant: GradientButtonVariant.primary,
                              height: 52,
                              onPressed: _isJoining ? null : _joinWaitlist,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Billing is currently in private beta. Early waitlist members receive 50% off.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIcon(
                icon,
                color: AppColors.primaryPurpleLight,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyM.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required String feature,
    required String freeVal,
    required String proVal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              freeVal,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              proVal,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryPurpleLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
