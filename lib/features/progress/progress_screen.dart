import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';

class AchievementBadgeData {
  final String title;
  final String icon;
  final bool isUnlocked;
  final String description;

  const AchievementBadgeData({
    required this.title,
    required this.icon,
    required this.isUnlocked,
    required this.description,
  });
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _selectedRange = 'Week'; // 'Week' or 'Month'

  final List<AchievementBadgeData> _achievements = const [
    AchievementBadgeData(
      title: '7-Day Streak',
      icon: '🔥',
      isUnlocked: true,
      description: 'Unlocked on Jan 28, 2025! Practiced 7 days in a row.',
    ),
    AchievementBadgeData(
      title: '50 Sessions',
      icon: '🎯',
      isUnlocked: false,
      description: 'Locked — 42/50 sessions completed. 8 more to go!',
    ),
    AchievementBadgeData(
      title: 'Clarity Master',
      icon: '💎',
      isUnlocked: true,
      description: 'Unlocked on Jan 15, 2025! Achieved >85% clarity score.',
    ),
    AchievementBadgeData(
      title: 'Early Bird',
      icon: '🌅',
      isUnlocked: true,
      description: 'Unlocked on Jan 10, 2025! Practiced before 8:00 AM.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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

              // 2. Summary Stat Cards Row
              _buildTopSummaryRow(),

              const SizedBox(height: 20),

              // 3. Confidence Over Time Line/Area Chart Card
              _buildConfidenceChartCard(),

              const SizedBox(height: 20),

              // 4. Skill Breakdown Card
              _buildSkillBreakdownCard(),

              const SizedBox(height: 20),

              // 5. Achievements Section
              _buildAchievementsSection(),

              const SizedBox(height: 20),

              // 6. Filler Word Trend Mini Card
              _buildFillerWordTrendCard(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3, // Progress active
        onTap: (index) => _handleNavigation(context, index),
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildTopSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: 'Total Sessions',
            value: '42',
            trend: '+14%',
            isTrendPositive: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            label: 'Avg. Confidence',
            value: '78%',
            trend: '+5%',
            isTrendPositive: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            label: 'Streak',
            value: '5',
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
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isStreak) ...[
                Icon(
                  isTrendPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 12,
                  color: isTrendPositive ? AppColors.successGreen : AppColors.dangerRed,
                ),
                const SizedBox(width: 2),
              ],
              Text(
                trend,
                style: AppTextStyles.caption.copyWith(
                  color: isStreak ? AppColors.textPrimaryDark : AppColors.successGreen,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceChartCard() {
    final isWeek = _selectedRange == 'Week';
    final xLabels = isWeek
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : ['W1', 'W2', 'W3', 'W4'];
    final spots = isWeek
        ? const [
            FlSpot(0, 68),
            FlSpot(1, 72),
            FlSpot(2, 75),
            FlSpot(3, 71),
            FlSpot(4, 79),
            FlSpot(5, 82),
            FlSpot(6, 85),
          ]
        : const [
            FlSpot(0, 65),
            FlSpot(1, 74),
            FlSpot(2, 79),
            FlSpot(3, 85),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header + Toggle Switch
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
                    _buildRangeToggleOption('Week', isWeek),
                    _buildRangeToggleOption('Month', !isWeek),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Area Line Chart
          SizedBox(
            height: 170,
            child: LineChart(
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
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
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

  Widget _buildRangeToggleOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = label),
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

  Widget _buildSkillBreakdownCard() {
    final skills = [
      {'name': 'Clarity', 'score': 0.85, 'label': '85%', 'color': AppColors.successGreen},
      {'name': 'Pace', 'score': 0.78, 'label': '78%', 'color': AppColors.successGreen},
      {'name': 'Filler Words', 'score': 0.64, 'label': '64%', 'color': AppColors.warningAmber},
      {'name': 'Confidence', 'score': 0.82, 'label': '82%', 'color': AppColors.successGreen},
      {'name': 'Engagement', 'score': 0.75, 'label': '75%', 'color': AppColors.primaryPurple},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skill Breakdown', style: AppTextStyles.headingM.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
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
                      Text(name, style: AppTextStyles.bodyM.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score,
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

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: AppTextStyles.headingM),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _achievements.map((badge) {
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
                        offset: Offset(0, 3),
                      ),
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
                              : const LinearGradient(colors: [Color(0xFFE0E0E8), Color(0xFFD0D0D8)]),
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
                          color: badge.isUnlocked ? AppColors.textPrimaryDark : AppColors.textSecondary,
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

  void _showAchievementModal(BuildContext context, AchievementBadgeData badge) {
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
        content: Text(badge.description, style: AppTextStyles.bodyM),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFillerWordTrendCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
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
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '-34%',
                    style: AppTextStyles.headingXL.copyWith(fontSize: 22, color: AppColors.successGreen),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'vs last month',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Icon(
            Icons.trending_down_rounded,
            color: AppColors.successGreen,
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
        // Already on Progress
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }
}
