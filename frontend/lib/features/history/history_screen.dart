import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/demo_repository.dart';
import '../../core/models/session_result.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/circular_gauge_painter.dart';
import '../../core/widgets/theme_toggle_button.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchQuery = '';
  DateTime? _selectedDate; // DatePicker filter (Unit 2)

  // Real data from API
  List<SessionSummary> _sessions = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _filterChips = ['All', 'Interview', 'Presentation', 'Free Talk'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final cached = SessionRepository.instance.cachedSessions;
    if (cached != null && cached.isNotEmpty) {
      _sessions = cached;
      _isLoading = false;
    }
    _loadSessions(isInitial: cached == null || cached.isEmpty);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({bool isInitial = false, bool force = false}) async {
    if (isInitial && _sessions.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      if (context.read<UserProvider>().isGuest) {
        if (mounted) setState(() => _sessions = DemoRepository.instance.sessions);
        return;
      }
      // Map filter chip → API mode value
      final modeParam = _selectedFilter == 'All'
          ? null
          : _selectedFilter == 'Interview'
              ? 'interview'
              : _selectedFilter == 'Presentation'
                  ? 'presentation'
                  : 'free_talk';

      final sessions = await SessionRepository.instance.listSessions(
        mode: modeParam,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        limit: 50,
        forceRefresh: force,
      );

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted && _sessions.isEmpty) {
        setState(() => _errorMessage = 'Could not load sessions. Pull to retry.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Group sessions by relative date label ("Today", "Yesterday", "This Week", older date strings).
  Map<String, List<SessionSummary>> get _groupedSessions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<SessionSummary>> groups = {};

    for (final s in _sessions) {
      final d = s.createdAt.toLocal();
      final sessionDay = DateTime(d.year, d.month, d.day);

      String label;
      if (sessionDay == today) {
        label = 'Today';
      } else if (sessionDay == yesterday) {
        label = 'Yesterday';
      } else if (sessionDay.isAfter(weekAgo)) {
        label = 'This Week';
      } else {
        label = s.dateFormatted; // e.g. "Mon, Sep 15"
      }

      groups.putIfAbsent(label, () => []).add(s);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  // Theme Toggle & DatePicker filter button (Unit 2)
                  Row(
                    children: [
                      const ThemeToggleButton(size: 38, compact: true),
                      const SizedBox(width: 8),
                      if (_selectedDate != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedDate = null);
                            _loadSessions();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Clear',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _selectedDate != null
                                ? AppColors.primaryPurple
                                : AppColors.cardOf(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderOf(context)),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                            color: _selectedDate != null
                                ? Colors.white
                                : AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Search Bar
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderOf(context)),
                  boxShadow: AppColors.softShadowOf(context),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  onSubmitted: (_) => _loadSessions(),
                  style: AppTextStyles.bodyM.copyWith(color: AppColors.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    hintText: 'Search sessions...',
                    hintStyle: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textSecondaryOf(context).withValues(alpha: 0.7),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondaryOf(context),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadSessions();
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
                        backgroundColor: AppColors.cardOf(context),
                        labelStyle: AppTextStyles.caption.copyWith(
                          color: isSelected ? Colors.white : AppColors.textPrimaryOf(context),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryPurple : AppColors.borderOf(context),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = chip);
                            _loadSessions();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Session List / Loading / Error / Empty State
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                        ),
                      )
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _sessions.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: () => _loadSessions(force: true),
                                color: AppColors.primaryPurple,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: _groupedSessions.keys.length,
                                  itemBuilder: (context, index) {
                                    final groupKey =
                                        _groupedSessions.keys.elementAt(index);
                                    final sessionsInGroup =
                                        _groupedSessions[groupKey]!;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Text(
                                            groupKey,
                                            style: AppTextStyles.headingMOf(context).copyWith(
                                              fontSize: 15,
                                              color: AppColors.textSecondaryOf(context),
                                            ),
                                          ),
                                        ),
                                        ...sessionsInGroup.map(
                                          (s) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12.0),
                                            child: _buildSessionCard(context, s),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SessionSummary session) {
    final score = session.overallScore;
    final scoreColor = score >= 80
        ? AppColors.successGreen
        : score >= 60
            ? AppColors.warningAmber
            : AppColors.dangerRed;

    final icon = session.mode == 'presentation'
        ? Icons.bar_chart_rounded
        : session.mode == 'free_talk'
            ? Icons.mic_rounded
            : Icons.event_seat_rounded;
    final iconBg = session.mode == 'presentation'
        ? AppColors.accentBlue
        : session.mode == 'free_talk'
            ? AppColors.accentGreen
            : AppColors.primaryPurple;

    return InkWell(
      onTap: () => context.push('/results', extra: session.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: AppColors.softShadowOf(context),
        ),
          // Use ListTile for session cards (Unit 1)
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconBg, size: 24),
            ),
            title: Text(
              session.topicOrQuestion,
              style: AppTextStyles.headingMOf(context).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  session.modeLabel,
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
                  '${session.createdAt.toLocal().minute.toString().padLeft(2, '0')}'
                  ' · ${session.durationFormatted}',
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.textSecondaryOf(context).withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            trailing: session.analysisFailed
                ? const Tooltip(
                    message: 'Analysis failed — tap to retry',
                    child: Icon(Icons.error_outline_rounded,
                        color: AppColors.warningAmber, size: 30),
                  )
                : CircularGauge(
                    value: score,
                    size: 46,
                    strokeWidth: 4.5,
                    centerBigText: '${score.round()}%',
                    gradientColors: [scoreColor, scoreColor],
                  ),
            isThreeLine: true,
          ),
        ),
      );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image.asset illustration (Unit 1)
          Image.asset(
            'assets/images/empty_history.png',
            height: 160,
            errorBuilder: (_, _, _) => Container(
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
          ),
          const SizedBox(height: 16),
          Text('No sessions found', style: AppTextStyles.headingLOf(context)),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery". Try a different search.'
                : _selectedDate != null
                    ? 'No sessions on the selected date.'
                    : 'Start practicing to build your session history.',
            style: AppTextStyles.bodyMOf(context).copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondaryOf(context)),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Something went wrong.', style: AppTextStyles.bodyMOf(context), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSessions,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }


  /// Show the DatePicker and reload sessions filtered to that date (Unit 2).
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primaryPurple,
                    onPrimary: Colors.white,
                    surface: AppColors.cardDark,
                    onSurface: AppColors.textOnDark,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primaryPurple,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.textPrimaryDark,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSessions();
    }
  }
}
