import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/session_result.dart';
import '../../core/providers/session_results_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/demo_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/circular_gauge_painter.dart';

class ResultsScreen extends StatefulWidget {
  final String? sessionId;
  const ResultsScreen({super.key, this.sessionId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _scoreGaugeAnimation;
  late Animation<double> _chartAnimation;

  // Staggered reveal animations
  late Animation<double> _card0Anim;
  late Animation<double> _card1Anim;
  late Animation<double> _card2Anim;
  late Animation<double> _card3Anim;

  int _navIndex = 0;

  // ── Audio Playback (Unit 2) ────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _playerCompleteSub;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Staggered entrance cards
    _card0Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );
    _card1Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.12, 0.47, curve: Curves.easeOutCubic),
    );
    _card2Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.24, 0.60, curve: Curves.easeOutCubic),
    );
    _card3Anim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.36, 0.72, curve: Curves.easeOutCubic),
    );

    // Score ring animation — target is real score once loaded, otherwise 0
    _scoreGaugeAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Chart draw animation
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    // Start polling if we have a session_id
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionId = widget.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        final provider = context.read<SessionResultsProvider>();
        provider.loadSession(sessionId);
        provider.addListener(_onResultsUpdate);
      } else {
        // No session id (e.g. navigated directly) — just run the animation
        _mainController.forward();
      }
    });

    // Audio player listeners
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDuration = d);
    });
    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _audioPosition = Duration.zero;
        });
      }
    });
  }

  void _onResultsUpdate() {
    final provider = context.read<SessionResultsProvider>();
    if (provider.state == ResultsLoadState.ready && provider.result != null) {
      final score = provider.result!.overallScore;
      // Re-create the tween with the real score target and replay
      _scoreGaugeAnimation = Tween<double>(begin: 0.0, end: score).animate(
        CurvedAnimation(
          parent: _mainController,
          curve: const Interval(0.1, 0.85, curve: Curves.easeOutCubic),
        ),
      );
      _mainController.forward(from: 0);
      provider.removeListener(_onResultsUpdate);
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _playerCompleteSub?.cancel();
    _mainController.dispose();
    _audioPlayer.dispose();
    // Remove listener if still attached
    try {
      context.read<SessionResultsProvider>().removeListener(_onResultsUpdate);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsProvider = context.watch<SessionResultsProvider>();
    final isGuest = context.watch<UserProvider>().isGuest;
    final result = resultsProvider.result ??
        (isGuest && widget.sessionId == null ? DemoRepository.instance.result : null);
    final isAnalyzing = resultsProvider.state == ResultsLoadState.analyzing ||
        resultsProvider.state == ResultsLoadState.loading;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar
            _buildTopAppBar(context),

            // Analyzing banner
            if (isAnalyzing && widget.sessionId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: AppColors.primaryPurple.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Analyzing your speech with AI…',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // 2. Scrollable Body with Staggered Sections
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 0: Overall Score Card
                    _buildAnimatedSection(
                      animation: _card0Anim,
                      child: _buildOverallScoreCard(result),
                    ),

                    const SizedBox(height: 20),

                    // Section 0.5: Audio Playback Card (Unit 2)
                    _buildAnimatedSection(
                      animation: _card0Anim,
                      child: _buildAudioPlaybackCard(result),
                    ),

                    const SizedBox(height: 20),

                    // Section 1: Performance Summary Grid
                    _buildAnimatedSection(
                      animation: _card1Anim,
                      child: _buildPerformanceSummary(result),
                    ),

                    const SizedBox(height: 20),

                    // Section 2: Session Comparison Line Chart
                    _buildAnimatedSection(
                      animation: _card2Anim,
                      child: _buildSessionComparison(),
                    ),

                    const SizedBox(height: 20),

                    // Section 3: Suggestions List
                    _buildAnimatedSection(
                      animation: _card3Anim,
                      child: _buildSuggestionsSection(result),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: _navIndex,
        onTap: (idx) => setState(() => _navIndex = idx),
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Chevron Button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFEBEBF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                size: 26,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),

          // Title
          Text(
            'Session Results',
            style: AppTextStyles.headingM.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          // Empty spacer for symmetry
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildAudioPlaybackCard(SessionResult? result) {
    // result.audioPath may be null if no local file is available
    final audioPath = result?.audioPath;
    final hasAudio = audioPath != null && audioPath.isNotEmpty;

    String fmtDuration(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.headphones_rounded,
                    color: AppColors.primaryPurple, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listen to Your Recording',
                        style: AppTextStyles.headingM.copyWith(fontSize: 14)),
                    Text(
                      hasAudio ? 'Tap play to review your speech' : 'No recording available',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (hasAudio) ...[
            const SizedBox(height: 14),

            // Progress slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: AppColors.primaryPurple,
                inactiveTrackColor: AppColors.divider,
                thumbColor: AppColors.primaryPurple,
                overlayColor: AppColors.primaryPurple.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: _audioDuration.inMilliseconds > 0
                    ? (_audioPosition.inMilliseconds / _audioDuration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0,
                onChanged: (val) {
                  final seek = Duration(
                    milliseconds: (val * _audioDuration.inMilliseconds).toInt(),
                  );
                  _audioPlayer.seek(seek);
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Play / Pause Button
                  GestureDetector(
                    onTap: () async {
                      if (_isPlaying) {
                        await _audioPlayer.pause();
                      } else {
                        if (_audioDuration == Duration.zero) {
                          await _audioPlayer.play(
                            DeviceFileSource(audioPath),
                          );
                        } else {
                          await _audioPlayer.resume();
                        }
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  // Time labels
                  Text(
                    '${fmtDuration(_audioPosition)} / ${fmtDuration(_audioDuration)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedSection({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final slideY = (1.0 - animation.value) * 16.0;
        return Transform.translate(
          offset: Offset(0, slideY),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildOverallScoreCard(SessionResult? result) {
    final score = result?.overallScore ?? 0.0;
    final headline = score >= 80
        ? 'Great Job!'
        : score >= 60
            ? 'Good Effort!'
            : 'Keep Practicing!';
    final summary = result != null
        ? '${result.wpm.round()} WPM · ${result.fillerWordCount} fillers · ${result.pauseCount} pauses'
        : 'You spoke clearly and confidently. Keep practicing to get even better.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Score',
                style: AppTextStyles.bodySmallBold.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gauge Ring with 0 -> 82% Animation
                  AnimatedBuilder(
                    animation: _scoreGaugeAnimation,
                    builder: (context, child) {
                      return CircularGauge(
                        value: _scoreGaugeAnimation.value,
                        size: 92,
                        strokeWidth: 9,
                        centerBigText: '${_scoreGaugeAnimation.value.round()}%',
                        trackColor: const Color(0xFFEDEDF5),
                        gradientColors: const [
                          AppColors.primaryPurpleLight,
                          AppColors.primaryPurple,
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 16),

                  // Text Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: AppTextStyles.headingM.copyWith(
                            color: score >= 70 ? AppColors.successGreen : AppColors.warningAmber,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          style: AppTextStyles.bodyM.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Party Popper Emoji Icon (Top-Right)
          const Positioned(
            top: 4,
            right: 4,
            child: Text(
              '🎉',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary(SessionResult? result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Performance Summary', style: AppTextStyles.headingM),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Filler Words',
                targetValue: result?.fillerWordCount ?? 5,
                suffix: '',
                status: (result?.fillerWordCount ?? 5) <= 5 ? 'Great' : 'Needs Work',
                delayMs: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Speaking Speed',
                targetValue: result?.wpm.round() ?? 118,
                suffix: ' WPM',
                status: (() {
                  final w = result?.wpm ?? 118;
                  return w >= 120 && w <= 160 ? 'Optimal' : 'Adjust';
                })(),
                delayMs: 100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Pauses',
                targetValue: result?.pauseCount ?? 6,
                suffix: '',
                status: 'Good',
                delayMs: 200,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Clarity',
                targetValue: result?.clarityScore.round() ?? 85,
                suffix: '%',
                status: (result?.clarityScore ?? 85) >= 80 ? 'Great' : 'Good',
                delayMs: 300,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountUpStatCard({
    required String label,
    required int targetValue,
    required String suffix,
    required String status,
    required int delayMs,
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
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return Text(
                '${val.round()}$suffix',
                style: AppTextStyles.headingXL.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.successGreen,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Session Comparison', style: AppTextStyles.headingM),
            Row(
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
          ],
        ),
        const SizedBox(height: 12),

        // fl_chart LineChart Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    final progress = _chartAnimation.value;

                    // Data points: Mon..Sun
                    final youData = [65.0, 72.0, 78.0, 75.0, 80.0, 82.0, 85.0];
                    final lastWeekData = [58.0, 62.0, 68.0, 66.0, 70.0, 72.0, 75.0];

                    return LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 25,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppColors.divider.withValues(alpha: 0.7),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 25,
                              getTitlesWidget: (val, meta) {
                                return Text(
                                  '${val.toInt()}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                final idx = val.toInt();
                                if (idx >= 0 && idx < days.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      days[idx],
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // Line 1: "You"
                          LineChartBarData(
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: AppColors.primaryPurple,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.primaryPurple,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white,
                              ),
                            ),
                            spots: List.generate(youData.length, (i) {
                              return FlSpot(i.toDouble(), youData[i] * progress);
                            }),
                          ),

                          // Line 2: "Last Week" (Dashed Muted Gray)
                          LineChartBarData(
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: AppColors.textSecondary.withValues(alpha: 0.45),
                            barWidth: 2,
                            dashArray: [5, 5],
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                radius: 3,
                                color: AppColors.textSecondary.withValues(alpha: 0.6),
                                strokeWidth: 1,
                                strokeColor: Colors.white,
                              ),
                            ),
                            spots: List.generate(lastWeekData.length, (i) {
                              return FlSpot(i.toDouble(), lastWeekData[i] * progress);
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('You', AppColors.primaryPurple),
                  const SizedBox(width: 24),
                  _buildLegendItem('Last Week', AppColors.textSecondary.withValues(alpha: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsSection(SessionResult? result) {
    // Use AI feedback if available, otherwise fall back to static suggestions
    final hasRealFeedback = result != null && result.aiFeedback.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Suggestions', style: AppTextStyles.headingM),
        const SizedBox(height: 12),
        Container(
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
            children: hasRealFeedback
                ? result.aiFeedback.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        if (idx > 0) const Divider(height: 1),
                        _buildSuggestionRow(
                          icon: _iconForCategory(item.category),
                          iconColor: _colorForSeverity(item.severity),
                          text: item.example != null
                              ? '${item.message}  "${item.example!}"'
                              : item.message,
                        ),
                      ],
                    );
                  }).toList()
                : [
                    _buildSuggestionRow(
                      icon: Icons.lightbulb_outline_rounded,
                      iconColor: AppColors.warningAmber,
                      text: 'Try reducing filler words like "um", "like".',
                    ),
                    const Divider(height: 1),
                    _buildSuggestionRow(
                      icon: Icons.access_time_rounded,
                      iconColor: AppColors.accentBlue,
                      text: 'Pause a bit more for emphasis.',
                    ),
                    const Divider(height: 1),
                    _buildSuggestionRow(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.successGreen,
                      text: 'Great pace! Maintain consistency.',
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'filler_words': return Icons.record_voice_over_rounded;
      case 'pacing': return Icons.speed_rounded;
      case 'structure': return Icons.list_alt_rounded;
      case 'confidence': return Icons.emoji_emotions_rounded;
      default: return Icons.lightbulb_outline_rounded;
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'positive': return AppColors.successGreen;
      case 'warning': return AppColors.warningAmber;
      default: return AppColors.accentBlue;
    }
  }

  Widget _buildSuggestionRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


