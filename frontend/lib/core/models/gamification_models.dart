/// Data models for Feature 11: Weekly Challenges and Privacy-Preserving Leaderboard.
library;

class WeeklyChallenge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int currentProgress;
  final int target;
  final bool isCompleted;
  final bool isClaimed;
  final int rewardPoints;

  const WeeklyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.currentProgress,
    required this.target,
    required this.isCompleted,
    required this.isClaimed,
    required this.rewardPoints,
  });

  factory WeeklyChallenge.fromJson(Map<String, dynamic> j) => WeeklyChallenge(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    icon: j['icon'] as String? ?? 'flag',
    currentProgress: (j['current_progress'] as num?)?.toInt() ?? 0,
    target: (j['target'] as num?)?.toInt() ?? 1,
    isCompleted: j['is_completed'] as bool? ?? false,
    isClaimed: j['is_claimed'] as bool? ?? false,
    rewardPoints: (j['reward_points'] as num?)?.toInt() ?? 0,
  );

  WeeklyChallenge copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? currentProgress,
    int? target,
    bool? isCompleted,
    bool? isClaimed,
    int? rewardPoints,
  }) {
    return WeeklyChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      currentProgress: currentProgress ?? this.currentProgress,
      target: target ?? this.target,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
      rewardPoints: rewardPoints ?? this.rewardPoints,
    );
  }
}

class LeaderboardEntry {
  final int? rank;
  final String displayName;
  final double score;
  final int sessionsCount;
  final bool isCurrentUser;

  const LeaderboardEntry({
    this.rank,
    required this.displayName,
    required this.score,
    required this.sessionsCount,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    rank: (j['rank'] as num?)?.toInt(),
    displayName: j['display_name'] as String? ?? 'Anonymous Speaker',
    score: (j['score'] as num?)?.toDouble() ?? 0.0,
    sessionsCount: (j['sessions_count'] as num?)?.toInt() ?? 0,
    isCurrentUser: j['is_current_user'] as bool? ?? false,
  );
}

class LeaderboardResponse {
  final String weekId;
  final String weekStart;
  final bool userOptedIn;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry currentUserEntry;

  const LeaderboardResponse({
    required this.weekId,
    required this.weekStart,
    required this.userOptedIn,
    required this.entries,
    required this.currentUserEntry,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> j) =>
      LeaderboardResponse(
        weekId: j['week_id'] as String? ?? '',
        weekStart: j['week_start'] as String? ?? '',
        userOptedIn: j['user_opted_in'] as bool? ?? false,
        entries: (j['entries'] as List<dynamic>? ?? [])
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentUserEntry: j['current_user_entry'] != null
            ? LeaderboardEntry.fromJson(
                j['current_user_entry'] as Map<String, dynamic>,
              )
            : const LeaderboardEntry(
                displayName: 'Anonymous Speaker',
                score: 0.0,
                sessionsCount: 0,
                isCurrentUser: true,
              ),
      );

  static const LeaderboardResponse empty = LeaderboardResponse(
    weekId: '',
    weekStart: '',
    userOptedIn: false,
    entries: [],
    currentUserEntry: LeaderboardEntry(
      displayName: 'Anonymous Speaker',
      score: 0.0,
      sessionsCount: 0,
      isCurrentUser: true,
    ),
  );
}

class ClaimChallengeResult {
  final bool success;
  final String challengeId;
  final int rewardPoints;
  final int totalClaimedPoints;
  final String message;

  const ClaimChallengeResult({
    required this.success,
    required this.challengeId,
    required this.rewardPoints,
    required this.totalClaimedPoints,
    required this.message,
  });

  factory ClaimChallengeResult.fromJson(Map<String, dynamic> j) =>
      ClaimChallengeResult(
        success: j['success'] as bool? ?? false,
        challengeId: j['challenge_id'] as String? ?? '',
        rewardPoints: (j['reward_points'] as num?)?.toInt() ?? 0,
        totalClaimedPoints: (j['total_claimed_points'] as num?)?.toInt() ?? 0,
        message: j['message'] as String? ?? '',
      );
}
