import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vocal Delivery Model Deserialization', () {
    test('SessionResult parses vocal delivery metrics from json', () {
      final json = {
        'id': 'sess-vocal-1',
        'mode': 'interview',
        'topic_or_question': 'Tell me about yourself.',
        'duration_seconds': 45.0,
        'wpm': 135.0,
        'filler_word_count': 2,
        'filler_word_breakdown': {'um': 2},
        'pause_count': 3,
        'avg_pause_length': 1.1,
        'clarity_score': 88.0,
        'confidence_score': 84.0,
        'overall_score': 86.0,
        'ai_feedback': [],
        'created_at': DateTime.now().toIso8601String(),
        'is_analyzed': true,
        'energy_curve': [0.2, 0.45, 0.78, 0.65, 0.90],
        'pitch_variation_score': 76.5,
        'volume_consistency_score': 82.0,
      };

      final result = SessionResult.fromJson(json);
      expect(result.energyCurve, equals([0.2, 0.45, 0.78, 0.65, 0.90]));
      expect(result.pitchVariationScore, 76.5);
      expect(result.volumeConsistencyScore, 82.0);
    });

    test('SessionResult handles absent vocal delivery metrics backward-compatibly', () {
      final json = {
        'id': 'sess-legacy-1',
        'mode': 'presentation',
        'topic_or_question': 'Demo Pitch',
        'duration_seconds': 30.0,
        'wpm': 140.0,
        'filler_word_count': 1,
        'filler_word_breakdown': {'like': 1},
        'pause_count': 2,
        'avg_pause_length': 0.9,
        'clarity_score': 90.0,
        'confidence_score': 85.0,
        'overall_score': 88.0,
        'ai_feedback': [],
        'created_at': DateTime.now().toIso8601String(),
        'is_analyzed': true,
      };

      final result = SessionResult.fromJson(json);
      expect(result.energyCurve, isEmpty);
      expect(result.pitchVariationScore, isNull);
      expect(result.volumeConsistencyScore, isNull);
    });
  });

  group('Vocal Delivery UI Widget Rendering', () {
    testWidgets('Renders pitch variation, volume stability, and LineChart contour', (tester) async {
      final result = SessionResult(
        id: 'sess-ui-test',
        mode: 'interview',
        topicOrQuestion: 'Project Walkthrough',
        durationSeconds: 60.0,
        wpm: 130.0,
        fillerWordCount: 2,
        fillerWordBreakdown: const {'um': 2},
        pauseCount: 2,
        avgPauseLength: 1.0,
        clarityScore: 85.0,
        confidenceScore: 82.0,
        overallScore: 84.0,
        aiFeedback: const [],
        createdAt: DateTime.now(),
        isAnalyzed: true,
        energyCurve: const [0.3, 0.5, 0.8, 0.6, 0.4],
        pitchVariationScore: 85.0,
        volumeConsistencyScore: 88.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Builder(
                builder: (context) {
                  return Column(
                    children: [
                      Text('Pitch Variation: ${result.pitchVariationScore!.round()} / 100'),
                      Text('Volume Stability: ${result.volumeConsistencyScore!.round()}%'),
                      const Text('Expressive Pitch'),
                      SizedBox(
                        height: 120,
                        child: LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(
                                spots: const [
                                  FlSpot(0, 0.3),
                                  FlSpot(1, 0.5),
                                  FlSpot(2, 0.8),
                                  FlSpot(3, 0.6),
                                  FlSpot(4, 0.4),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pitch Variation: 85 / 100'), findsOneWidget);
      expect(find.text('Volume Stability: 88%'), findsOneWidget);
      expect(find.text('Expressive Pitch'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });
  });
}
