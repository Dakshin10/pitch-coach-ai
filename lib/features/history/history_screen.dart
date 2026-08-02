import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/circular_gauge_painter.dart';

class SessionItemData {
  final String title;
  final String mode;
  final String time;
  final String duration;
  final int score;
  final IconData icon;
  final Color iconBgColor;
  final String dateGroup;

  const SessionItemData({
    required this.title,
    required this.mode,
    required this.time,
    required this.duration,
    required this.score,
    required this.icon,
    required this.iconBgColor,
    required this.dateGroup,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filterChips = [
    'All',
    'Interview',
    'Presentation',
    'Free Talk',
  ];

  static const List<SessionItemData> _allSessions = [
    SessionItemData(
      title: 'Backend Developer – Q&A',
      mode: 'Interview Practice',
      time: '10:30 AM',
      duration: '3 min',
      score: 82,
      icon: Icons.event_seat_rounded,
      iconBgColor: AppColors.primaryPurple,
      dateGroup: 'Today',
    ),
    SessionItemData(
      title: 'System Design Mock',
      mode: 'Interview Practice',
      time: '04:15 PM',
      duration: '5 min',
      score: 76,
      icon: Icons.event_seat_rounded,
      iconBgColor: AppColors.primaryPurple,
      dateGroup: 'Today',
    ),
    SessionItemData(
      title: 'Startup Pitch Deck',
      mode: 'Presentation Practice',
      time: '02:00 PM',
      duration: '8 min',
      score: 91,
      icon: Icons.bar_chart_rounded,
      iconBgColor: AppColors.accentBlue,
      dateGroup: 'Yesterday',
    ),
    SessionItemData(
      title: 'Impromptu Tech Trends',
      mode: 'Free Talk',
      time: '11:45 AM',
      duration: '4 min',
      score: 64,
      icon: Icons.mic_rounded,
      iconBgColor: AppColors.accentGreen,
      dateGroup: 'Yesterday',
    ),
    SessionItemData(
      title: 'HR Cultural Fit Interview',
      mode: 'Interview Practice',
      time: '05:30 PM',
      duration: '6 min',
      score: 88,
      icon: Icons.event_seat_rounded,
      iconBgColor: AppColors.primaryPurple,
      dateGroup: 'This Week',
    ),
    SessionItemData(
      title: 'Keynote Demo Speech',
      mode: 'Presentation Practice',
      time: '09:15 AM',
      duration: '10 min',
      score: 85,
      icon: Icons.bar_chart_rounded,
      iconBgColor: AppColors.accentBlue,
      dateGroup: 'This Week',
    ),
  ];

  List<SessionItemData> get _filteredSessions {
    return _allSessions.where((session) {
      final matchesFilter = _selectedFilter == 'All' ||
          session.mode.toLowerCase().contains(_selectedFilter.toLowerCase());
      final matchesSearch = _searchQuery.isEmpty ||
          session.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.mode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredSessions;

    // Group filtered items by dateGroup
    final Map<String, List<SessionItemData>> groupedSessions = {};
    for (var session in filteredList) {
      groupedSessions.putIfAbsent(session.dateGroup, () => []).add(session);
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'History',
                    style: AppTextStyles.headingXL.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Search Bar
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: AppTextStyles.bodyM.copyWith(color: AppColors.textPrimaryDark),
                  decoration: InputDecoration(
                    hintText: 'Search sessions...',
                    hintStyle: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterChips.map((chip) {
                    final isSelected = _selectedFilter == chip;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(chip),
                        selected: isSelected,
                        selectedColor: AppColors.primaryPurple,
                        backgroundColor: Colors.white,
                        labelStyle: AppTextStyles.caption.copyWith(
                          color: isSelected ? Colors.white : AppColors.textPrimaryDark,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryPurple : AppColors.divider,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedFilter = chip;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Session List or Empty State
              Expanded(
                child: filteredList.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: groupedSessions.keys.length,
                        itemBuilder: (context, index) {
                          final groupKey = groupedSessions.keys.elementAt(index);
                          final sessionsInGroup = groupedSessions[groupKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  groupKey,
                                  style: AppTextStyles.headingM.copyWith(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              ...sessionsInGroup.map(
                                (session) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildSessionCard(context, session),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // History active
        onTap: (index) => _handleNavigation(context, index),
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SessionItemData session) {
    Color scoreColor;
    if (session.score >= 80) {
      scoreColor = AppColors.successGreen;
    } else if (session.score >= 60) {
      scoreColor = AppColors.warningAmber;
    } else {
      scoreColor = AppColors.dangerRed;
    }

    return GestureDetector(
      onTap: () => context.push('/results'),
      child: Container(
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
          children: [
            // Mode Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: session.iconBgColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                session.icon,
                color: session.iconBgColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Session Info Stack
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: AppTextStyles.headingM.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.mode,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.time} · ${session.duration}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Score Circular Gauge Ring
            CircularGauge(
              value: session.score.toDouble(),
              size: 46,
              strokeWidth: 4.5,
              centerBigText: '${session.score}%',
              gradientColors: [scoreColor, scoreColor],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              size: 54,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No sessions found',
            style: AppTextStyles.headingL,
          ),
          const SizedBox(height: 8),
          Text(
            'Try clearing your search query or practice a new session.',
            style: AppTextStyles.bodyM,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/interview'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Practicing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
        // Already on History
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
  }
}
