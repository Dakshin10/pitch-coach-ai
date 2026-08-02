import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/circular_gauge_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _fadeController.reset();
    await Future.delayed(const Duration(milliseconds: 150));
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primaryPurple,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Row
                _buildHeaderRow(),

                const SizedBox(height: 24),

                // 2. "Choose Your Practice Mode" Header
                Text('Choose Your Practice Mode', style: AppTextStyles.headingL),

                const SizedBox(height: 16),

                // 3. Stacked Practice-Mode Cards
                _PracticeModeCard(
                  title: 'Interview Practice',
                  subtitle: 'Simulate campus placement interviews',
                  icon: Icons.event_seat_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.gradientPurpleStart,
                      AppColors.gradientPurpleEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => context.push('/interview'),
                ),
                const SizedBox(height: 12),
                _PracticeModeCard(
                  title: 'Presentation Practice',
                  subtitle: 'Rehearse your slides or speeches',
                  icon: Icons.bar_chart_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.accentBlue,
                      AppColors.accentBlueDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => context.push('/interview'),
                ),
                const SizedBox(height: 12),
                _PracticeModeCard(
                  title: 'Free Talk',
                  subtitle: 'Speak about any topic you like',
                  icon: Icons.mic_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.accentGreen,
                      AppColors.accentGreenLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => context.push('/interview'),
                ),

                const SizedBox(height: 28),

                // 4. "Your Progress" Header + Dropdown
                _buildSectionHeader(
                  title: 'Your Progress',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This Week',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 5. Stat Cards Row (Fade animated on refresh)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildProgressStatCards(),
                ),

                const SizedBox(height: 24),

                // 6. "Recent Session" Header + View All
                _buildSectionHeader(
                  title: 'Recent Session',
                  trailing: GestureDetector(
                    onTap: () => context.push('/results'),
                    child: Text(
                      'View All >',
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 7. Recent Session Item Card
                _buildRecentSessionCard(context),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),

      // 8. Custom Bottom Navigation Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
              context.go('/history');
              break;
            case 2:
              context.push('/interview');
              break;
            case 3:
              context.go('/progress');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Greeting Text Stack
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Hello, Nihil',
                  style: AppTextStyles.headingXL.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '👋',
                  style: TextStyle(fontSize: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ready to practice today?',
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        // Action Icons: Bell + Avatar
        Row(
          children: [
            // Bell Notification Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEBEBF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(width: 10),

            // User Avatar (Fallback Circle with initials "D")
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryPurple,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'D',
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required Widget trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: AppTextStyles.headingL),
        trailing,
      ],
    );
  }

  Widget _buildProgressStatCards() {
    return Row(
      children: [
        // Card 1: Sessions
        Expanded(
          child: _buildSmallStatCard(
            label: 'Sessions',
            value: '7',
            valueColor: AppColors.textPrimaryDark,
          ),
        ),
        const SizedBox(width: 10),

        // Card 2: Avg. Confidence
        Expanded(
          child: _buildSmallStatCard(
            label: 'Avg. Confidence',
            value: '78%',
            valueColor: AppColors.successGreen,
          ),
        ),
        const SizedBox(width: 10),

        // Card 3: Filler Words
        Expanded(
          child: _buildSmallStatCard(
            label: 'Filler Words',
            value: '-34%',
            valueColor: AppColors.accentGreen,
            subCaption: 'vs last week',
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStatCard({
    required String label,
    required String value,
    required Color valueColor,
    String? subCaption,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.headingXL.copyWith(
              fontSize: 22,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subCaption != null) ...[
            const SizedBox(height: 2),
            Text(
              subCaption,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentSessionCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/results'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Icon Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.event_seat_rounded,
                color: AppColors.primaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Middle Information Stack
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interview Practice',
                    style: AppTextStyles.headingM.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Backend Developer — Q&A',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Today, 10:30 AM',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Right Small Circular Gauge Ring
            const CircularGauge(
              value: 82,
              size: 46,
              strokeWidth: 4.5,
              gradientColors: [
                AppColors.accentGreenLight,
                AppColors.accentGreen,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Practice Mode Card with scale-down tap animation.
class _PracticeModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _PracticeModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_PracticeModeCard> createState() => _PracticeModeCardState();
}

class _PracticeModeCardState extends State<_PracticeModeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.headingM.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.bodyM.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
