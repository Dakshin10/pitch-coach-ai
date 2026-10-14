import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/providers/session_results_provider.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/core/repositories/session_repository.dart';
import 'package:pitch_coach/features/results/results_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Feature 1: Transcript Playback Models & Seeking Math', () {
    test('WordTimestamp model serializes and deserializes correctly', () {
      final json = {'word': 'basically', 'start': 4.5, 'end': 5.1};
      final wt = WordTimestamp.fromJson(json);

      expect(wt.word, 'basically');
      expect(wt.start, 4.5);
      expect(wt.end, 5.1);
      expect(wt.toJson(), json);
    });

    test('SessionResult parses wordTimestamps and audioOffsetSeconds', () {
      final json = {
        'id': 'session_interactive_1',
        'mode': 'interview',
        'topic_or_question': 'Tell me about yourself',
        'duration_seconds': 60.0,
        'transcript': 'Hello um world',
        'word_timestamps': [
          {'word': 'Hello', 'start': 0.1, 'end': 0.4},
          {'word': 'um', 'start': 0.5, 'end': 0.8},
          {'word': 'world', 'start': 0.9, 'end': 1.4},
        ],
        'audio_offset_seconds': 0.25,
        'wpm': 130.0,
        'filler_word_count': 1,
        'filler_word_breakdown': {'um': 1},
        'pause_count': 1,
        'avg_pause_length': 0.6,
        'clarity_score': 88.0,
        'confidence_score': 85.0,
        'overall_score': 86.5,
        'ai_feedback': [],
        'created_at': DateTime.now().toIso8601String(),
        'is_analyzed': true,
      };

      final result = SessionResult.fromJson(json);
      expect(result.wordTimestamps.length, 3);
      expect(result.wordTimestamps[1].word, 'um');
      expect(result.audioOffsetSeconds, 0.25);
    });

    test('Seeking calculation clamps early timestamps and applies offset', () {
      // Seek target formula: ((start - offset) - 0.3s).clamp(0.0, maxDuration)
      double computeSeek(double start, {double offset = 0.0, double max = 60.0}) {
        final raw = (start - offset) - 0.3;
        return raw.clamp(0.0, max);
      }

      // Word at 0.1s -> raw is -0.2s -> clamps to 0.0s
      expect(computeSeek(0.1), 0.0);
      // Word at 0.3s -> raw is 0.0s -> 0.0s
      expect(computeSeek(0.3), 0.0);
      // Word at 2.5s -> raw is 2.2s -> 2.2s
      expect(computeSeek(2.5), closeTo(2.2, 0.001));
      // Word at 3.0s with slide rehearsal offset 1.0s -> raw is (3.0 - 1.0) - 0.3 = 1.7s
      expect(computeSeek(3.0, offset: 1.0), closeTo(1.7, 0.001));
      // Word beyond end -> clamped to max
      expect(computeSeek(65.0, max: 60.0), 60.0);
    });
  });

  group('Feature 1: Interactive Transcript Widget', () {
    testWidgets('Renders interactive transcript card with filler badge and tappable words',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleResult = SessionResult(
        id: 'widget-test-session',
        mode: 'interview',
        topicOrQuestion: 'Introduce yourself',
        durationSeconds: 15.0,
        transcript: 'Hello everyone, um, my name is Alex and I, like, code.',
        wordTimestamps: const [
          WordTimestamp(word: 'Hello', start: 0.2, end: 0.6),
          WordTimestamp(word: 'everyone,', start: 0.7, end: 1.2),
          WordTimestamp(word: 'um,', start: 1.4, end: 1.8),
          WordTimestamp(word: 'my', start: 2.0, end: 2.2),
          WordTimestamp(word: 'name', start: 2.3, end: 2.6),
          WordTimestamp(word: 'is', start: 2.7, end: 2.9),
          WordTimestamp(word: 'Alex', start: 3.0, end: 3.4),
          WordTimestamp(word: 'and', start: 3.5, end: 3.7),
          WordTimestamp(word: 'I,', start: 3.8, end: 4.0),
          WordTimestamp(word: 'like,', start: 4.2, end: 4.5),
          WordTimestamp(word: 'code.', start: 4.7, end: 5.2),
        ],
        wpm: 125.0,
        fillerWordCount: 2,
        fillerWordBreakdown: const {'um': 1, 'like': 1},
        pauseCount: 2,
        avgPauseLength: 0.7,
        clarityScore: 84.0,
        confidenceScore: 82.0,
        overallScore: 83.0,
        aiFeedback: const [],
        createdAt: DateTime.now(),
        isAnalyzed: true,
      );

      // Cache session so SessionRepository.getSession returns it
      SessionRepository.instance.cacheSession(sampleResult);

      final resultsProvider = SessionResultsProvider();
      final userProvider = UserProvider();
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionResultsProvider>.value(
              value: resultsProvider,
            ),
            ChangeNotifierProvider<UserProvider>.value(
              value: userProvider,
            ),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider,
            ),
          ],
          child: const MaterialApp(
            home: ResultsScreen(sessionId: 'widget-test-session'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for Interactive Transcript section
      expect(find.text('Interactive Transcript'), findsOneWidget);
      expect(find.text('Tap any word or sentence to listen'), findsOneWidget);

      // Check filler word badge is rendered
      expect(find.text('2 Fillers'), findsOneWidget);

      // Check filler words exist in the widget tree
      expect(find.text('um,'), findsOneWidget);
      expect(find.text('like,'), findsOneWidget);

      // Tap on a filler word "um,"
      final wordFinder = find.text('um,');
      await tester.tap(wordFinder);
      await tester.pump();
    });
  });
}
