import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/circular_gauge_painter.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

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

    // Score ring fill (1200ms)
    _scoreGaugeAnimation = Tween<double>(begin: 0.0, end: 82.0).animate(
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

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar
            _buildTopAppBar(context),

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
                      child: _buildOverallScoreCard(),
                    ),

                    const SizedBox(height: 20),

                    // Section 1: Performance Summary Grid
                    _buildAnimatedSection(
                      animation: _card1Anim,
                      child: _buildPerformanceSummary(),
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
                      child: _buildSuggestionsSection(),
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

  Widget _buildOverallScoreCard() {
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
                          'Great Job!',
                          style: AppTextStyles.headingM.copyWith(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You spoke clearly and confidently. Keep practicing to get even better.',
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

  Widget _buildPerformanceSummary() {
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
                targetValue: 5,
                suffix: '',
                status: 'Great',
                delayMs: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Speaking Speed',
                targetValue: 118,
                suffix: ' WPM',
                status: 'Good',
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
                targetValue: 6,
                suffix: '',
                status: 'Good',
                delayMs: 200,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountUpStatCard(
                label: 'Clarity',
                targetValue: 85,
                suffix: '%',
                status: 'Great',
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

  Widget _buildSuggestionsSection() {
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
            children: [
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


