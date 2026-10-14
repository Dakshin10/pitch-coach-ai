import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/practice_drill.dart';
import '../../core/models/practice_mode.dart';
import '../../core/models/session_result.dart';
import '../../core/models/slide_coach_models.dart';
import '../../core/providers/session_results_provider.dart';
import '../../core/providers/slide_coach_provider.dart';
import '../../core/providers/stats_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/demo_repository.dart';
import '../../core/repositories/practice_plan_repository.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/circular_gauge_painter.dart';

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

  // Personalized Practice Plan (Feature 6)
  PracticePlan? _practicePlan;
  bool _practicePlanLoading = true;

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

    final cachedPlan = PracticePlanRepository.instance.cachedPlan;
    if (cachedPlan != null) {
      _practicePlan = cachedPlan;
      _practicePlanLoading = false;
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
          _practicePlan = PracticePlanRepository.defaultFallbackPlan;
          _practicePlanLoading = false;
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
      final session = await SessionRepository.instance.getRecentSession(
        forceRefresh: force,
      );
      if (mounted) {
        setState(() {
          _recentSession = session;
          _recentSessionLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _recentSessionLoading = false);
    }

    // Load personalized practice plan drills (Feature 6)
    try {
      final plan = await PracticePlanRepository.instance.getPracticePlan(
        forceRefresh: force,
      );
      if (mounted) {
        setState(() {
          _practicePlan = plan;
          _practicePlanLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _practicePlanLoading = false);
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
    final slideCoach = context.watch<SlideCoachProvider>();
    final sessionResults = context.watch<SessionResultsProvider>();

    if (slideCoach.completedDeckToAnnounce != null) {
      final deck = slideCoach.completedDeckToAnnounce!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        slideCoach.dismissCompletedAnnouncement();
        _showDeckReadyPopup(context, deck);
      });
    }

    if (sessionResults.completedSessionToAnnounce != null) {
      final session = sessionResults.completedSessionToAnnounce!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        sessionResults.dismissCompletedAnnouncement();
        _showSessionReadyPopup(context, session);
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primaryPurple,
          backgroundColor: AppColors.cardOf(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Row (Dynamic User Greeting)
                _buildHeaderRow(context, user),

                if (slideCoach.hasActiveBackgroundProcessing) ...[
                  const SizedBox(height: 16),
                  _buildSlideProcessingBanner(context, slideCoach),
                ],

                if (sessionResults.hasActiveBackgroundProcessing) ...[
                  const SizedBox(height: 16),
                  _buildSpeechProcessingBanner(context, sessionResults),
                ],

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
                    colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
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
                    colors: [AppColors.accentBlue, AppColors.accentBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () =>
                      context.push('/interview', extra: 'presentation'),
                ),
                const SizedBox(height: 12),
                _PracticeModeCard(
                  title: 'Free Talk',
                  subtitle: 'Speak about any topic you like',
                  icon: Icons.mic_rounded,
                  gradient: const LinearGradient(
                    colors: [AppColors.accentGreen, AppColors.accentGreenLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () => context.push('/interview', extra: 'free_talk'),
                ),

                const SizedBox(height: 28),

                // Targeted Practice Drills (Feature 6)
                _buildPracticePlanSection(context),

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
      builder: (_) => _PracticeModeSheet(
        onModeTap: (route) {
          Navigator.pop(context);
          context.push(route);
        },
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, UserProfile user) {
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
        const SizedBox(width: 12),
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
                cacheWidth:
                    80, // 2x for HiDPI — avoids re-decode on rebuild
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
              Icon(
                icon,
                color: isDark ? color.withValues(alpha: 0.95) : color,
                size: 22,
              ),
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

  Widget _buildPracticePlanSection(BuildContext context) {
    if (_practicePlanLoading && _practicePlan == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Personalizing practice drills...',
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      );
    }

    final plan = _practicePlan ?? PracticePlanRepository.defaultFallbackPlan;
    final diagnosis = plan.diagnosis;
    final completedCount = plan.drills.where((d) => d.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Targeted Drills',
                  style: AppTextStyles.headingL.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    diagnosis.weakestMetric.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '$completedCount/3 Done',
              style: AppTextStyles.caption.copyWith(
                color: completedCount == 3
                    ? AppColors.accentGreen
                    : AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Diagnostic Insight Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryPurple.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryPurple,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diagnosis.diagnosticsSummary,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        height: 1.35,
                      ),
                    ),
                    if (diagnosis.scoreTrend != 'insufficient_data') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Score Trend: ${diagnosis.scoreTrend.toUpperCase()} • ${diagnosis.sessionsAnalyzed} sessions analyzed',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Drills list
        ...plan.drills.map((drill) => _buildDrillCard(context, drill)),
      ],
    );
  }

  Widget _buildDrillCard(BuildContext context, PracticeDrill drill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: drill.isCompleted
              ? AppColors.accentGreen.withValues(alpha: 0.35)
              : AppColors.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: drill.isCompleted
                      ? AppColors.accentGreen.withValues(alpha: 0.15)
                      : AppColors.primaryPurple.withValues(alpha: 0.12),
                ),
                child: Icon(
                  drill.isCompleted ? Icons.check_circle_rounded : Icons.timer_outlined,
                  size: 18,
                  color: drill.isCompleted ? AppColors.accentGreen : AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            drill.title,
                            style: AppTextStyles.bodySmallBold.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              decoration:
                                  drill.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtleOf(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${drill.targetDurationSeconds}s',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drill.description,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Why: ${drill.reason}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryPurple,
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (drill.isCompleted)
                Row(
                  children: [
                    const Icon(Icons.done_all_rounded, size: 16, color: AppColors.accentGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _launchDrill(drill),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(
                    'Start Drill',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _launchDrill(PracticeDrill drill) {
    final prompt = PracticePrompt(
      id: drill.id,
      text: drill.title,
      category: 'Targeted Drill: ${drill.targetMetric.toUpperCase()}',
      hint: '${drill.description}\n\nCoach Note: ${drill.reason}',
      targetDurationSeconds: drill.targetDurationSeconds,
    );
    final config = PracticeSessionConfig(
      modeId: PracticeMode.freeTalkId,
      prompt: prompt,
    );
    context.push('/interview', extra: config);
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildSmallStatCard(
              label: 'Sessions',
              value: isLoading ? '...' : '${s.totalSessions}',
              valueColor: AppColors.textPrimaryOf(context),
              subCaption: isLoading ? null : 'completed',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSmallStatCard(
              label: 'Avg. Confidence',
              value: isLoading
                  ? '...'
                  : '${s.avgConfidence.toStringAsFixed(0)}%',
              valueColor: AppColors.successGreen,
              subCaption: isLoading ? null : 'overall',
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
      ),
    );
  }

  Widget _buildSmallStatCard({
    required String label,
    required String value,
    required Color valueColor,
    String? subCaption,
  }) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (subCaption != null && subCaption.isNotEmpty) ? subCaption : ' ',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.textSecondaryOf(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryPurple,
                ),
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
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primaryPurpleLight,
                size: 24,
              ),
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
            child: Icon(
              modeIcon,
              color: AppColors.primaryPurpleLight,
              size: 24,
            ),
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
                    color: AppColors.textSecondaryOf(
                      context,
                    ).withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          session.analysisFailed
              ? const Tooltip(
                  message: 'Analysis failed — tap to retry',
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.warningAmber,
                    size: 30,
                  ),
                )
              : !session.isAnalyzed
                  ? Container(
                      key: const Key('home_recent_pending_indicator'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: AppColors.warningAmber,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Pending',
                            style: TextStyle(
                              color: AppColors.warningAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CircularGauge(
                      value: session.overallScore,
                      size: 46,
                      strokeWidth: 4.5,
                      gradientColors: [scoreColor, scoreColor],
                    ),
        ],
      ),
    );
  }

  Widget _buildSlideProcessingBanner(
    BuildContext context,
    SlideCoachProvider provider,
  ) {
    final st = provider.status;
    final progress = (st?.progress ?? 15) / 100.0;
    final stage = st?.stageLabel ?? 'Analyzing slide deck visuals & script...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/slide-coach/processing'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Slide Deck Processing in Background',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stage,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.primaryPurple,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: AppColors.primaryPurple,
                backgroundColor: AppColors.borderOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechProcessingBanner(
    BuildContext context,
    SessionResultsProvider provider,
  ) {
    final topic = provider.activeTopic ?? 'Interview Practice Session';
    final mode = provider.activeMode ?? 'interview';
    final modeLabel = mode == 'presentation'
        ? 'Presentation'
        : mode == 'free_talk'
        ? 'Free Talk'
        : 'Interview';
    final sessionId = provider.activeSessionId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentBlue.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (sessionId != null && sessionId.isNotEmpty) {
            context.push('/results', extra: sessionId);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$modeLabel Processing in Background',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ANALYZING',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topic,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.accentBlue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                color: AppColors.accentBlue,
                backgroundColor: AppColors.borderOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionReadyPopup(BuildContext context, SessionResult session) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppColors.cardOf(dialogCtx),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIllustration.sessionReady(size: 72),
              const SizedBox(height: 16),
              Text(
                'Practice Session Ready',
                style: AppTextStyles.headingMOf(dialogCtx),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                session.topicOrQuestion,
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.primaryPurple,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'AI speech and pacing analysis complete. Your scores, filler breakdown, and tailored coaching are ready.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(dialogCtx),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldOf(dialogCtx),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderOf(dialogCtx)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPopupStatItem(
                      dialogCtx,
                      icon: Icons.speed_rounded,
                      label: 'Overall',
                      value: '${session.overallScore.round()}%',
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: AppColors.borderOf(dialogCtx),
                    ),
                    _buildPopupStatItem(
                      dialogCtx,
                      icon: Icons.record_voice_over_rounded,
                      label: 'Pacing',
                      value: '${session.wpm.round()} WPM',
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: AppColors.borderOf(dialogCtx),
                    ),
                    _buildPopupStatItem(
                      dialogCtx,
                      icon: Icons.warning_amber_rounded,
                      label: 'Fillers',
                      value: '${session.totalFillerCount}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        context.push('/results', extra: session.sessionId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('View Results'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeckReadyPopup(BuildContext context, SlideDeckModel deck) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: AppColors.cardOf(dialogCtx),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIllustration.deckReady(size: 72),
              const SizedBox(height: 16),
              Text(
                'Slide Deck Ready',
                style: AppTextStyles.headingMOf(dialogCtx),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                deck.fileName,
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.primaryPurple,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'AI vision analysis is complete. Your slide coaching, talking points, and duration budgets are ready.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(dialogCtx),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldOf(dialogCtx),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderOf(dialogCtx)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPopupStatItem(
                      dialogCtx,
                      icon: Icons.slideshow_rounded,
                      label: 'Slides',
                      value: '${deck.slides.length}',
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: AppColors.borderOf(dialogCtx),
                    ),
                    _buildPopupStatItem(
                      dialogCtx,
                      icon: Icons.timer_outlined,
                      label: 'Target',
                      value:
                          '${(deck.targetTotalDurationSeconds / 60).toStringAsFixed(1)}m',
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: AppColors.borderOf(dialogCtx),
                    ),
                    _buildPopupStatItem(
                      dialogCtx,
                      icon: Icons.people_outline_rounded,
                      label: 'Audience',
                      value: deck.audience,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        context.push('/slide-coach/review');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Review Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryPurple),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyBold.copyWith(
            color: AppColors.textPrimaryOf(context),
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondaryOf(context),
            fontSize: 10,
          ),
        ),
      ],
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
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
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
