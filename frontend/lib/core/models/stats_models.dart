/// Data models for stats and achievements API responses.
library;

// ─────────────────────────────────────────────────────────────────────────────
// StatsSummary  (GET /stats/summary)
// ─────────────────────────────────────────────────────────────────────────────

class StatsSummary {
  final int totalSessions;
  final double avgConfidence;
  final int streakDays;
  final double fillerReductionPct;

  const StatsSummary({
    required this.totalSessions,
    required this.avgConfidence,
    required this.streakDays,
    required this.fillerReductionPct,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> j) => StatsSummary(
        totalSessions: (j['total_sessions'] as num?)?.toInt() ?? 0,
        avgConfidence: (j['avg_confidence'] as num?)?.toDouble() ?? 0,
        streakDays: (j['streak_days'] as num?)?.toInt() ?? 0,
        fillerReductionPct: (j['filler_reduction_pct'] as num?)?.toDouble() ?? 0,
      );

  static const StatsSummary empty = StatsSummary(
    totalSessions: 0,
    avgConfidence: 0,
    streakDays: 0,
    fillerReductionPct: 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TrendPoint  (GET /stats/trend)
// ─────────────────────────────────────────────────────────────────────────────

class TrendPoint {
  final String date;
  final double confidence;

  const TrendPoint({required this.date, required this.confidence});

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
        date: j['date'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SkillBreakdown  (GET /stats/skills)
// ─────────────────────────────────────────────────────────────────────────────

class SkillBreakdown {
  final double clarity;
  final double pace;
  final double fillerWords;
  final double confidence;
  final double engagement;

  const SkillBreakdown({
    required this.clarity,
    required this.pace,
    required this.fillerWords,
    required this.confidence,
    required this.engagement,
  });

  factory SkillBreakdown.fromJson(Map<String, dynamic> j) => SkillBreakdown(
        clarity: (j['clarity'] as num?)?.toDouble() ?? 0,
        pace: (j['pace'] as num?)?.toDouble() ?? 0,
        fillerWords: (j['filler_words'] as num?)?.toDouble() ?? 0,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        engagement: (j['engagement'] as num?)?.toDouble() ?? 0,
      );

  static const SkillBreakdown empty = SkillBreakdown(
    clarity: 0,
    pace: 0,
    fillerWords: 0,
    confidence: 0,
    engagement: 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Achievement  (GET /achievements)
// ─────────────────────────────────────────────────────────────────────────────

class Achievement {
  final String key;
  final String title;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final String description;

  const Achievement({
    required this.key,
    required this.title,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
    required this.description,
  });

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        key: j['key'] as String? ?? '',
        title: j['title'] as String? ?? '',
        icon: j['icon'] as String? ?? '🏆',
        isUnlocked: j['is_unlocked'] as bool? ?? false,
        unlockedAt: j['unlocked_at'] != null
            ? DateTime.parse(j['unlocked_at'] as String)
            : null,
        description: j['description'] as String? ?? '',
      );
}
