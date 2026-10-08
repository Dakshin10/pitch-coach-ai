import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/config/app_config.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/providers/session_results_provider.dart';

void main() {
  group('Phase 4 Frontend Configuration & Models', () {
    test('AppConfig resolves valid base URL', () {
      final url = AppConfig.apiBaseUrl;
      expect(url, isNotEmpty);
      expect(url.startsWith('http'), isTrue);
      expect(AppConfig.resultsPollInitialInterval, const Duration(seconds: 2));
      expect(AppConfig.resultsPollMaxInterval, const Duration(seconds: 10));
      expect(AppConfig.resultsPollTimeout, const Duration(minutes: 3));
    });

    test('SessionResult parses failureReason and analysisFailed correctly', () {
      final json = {
        'id': 'sess_1',
        'mode': 'interview',
        'topic_or_question': 'Tell me about yourself',
        'duration_seconds': 120.0,
        'wpm': 140.0,
        'filler_word_count': 3,
        'filler_word_breakdown': {'um': 3},
        'pause_count': 2,
        'avg_pause_length': 1.2,
        'clarity_score': 85.0,
        'confidence_score': 80.0,
        'overall_score': 82.5,
        'ai_feedback': [],
        'created_at': DateTime.now().toIso8601String(),
        'is_analyzed': true,
        'analysis_failed': true,
        'failure_reason': 'Processing timed out',
      };

      final result = SessionResult.fromJson(json);
      expect(result.id, 'sess_1');
      expect(result.isAnalyzed, isTrue);
      expect(result.analysisFailed, isTrue);
      expect(result.failureReason, 'Processing timed out');

      final copied = result.copyWith(failureReason: 'Resolved');
      expect(copied.failureReason, 'Resolved');
    });

    test('SessionSummary parses failureReason correctly', () {
      final json = {
        'id': 'sum_1',
        'mode': 'presentation',
        'topic_or_question': 'Investor Pitch',
        'duration_seconds': 180.0,
        'overall_score': 90.0,
        'confidence_score': 88.0,
        'created_at': DateTime.now().toIso8601String(),
        'is_analyzed': true,
        'analysis_failed': false,
        'failure_reason': null,
      };

      final summary = SessionSummary.fromJson(json);
      expect(summary.id, 'sum_1');
      expect(summary.modeLabel, 'Presentation');
      expect(summary.failureReason, isNull);
    });

    test('SessionResultsProvider initial state', () {
      final provider = SessionResultsProvider();
      expect(provider.state, ResultsLoadState.loading);
      expect(provider.result, isNull);
      expect(provider.errorMessage, isNull);
      provider.dispose();
    });
  });
}
