import '../models/session_result.dart';
import '../models/stats_models.dart';

/// Isolated, local-only data source for Guest Mode. It never uses ApiClient.
class DemoRepository {
  DemoRepository._();
  static final instance = DemoRepository._();

  SessionResult get result => SessionResult(
    id: 'demo-session',
    mode: 'interview',
    topicOrQuestion: 'Tell me about yourself.',
    durationSeconds: 95,
    transcript:
        'I am excited to introduce myself, um, and share my experience with, like, software engineering.',
    wordTimestamps: const [
      WordTimestamp(word: 'I', start: 0.2, end: 0.4),
      WordTimestamp(word: 'am', start: 0.45, end: 0.6),
      WordTimestamp(word: 'excited', start: 0.65, end: 1.1),
      WordTimestamp(word: 'to', start: 1.15, end: 1.3),
      WordTimestamp(word: 'introduce', start: 1.35, end: 1.8),
      WordTimestamp(word: 'myself,', start: 1.85, end: 2.3),
      WordTimestamp(word: 'um,', start: 2.5, end: 2.9),
      WordTimestamp(word: 'and', start: 3.1, end: 3.3),
      WordTimestamp(word: 'share', start: 3.35, end: 3.7),
      WordTimestamp(word: 'my', start: 3.75, end: 3.9),
      WordTimestamp(word: 'experience', start: 3.95, end: 4.5),
      WordTimestamp(word: 'with,', start: 4.55, end: 4.8),
      WordTimestamp(word: 'like,', start: 5.0, end: 5.3),
      WordTimestamp(word: 'software', start: 5.4, end: 5.8),
      WordTimestamp(word: 'engineering.', start: 5.85, end: 6.4),
    ],
    wpm: 128,
    fillerWordCount: 3,
    fillerWordBreakdown: const {'um': 2, 'like': 1},
    pauseCount: 4,
    avgPauseLength: 0.8,
    clarityScore: 81,
    confidenceScore: 82,
    overallScore: 82,
    aiFeedback: const [
      FeedbackItem(
        category: 'pacing',
        message: 'Your pace was clear and easy to follow.',
        severity: 'positive',
      ),
      FeedbackItem(
        category: 'filler_words',
        message: 'Try replacing filler words with a short pause.',
        severity: 'tip',
      ),
    ],
    createdAt: DateTime.now(),
    isAnalyzed: true,
  );

  List<SessionSummary> get sessions => [
    SessionSummary(
      id: result.id,
      mode: result.mode,
      topicOrQuestion: result.topicOrQuestion,
      durationSeconds: result.durationSeconds,
      overallScore: result.overallScore,
      confidenceScore: result.confidenceScore,
      createdAt: result.createdAt,
      isAnalyzed: true,
    ),
  ];

  StatsSummary get summary => const StatsSummary(
    totalSessions: 5,
    avgConfidence: 82,
    streakDays: 3,
    fillerReductionPct: 18,
  );
  List<TrendPoint> get trend => const [
    TrendPoint(date: 'Mon', confidence: 72),
    TrendPoint(date: 'Wed', confidence: 78),
    TrendPoint(date: 'Fri', confidence: 82),
  ];
  SkillBreakdown get skills => const SkillBreakdown(
    clarity: 81,
    pace: 78,
    fillerWords: 76,
    confidence: 82,
    engagement: 80,
  );
}
