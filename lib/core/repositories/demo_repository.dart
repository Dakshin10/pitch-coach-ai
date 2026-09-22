import '../models/session_result.dart';
import '../models/stats_models.dart';

/// Isolated, local-only data source for Guest Mode. It never uses ApiClient.
class DemoRepository {
  DemoRepository._();
  static final instance = DemoRepository._();

  SessionResult get result => SessionResult(
        id: 'demo-session', mode: 'interview',
        topicOrQuestion: 'Tell me about yourself.', durationSeconds: 95,
        transcript: 'I am excited to introduce myself and share my experience.',
        wpm: 128, fillerWordCount: 3, fillerWordBreakdown: const {'um': 2, 'like': 1},
        pauseCount: 4, avgPauseLength: 0.8, clarityScore: 81, confidenceScore: 82,
        overallScore: 82,
        aiFeedback: const [
          FeedbackItem(category: 'pacing', message: 'Your pace was clear and easy to follow.', severity: 'positive'),
          FeedbackItem(category: 'filler_words', message: 'Try replacing filler words with a short pause.', severity: 'tip'),
        ],
        createdAt: DateTime.now(), isAnalyzed: true,
      );

  List<SessionSummary> get sessions => [
        SessionSummary(id: result.id, mode: result.mode, topicOrQuestion: result.topicOrQuestion,
          durationSeconds: result.durationSeconds, overallScore: result.overallScore,
          confidenceScore: result.confidenceScore, createdAt: result.createdAt, isAnalyzed: true),
      ];

  StatsSummary get summary => const StatsSummary(
      totalSessions: 5, avgConfidence: 82, streakDays: 3, fillerReductionPct: 18);
  List<TrendPoint> get trend => const [
    TrendPoint(date: 'Mon', confidence: 72), TrendPoint(date: 'Wed', confidence: 78),
    TrendPoint(date: 'Fri', confidence: 82),
  ];
  SkillBreakdown get skills => const SkillBreakdown(
    clarity: 81, pace: 78, fillerWords: 76, confidence: 82, engagement: 80);
}
