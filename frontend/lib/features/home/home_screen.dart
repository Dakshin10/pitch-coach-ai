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
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/circular_gauge_painter.dart';
import '../../core/widgets/theme_toggle_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Real recent session — null while loading or when user has none yet
  SessionSummary? _recentSession;
  bool _recentSessionLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Populate from in-memory cache immediately if available
    final cached = SessionRepository.instance.cachedRecentSession;
    if (cached != null) {
      _recentSession = cached;
      _recentSessionLoading = false;
    }

    // Defer loads until after the first frame so navigation is not blocked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fadeController.forward();
      _loadData();
    });
  }

  Future<void> _loadData({bool force = false}) async {
    if (context.read<UserProvider>().isGuest) {
      context.read<StatsProvider>().loadDemo();
      if (mounted) {
        setState(() {
          _recentSession = DemoRepository.instance.sessions.first;
          _recentSessionLoading = false;
        });
      }
      return;
    }
    // Only show loading if we don't already have a recent session
    if (_recentSession == null) {
      setState(() => _recentSessionLoading = true);
    }
    // Load summary stats (feeds the 3 stat cards)
    final userId = context.read<UserProvider>().user.id;
    context.read<StatsProvider>().loadSummaryOnly(force: force, userId: userId);

    // Load the most recent session (feeds the recent session card)
    try {
      final session = await SessionRepository.instance.getRecentSession(forceRefresh: force);
      if (mounted) {
        setState(() {
          _recentSession = session;
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
    await _loadData(force: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Select only the fields we actually use so that unrelated state changes
    // (e.g. dark mode toggle in ThemeToggleButton) do not rebuild this Scaffold.
    final user = context.select<UserProvider, UserProfile>((p) => p.user);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primaryPurple,
          backgroundColor: AppColors.cardOf(context),
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
                Text(
                  'Choose Your Practice Mode',
                  style: AppTextStyles.headingL.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Stacked Practice-Mode Cards
                _PracticeModeCard(
                  title: 'Slide Coach (Deck Vision)',
                  subtitle: 'Upload PDF deck → AI speech notes & rehearsal',
                  icon: Icons.auto_awesome_rounded,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7C3AED),
                      Color(0xFFDB2777),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => context.push('/slide-coach'),
                ),
                const SizedBox(height: 12),
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
                  onTap: () => context.push('/interview', extra: 'interview'),
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
                  onTap: () => context.push('/interview', extra: 'presentation'),
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
                  onTap: () => context.push('/interview', extra: 'free_talk'),
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
                          color: AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondaryOf(context),
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

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = user.name.split(' ').first;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $firstName',
                style: AppTextStyles.headingXL.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to practice today?',
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            const ThemeToggleButton(size: 40, compact: true),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                   child: Image.network(
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.name)}&background=7C6CF0&color=fff&size=128',
                    width: 40,
                    height: 40,
                    cacheWidth: 80,  // 2x for HiDPI — avoids re-decode on rebuild
                    cacheHeight: 80,
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
    final isDark = AppColors.isDark(context);
    return Expanded(
      child: InkWell(
        onTap: () => context.push('/lessons'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isDark ? null : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.2),
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isDark ? color.withValues(alpha: 0.95) : color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textOnDark : color,
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
        Text(
          title,
          style: AppTextStyles.headingL.copyWith(
            color: AppColors.textPrimaryOf(context),
          ),
        ),
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
            valueColor: AppColors.textPrimaryOf(context),
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
    return GlassSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
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
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subCaption != null) ...[
            const SizedBox(height: 2),
            Text(
              subCaption,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textSecondaryOf(context),
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
      return GlassSurface(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
              ),
            ),
          ),
        ),
      );
    }

    // No sessions yet — prompt user to start
    if (_recentSession == null) {
      return GlassSurface(
        onTap: () => context.push('/interview'),
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPurple.withValues(alpha: 0.28),
                    AppColors.auroraCyan.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.primaryPurpleLight, size: 24),
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
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to start your first practice session!',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryOf(context),
              size: 22,
            ),
          ],
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

    return GlassSurface(
      onTap: () => context.push('/results', extra: session.id),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryPurple.withValues(alpha: 0.3),
                  AppColors.gradientPurpleEnd.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(modeIcon, color: AppColors.primaryPurpleLight, size: 24),
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
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.topicOrQuestion,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.dateFormatted} · ${session.durationFormatted}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context).withValues(alpha: 0.75),
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
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
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
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF161428), Color(0xFF0E0D18)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: isDark ? null : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDarkBorder : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Practice',
                    style: AppTextStyles.headingL.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    'Choose a practice mode',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildModeOption(
            context,
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF7C3AED),
            title: 'Slide Coach (Deck Vision)',
            subtitle: 'Upload PDF deck for slide-by-slide AI coaching',
            route: '/slide-coach',
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            context,
            icon: Icons.event_seat_rounded,
            color: AppColors.primaryPurple,
            title: 'Interview Practice',
            subtitle: 'Practice common interview questions',
            route: '/interview',
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            context,
            icon: Icons.bar_chart_rounded,
            color: AppColors.accentBlue,
            title: 'Presentation Practice',
            subtitle: 'Rehearse your slides or speeches',
            route: '/interview',
          ),
          const SizedBox(height: 12),
          _buildModeOption(
            context,
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

  Widget _buildModeOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String route,
  }) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      onTap: () => onModeTap(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
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
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
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

