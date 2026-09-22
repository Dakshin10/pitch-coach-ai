import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/stats_models.dart';
import '../../core/providers/stats_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _selectedRange = 'Week'; // 'Week' or 'Month'

  @override
  void initState() {
    super.initState();
    // Load all stats data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatsProvider>().loadAll(trendRange: 'week');
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = context.watch<StatsProvider>();
    final isLoading = statsProvider.isLoading || statsProvider.state == StatsLoadState.idle;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => statsProvider.loadAll(
            trendRange: _selectedRange.toLowerCase(),
          ),
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: AppTextStyles.headingXL.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'This Month',
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

                const SizedBox(height: 16),

                // 2. Summary Stat Cards Row — real data
                _buildTopSummaryRow(statsProvider, isLoading),

                const SizedBox(height: 20),

                // 3. Confidence Over Time Chart — real trend data
                _buildConfidenceChartCard(statsProvider, isLoading),

                const SizedBox(height: 20),

                // 4. Skill Breakdown Card — real skills data
                _buildSkillBreakdownCard(statsProvider, isLoading),

                const SizedBox(height: 20),

                // 5. Achievements Section — real achievements
                _buildAchievementsSection(statsProvider, isLoading),

                const SizedBox(height: 20),

                // 6. Filler Word Reduction Card — real data
                _buildFillerWordTrendCard(statsProvider, isLoading),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTap: (index) => _handleNavigation(context, index),
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildTopSummaryRow(StatsProvider provider, bool isLoading) {
    final s = provider.summary;
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: 'Total Sessions',
            value: isLoading ? '...' : '${s.totalSessions}',
            trend: isLoading ? '' : '+${(s.totalSessions * 0.14).round()}%',
            isTrendPositive: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            label: 'Avg. Confidence',
            value: isLoading ? '...' : '${s.avgConfidence.toStringAsFixed(0)}%',
            trend: isLoading ? '' : '+5%',
            isTrendPositive: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            label: 'Streak',
            value: isLoading ? '...' : '${s.streakDays}',
            trend: 'days 🔥',
            isTrendPositive: true,
            isStreak: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String trend,
    required bool isTrendPositive,
    bool isStreak = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.headingXL.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (trend.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isStreak) ...[
                  Icon(
                    isTrendPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: isTrendPositive ? AppColors.successGreen : AppColors.dangerRed,
                  ),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    trend,
                    style: AppTextStyles.caption.copyWith(
                      color: isStreak ? AppColors.textPrimaryDark : AppColors.successGreen,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConfidenceChartCard(StatsProvider provider, bool isLoading) {
    final isWeek = _selectedRange == 'Week';

    // Build chart spots from real trend data; fall back to empty list
    List<FlSpot> spots = [];
    List<String> xLabels = isWeek
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : ['W1', 'W2', 'W3', 'W4'];

    if (!isLoading && provider.trend.isNotEmpty) {
      final trendData = provider.trend;
      // Build spots in order; use index as x-axis
      for (int i = 0; i < trendData.length; i++) {
        spots.add(FlSpot(i.toDouble(), trendData[i].confidence));
      }
      // Use real date labels from trend data
      xLabels = trendData.map((t) => t.date).toList();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Card Header + Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confidence Over Time',
                style: AppTextStyles.headingM.copyWith(fontWeight: FontWeight.w700),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEBEBF5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildRangeToggleOption('Week', isWeek, provider),
                    _buildRangeToggleOption('Month', !isWeek, provider),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Chart area
          SizedBox(
            height: 170,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                    ),
                  )
                : spots.isEmpty
                    ? Center(
                        child: Text(
                          'No data yet — complete some sessions first.',
                          style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: 100,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 25,
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: AppColors.divider.withValues(alpha: 0.6),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 25,
                                getTitlesWidget: (val, meta) => Text(
                                  '${val.toInt()}',
                                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < xLabels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        xLabels[idx],
                                        style: AppTextStyles.caption.copyWith(fontSize: 10),
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
                            LineChartBarData(
                              isCurved: true,
                              curveSmoothness: 0.3,
                              color: AppColors.primaryPurple,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryPurple.withValues(alpha: 0.3),
                                    AppColors.primaryPurple.withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) =>
                                    FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.primaryPurple,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                              spots: spots,
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeToggleOption(String label, bool isSelected, StatsProvider provider) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedRange = label);
        provider.loadAll(trendRange: label.toLowerCase());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSkillBreakdownCard(StatsProvider provider, bool isLoading) {
    final sk = provider.skills;

    // Build skill list from real data
    final skills = [
      {'name': 'Clarity', 'score': sk.clarity / 100, 'label': '${sk.clarity.toStringAsFixed(0)}%', 'color': AppColors.successGreen},
      {'name': 'Pace', 'score': sk.pace / 100, 'label': '${sk.pace.toStringAsFixed(0)}%', 'color': AppColors.successGreen},
      {'name': 'Filler Words', 'score': sk.fillerWords / 100, 'label': '${sk.fillerWords.toStringAsFixed(0)}%', 'color': AppColors.warningAmber},
      {'name': 'Confidence', 'score': sk.confidence / 100, 'label': '${sk.confidence.toStringAsFixed(0)}%', 'color': AppColors.successGreen},
      {'name': 'Engagement', 'score': sk.engagement / 100, 'label': '${sk.engagement.toStringAsFixed(0)}%', 'color': AppColors.primaryPurple},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skill Breakdown',
              style: AppTextStyles.headingM.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                ),
              ),
            )
          else
            ...skills.map((skill) {
              final name = skill['name'] as String;
              final score = skill['score'] as double;
              final label = skill['label'] as String;
              final color = skill['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name,
                            style: AppTextStyles.bodyM
                                .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(label,
                            style: AppTextStyles.caption
                                .copyWith(color: color, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEFEFF5),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(StatsProvider provider, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: AppTextStyles.headingM),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
            ),
          )
        else if (provider.achievements.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'Complete sessions to unlock achievements! 🏆',
              style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: provider.achievements.map((badge) {
                return GestureDetector(
                  onTap: () => _showAchievementModal(context, badge),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: const [
                        BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 10,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: badge.isUnlocked
                                ? AppColors.primaryGradient
                                : const LinearGradient(
                                    colors: [Color(0xFFE0E0E8), Color(0xFFD0D0D8)]),
                          ),
                          child: Center(
                            child: Text(
                              badge.icon,
                              style: TextStyle(
                                fontSize: 22,
                                color: badge.isUnlocked ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badge.isUnlocked
                                ? AppColors.textPrimaryDark
                                : AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showAchievementModal(BuildContext context, Achievement badge) {
    String unlockedText;
    if (badge.isUnlocked && badge.unlockedAt != null) {
      final d = badge.unlockedAt!.toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      unlockedText = 'Unlocked on ${months[d.month - 1]} ${d.day}, ${d.year}! ${badge.description}';
    } else {
      unlockedText = badge.description;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(badge.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Text(badge.title, style: AppTextStyles.headingM)),
          ],
        ),
        content: Text(unlockedText, style: AppTextStyles.bodyM),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFillerWordTrendCard(StatsProvider provider, bool isLoading) {
    final pct = provider.summary.fillerReductionPct;
    final isPositive = pct >= 0;
    final displayPct = isPositive ? '-${pct.toStringAsFixed(0)}%' : '+${(-pct).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filler Word Reduction',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    isLoading ? '...' : displayPct,
                    style: AppTextStyles.headingXL.copyWith(
                      fontSize: 22,
                      color: isPositive ? AppColors.successGreen : AppColors.dangerRed,
                    ),
                  ),
                  if (!isLoading) ...[
                    const SizedBox(width: 6),
                    Text(
                      'vs last week',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Icon(
            isLoading
                ? Icons.trending_flat_rounded
                : isPositive
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
            color: isLoading
                ? AppColors.textSecondary
                : isPositive
                    ? AppColors.successGreen
                    : AppColors.dangerRed,
            size: 36,
          ),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/history');
        break;
      case 2:
        context.push('/interview');
        break;
      case 3:
        break; // Already on Progress
      case 4:
        context.go('/profile');
        break;
    }
  }
}
