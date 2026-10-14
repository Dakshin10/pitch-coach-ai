import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pitch_coach/core/models/multi_turn_interview.dart';
import 'package:pitch_coach/core/models/practice_mode.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/core/services/tts_service.dart';
import 'package:pitch_coach/features/interview/interview_practice_screen.dart';

void main() {
  group('Multi-Turn Interviewer Models & Services', () {
    test('TurnMessage JSON serializes and deserializes correctly', () {
      const msg = TurnMessage(
        role: TurnRole.interviewer,
        content: 'What was the specific outcome?',
      );
      final json = msg.toJson();
      expect(json['role'], 'interviewer');
      expect(json['content'], 'What was the specific outcome?');

      final reconstructed = TurnMessage.fromJson(json);
      expect(reconstructed.role, TurnRole.interviewer);
      expect(reconstructed.content, 'What was the specific outcome?');
    });

    test('TurnEvaluateResponse parses JSON with latency and follow-up', () {
      final json = {
        'follow_up': 'Could you share the technical root cause?',
        'move_on': false,
        'reason': 'Lacks root cause explanation.',
        'is_vague': true,
        'latency_ms': 1240.5,
        'transcription': 'I fixed the app bug yesterday.',
      };

      final response = TurnEvaluateResponse.fromJson(json);
      expect(response.followUp, 'Could you share the technical root cause?');
      expect(response.moveOn, isFalse);
      expect(response.isVague, isTrue);
      expect(response.latencyMs, 1240.5);
      expect(response.transcription, 'I fixed the app bug yesterday.');
    });

    test('ExchangeScoreResponse parses composite scoring and STAR breakdown', () {
      final json = {
        'clarity_score': 84.5,
        'confidence_score': 79.0,
        'overall_score': 82.0,
        'feedback_summary':
            'Solid multi-turn response with clear technical depth.',
        'strengths': ['Specific metrics', 'Clear STAR format'],
        'improvements': ['Reduce um/uh fillers'],
        'star_assessment': {
          'situation': 'Production latency spike',
          'task': 'Optimize checkout service',
          'action': 'Added composite indexing and Redis cache',
          'result': 'P99 dropped by 85%',
        },
        'latency_ms': 980.2,
      };

      final score = ExchangeScoreResponse.fromJson(json);
      expect(score.clarityScore, 84.5);
      expect(score.confidenceScore, 79.0);
      expect(score.overallScore, 82.0);
      expect(score.strengths.length, 2);
      expect(score.starAssessment?['result'], 'P99 dropped by 85%');
    });

    test('TtsService toggles and handles speak gracefully without errors', () async {
      final tts = TtsService.instance;
      tts.setEnabled(true);
      expect(tts.isEnabled, isTrue);

      tts.toggleEnabled();
      expect(tts.isEnabled, isFalse);

      tts.toggleEnabled();
      expect(tts.isEnabled, isTrue);

      // Verify calling speak does not throw
      await expectLater(tts.speak('Follow-up question test'), completes);
      tts.stop();
      expect(tts.isSpeaking, isFalse);
    });
  });

  group('InterviewSessionController Multi-Turn Logic', () {
    test('Initializes with multi-turn enabled and clean follow-up state', () {
      final controller = InterviewSessionController(isGuest: true);
      expect(controller.isMultiTurnEnabled, isTrue);
      expect(controller.followUpCount, 0);
      expect(controller.dialogueTurns, isEmpty);
      expect(controller.currentFollowUp, isNull);
      expect(controller.isThinking, isFalse);
      expect(controller.turnEvaluationFailed, isFalse);
    });

    test('resetMultiTurn clears follow-ups and turns', () {
      final controller = InterviewSessionController(isGuest: true);
      controller.toggleMultiTurn(true);
      controller.resetMultiTurn();
      expect(controller.followUpCount, 0);
      expect(controller.dialogueTurns, isEmpty);
      expect(controller.currentFollowUp, isNull);
    });
  });

  group('InterviewPracticeScreen Multi-Turn UI Widgets', () {
    testWidgets('Renders TTS voice toggle in the top bar and toggles state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(home: InterviewPracticeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final ttsToggleFinder = find.byKey(const Key('tts_toggle_button'));
      expect(ttsToggleFinder, findsOneWidget);

      await tester.tap(ttsToggleFinder);
      await tester.pump(const Duration(milliseconds: 50));

      expect(TtsService.instance.isEnabled, isFalse);

      // Toggle back
      await tester.tap(ttsToggleFinder);
      await tester.pump(const Duration(milliseconds: 50));
      expect(TtsService.instance.isEnabled, isTrue);
    });

    testWidgets('Shows question card and handles practice configuration', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            home: InterviewPracticeScreen(
              initialConfig: PracticeSessionConfig(
                modeId: PracticeMode.interviewId,
                prompt: PracticePrompt(
                  id: 'test-p1',
                  text: 'Tell me about a challenging bug.',
                  category: 'Technical',
                  hint: 'Focus on root cause and results.',
                  targetDurationSeconds: 90,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tell me about a challenging bug.'), findsOneWidget);
    });
  });
}
