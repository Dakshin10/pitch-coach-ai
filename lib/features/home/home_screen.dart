import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/session_result.dart';
import '../../core/providers/stats_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/repositories/demo_repository.dart';
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

  // Real recent session — null while loading or when user has none yet
  SessionSummary? _recentSession;
  bool _recentSessionLoading = true;

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

    // Load stats + recent session after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (context.read<UserProvider>().isGuest) {
      context.read<StatsProvider>().loadDemo();
      if (mounted) setState(() {
        _recentSession = DemoRepository.instance.sessions.first;
        _recentSessionLoading = false;
      });
      return;
    }
    // Load summary stats (feeds the 3 stat cards)
    context.read<StatsProvider>().loadSummaryOnly();

    // Load the most recent session (feeds the recent session card)
    try {
      final sessions = await SessionRepository.instance.listSessions(limit: 1);
      if (mounted) {
        setState(() {
          _recentSession = sessions.isNotEmpty ? sessions.first : null;
          _recentSessionLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _recentSessionLoading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _fadeController.reset();
    setState(() => _recentSessionLoading = true);
    await _loadData();
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

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
                // 1. Top Header Row (Dynamic User Greeting)
                _buildHeaderRow(context, user),

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

                // 4. "Your Progress" Header
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

                // 5. Stat Cards Row — wired to StatsProvider
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildProgressStatCards(context),
                ),

                const SizedBox(height: 24),

                // 6. "Recent Session" Header + View All
                _buildSectionHeader(
                  title: 'Recent Session',
                  trailing: GestureDetector(
                    onTap: () => context.push('/history'),
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

                // 7. Recent Session Card — real data
                _buildRecentSessionCard(context),

                const SizedBox(height: 24),

                // Learn section — quick access to lesson library
                _buildSectionHeader(
                  title: 'Learn & Improve',
                  trailing: GestureDetector(
                    onTap: () => context.push('/lessons'),
                    child: Text(
                      'All Lessons >',
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Lesson quick-access row
                Row(
                  children: [
                    _buildLearnChip(
                      context,
                      icon: Icons.event_seat_rounded,
                      label: 'Interview',
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 10),
                    _buildLearnChip(
                      context,
                      icon: Icons.bar_chart_rounded,
                      label: 'Presentation',
                      color: AppColors.accentBlue,
                    ),
                    const SizedBox(width: 10),
                    _buildLearnChip(
                      context,
                      icon: Icons.mic_rounded,
                      label: 'Speaking',
                      color: AppColors.accentGreen,
                    ),
                  ],
                ),

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

      // FloatingActionButton — Quick Practice (Unit 1)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPracticeModeSheet(context),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.mic_rounded),
        label: Text(
          'Quick Practice',
          style: AppTextStyles.bodySmallBold.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showPracticeModeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PracticeModeSheet(onModeTap: (route) {
        Navigator.pop(context);
        context.push(route);
      }),
    );
  }

  Widget _buildHeaderRow(BuildContext context, UserProfile user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Hello, ${user.name.split(' ').first}',
                  style: AppTextStyles.headingXL.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('👋', style: TextStyle(fontSize: 22)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ready to practice today?',
              style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFEBEBF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(width: 10),
      // Avatar with Image.network + initials fallback (Unit 1)
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.name)}&background=6C5CE7&color=fff&size=128',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        user.initials,
                        style: AppTextStyles.bodySmallBold.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Text(
                          user.initials,
                          style: AppTextStyles.bodySmallBold.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLearnChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push('/lessons'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

  /// Stat cards driven by StatsProvider — shows '...' while loading.
  Widget _buildProgressStatCards(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final isLoading = stats.isLoading || stats.state == StatsLoadState.idle;
    final s = stats.summary;

    String fillerLabel;
    if (isLoading) {
      fillerLabel = '...';
    } else {
      final pct = s.fillerReductionPct;
      fillerLabel = pct >= 0
          ? '-${pct.toStringAsFixed(0)}%'
          : '+${(-pct).toStringAsFixed(0)}%';
    }

    return Row(
      children: [
        Expanded(
          child: _buildSmallStatCard(
            label: 'Sessions',
            value: isLoading ? '...' : '${s.totalSessions}',
            valueColor: AppColors.textPrimaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSmallStatCard(
            label: 'Avg. Confidence',
            value: isLoading ? '...' : '${s.avgConfidence.toStringAsFixed(0)}%',
            valueColor: AppColors.successGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSmallStatCard(
            label: 'Filler Words',
            value: fillerLabel,
            valueColor: !isLoading && s.fillerReductionPct >= 0
                ? AppColors.accentGreen
                : AppColors.warningAmber,
            subCaption: isLoading ? null : 'vs last week',
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
          BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 3)),
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
    // Loading skeleton
    if (_recentSessionLoading) {
      return Container(
        height: 76,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: const [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
            ),
          ),
        ),
      );
    }

    // No sessions yet — prompt user to start
    if (_recentSession == null) {
      return GestureDetector(
        onTap: () => context.push('/interview'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: const [
              BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primaryPurple, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No sessions yet',
                      style: AppTextStyles.headingM.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to start your first practice session!',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 22),
            ],
          ),
        ),
      );
    }

    // Real most-recent session
    final session = _recentSession!;
    final scoreColor = session.overallScore >= 80
        ? AppColors.successGreen
        : session.overallScore >= 60
            ? AppColors.warningAmber
            : AppColors.dangerRed;
    final modeIcon = session.mode == 'presentation'
        ? Icons.bar_chart_rounded
        : session.mode == 'free_talk'
            ? Icons.mic_rounded
            : Icons.event_seat_rounded;

    return GestureDetector(
      onTap: () => context.push('/results', extra: session.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: const [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(modeIcon, color: AppColors.primaryPurple, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.modeLabel,
                    style: AppTextStyles.headingM.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.topicOrQuestion,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.dateFormatted} · ${session.durationFormatted}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            CircularGauge(
              value: session.overallScore,
              size: 46,
              strokeWidth: 4.5,
              gradientColors: [scoreColor, scoreColor],
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
                child: Icon(widget.icon, color: Colors.white, size: 28),
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
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Practice Mode Bottom Sheet ─────────────────────────────────────────────

/// Modal bottom sheet that lets the user pick a practice mode from the FAB.
class _PracticeModeSheet extends StatelessWidget {
  final void Function(String route) onModeTap;

  const _PracticeModeSheet({required this.onModeTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Logo + Title
          Row(
            children: [
              Image.asset(
                'assets/images/pitch_coach_logo.png',
                width: 36,
                height: 36,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.mic_rounded,
                  color: AppColors.primaryPurple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Practice',
                    style: AppTextStyles.headingL.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  Text(
                    'Choose a practice mode',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Mode options
          _buildModeOption(
            icon: Icons.event_seat_rounded,
            color: AppColors.primaryPurple,
            title: 'Interview Practice',
            subtitle: 'Practice common interview questions',
            route: '/interview',
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            icon: Icons.bar_chart_rounded,
            color: AppColors.accentBlue,
            title: 'Presentation Practice',
            subtitle: 'Rehearse your slides or speeches',
            route: '/interview',
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            icon: Icons.mic_rounded,
            color: AppColors.accentGreen,
            title: 'Free Talk',
            subtitle: 'Speak freely on any topic',
            route: '/interview',
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return InkWell(
      onTap: () => onModeTap(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headingM.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

