import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/practice_mode.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/providers/session_results_provider.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/core/repositories/demo_repository.dart';
import 'package:pitch_coach/features/results/results_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Feature 2: Attempt Comparison Models & Math', () {
    test('SessionResult parses parent_session_id', () {
      final json = {
        'id': 'session_attempt_2',
        'parent_session_id': 'session_attempt_1',
        'mode': 'interview',
        'topic_or_question': 'Tell me about yourself',
        'duration_seconds': 60.0,
        'wpm': 135.0,
        'filler_word_count': 2,
        'filler_word_breakdown': {'um': 2},
        'pause_count': 3,
        'avg_pause_length': 0.8,
        'clarity_score': 85.0,
        'confidence_score': 82.0,
        'overall_score': 84.0,
        'ai_feedback': [],
        'created_at': DateTime.now().toIso8601String(),
        'is_analyzed': true,
      };

      final result = SessionResult.fromJson(json);
      expect(result.id, 'session_attempt_2');
      expect(result.parentSessionId, 'session_attempt_1');
    });

    test('WPM optimal 120-160 band distance calculations', () {
      expect(SessionResult.wpmBandDistance(135.0), 0.0); // Inside optimal band
      expect(SessionResult.wpmBandDistance(120.0), 0.0); // Lower boundary
      expect(SessionResult.wpmBandDistance(160.0), 0.0); // Upper boundary
      expect(SessionResult.wpmBandDistance(105.0), 15.0); // 15 WPM below target
      expect(SessionResult.wpmBandDistance(175.0), 15.0); // 15 WPM above target
    });

    test('fillersPer100Words calculates accurately with word count', () {
      final session = SessionResult(
        id: 's1',
        mode: 'interview',
        topicOrQuestion: 'Tell me about a time you solved a hard bug',
        durationSeconds: 60.0,
        wpm: 120.0,
        fillerWordCount: 4,
        fillerWordBreakdown: const {'um': 4},
        pauseCount: 2,
        avgPauseLength: 0.6,
        clarityScore: 80,
        confidenceScore: 80,
        overallScore: 80,
        aiFeedback: const [],
        createdAt: DateTime.now(),
        isAnalyzed: true,
        wordTimestamps: List.generate(
          100,
          (i) => WordTimestamp(word: 'word$i', start: i * 0.5, end: i * 0.5 + 0.3),
        ),
      );

      expect(session.fillersPer100Words, 4.0);
    });

    test('PracticeSessionConfig carries parentSessionId correctly', () {
      const prompt = PracticePrompt(
        id: 'p1',
        text: 'Walk me through your resume.',
        category: 'Interview',
        hint: 'Be concise',
        targetDurationSeconds: 90,
      );
      const config = PracticeSessionConfig(
        modeId: 'interview',
        prompt: prompt,
        parentSessionId: 'parent_uuid_123',
      );

      expect(config.modeId, 'interview');
      expect(config.prompt.text, 'Walk me through your resume.');
      expect(config.parentSessionId, 'parent_uuid_123');
    });
  });

  group('Feature 2: Attempt Comparison Widget Tests', () {
    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => SessionResultsProvider()),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: child,
        ),
      );
    }

    testWidgets(
      'Linked attempt renders Attempt Comparison delta card when prompts match',
      (tester) async {
        final parentResult = SessionResult(
          id: 'parent_1',
          mode: 'interview',
          topicOrQuestion: 'Tell me about yourself.',
          durationSeconds: 90,
          wpm: 105, // Below 120-160 band
          fillerWordCount: 6,
          fillerWordBreakdown: const {'um': 6},
          pauseCount: 6,
          avgPauseLength: 1.2,
          clarityScore: 70,
          confidenceScore: 70,
          overallScore: 72,
          aiFeedback: const [],
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isAnalyzed: true,
        );

        // Demo result in DemoRepository has topicOrQuestion: 'Tell me about yourself.'
        // and overallScore: 82, wpm: 128 (in optimal band), pauseCount: 4.
        final currentLinked = DemoRepository.instance.result.copyWith(
          id: 'child_attempt_2',
          parentSessionId: 'parent_1',
        );

        await tester.pumpWidget(
          createTestApp(
            ResultsScreen(
              initialResult: currentLinked,
              initialParentResult: parentResult,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check if Attempt Comparison header and badge appear
        expect(find.text('Attempt Comparison'), findsOneWidget);
        expect(find.text('Linked Attempt'), findsOneWidget);
        expect(find.text('Comparing against your previous run'), findsOneWidget);

        // Check Overall Score delta (+10 pts)
        expect(find.text('Overall Score'), findsNWidgets(2));
        expect(find.text('+10.0 pts'), findsOneWidget);

        // Check Pacing Optimal Band comparison
        expect(find.text('Pacing (120–160 Band)'), findsOneWidget);
        expect(find.text('Reached Optimal Band!'), findsOneWidget);

        // Check Pauses delta
        expect(find.text('Pauses (>1.5s)'), findsOneWidget);
        expect(find.text('-2 pauses'), findsOneWidget);
      },
    );

    testWidgets(
      'Session with no parent does NOT render Attempt Comparison card',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const ResultsScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Default DemoRepository result has no parentSessionId
        expect(find.text('Attempt Comparison'), findsNothing);
        expect(find.text('Linked Attempt'), findsNothing);
      },
    );

    testWidgets(
      'Attempt with mismatched prompt hides comparison card',
      (tester) async {
        final parentResult = SessionResult(
          id: 'parent_diff_prompt',
          mode: 'interview',
          topicOrQuestion: 'Completely different question about databases',
          durationSeconds: 90,
          wpm: 130,
          fillerWordCount: 2,
          fillerWordBreakdown: const {'like': 2},
          pauseCount: 2,
          avgPauseLength: 0.5,
          clarityScore: 85,
          confidenceScore: 85,
          overallScore: 85,
          aiFeedback: const [],
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          isAnalyzed: true,
        );

        await tester.pumpWidget(
          createTestApp(
            ResultsScreen(
              initialParentResult: parentResult,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Prompts differ ('Tell me about yourself.' vs 'Completely different question...')
        expect(find.text('Attempt Comparison'), findsNothing);
      },
    );
  });
}
