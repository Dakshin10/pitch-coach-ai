import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/blocs/session_results_bloc.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/providers/session_results_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const MethodChannel storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (MethodCall call) async {
          return null;
        });
  });

  final testSession = SessionResult(
    id: 'session-123',
    mode: 'interview',
    topicOrQuestion: 'Tell me about yourself',
    durationSeconds: 65.0,
    wpm: 135.0,
    fillerWordCount: 2,
    fillerWordBreakdown: const {'um': 2},
    pauseCount: 3,
    avgPauseLength: 1.2,
    clarityScore: 88.0,
    confidenceScore: 85.0,
    overallScore: 86.0,
    aiFeedback: const [],
    isAnalyzed: true,
    createdAt: DateTime.now(),
  );

  group('SessionResultsBloc Tests', () {
    test('initial state has loading status and null result', () {
      final bloc = SessionResultsBloc();
      expect(bloc.state.status, equals(ResultsLoadState.loading));
      expect(bloc.state.result, isNull);
      expect(bloc.state.isBackgroundProcessing, isFalse);
      bloc.close();
    });

    blocTest<SessionResultsBloc, SessionResultsState>(
      'DismissAnnouncementEvent clears completedSessionToAnnounce',
      build: () => SessionResultsBloc(),
      seed: () => SessionResultsState(completedSessionToAnnounce: testSession),
      act: (bloc) => bloc.add(const DismissAnnouncementEvent()),
      expect: () => [
        isA<SessionResultsState>().having(
          (s) => s.completedSessionToAnnounce,
          'announcement',
          isNull,
        ),
      ],
    );

    blocTest<SessionResultsBloc, SessionResultsState>(
      'StartBackgroundProcessingEvent updates active processing session',
      build: () => SessionResultsBloc(),
      act: (bloc) => bloc.add(
        const StartBackgroundProcessingEvent(
          sessionId: 'sess-abc',
          topic: 'Investor pitch',
          mode: 'pitch',
        ),
      ),
      expect: () => [
        isA<SessionResultsState>()
            .having(
              (s) => s.activeSessionId,
              'activeSessionId',
              equals('sess-abc'),
            )
            .having(
              (s) => s.activeTopic,
              'activeTopic',
              equals('Investor pitch'),
            )
            .having((s) => s.activeMode, 'activeMode', equals('pitch'))
            .having(
              (s) => s.isBackgroundProcessing,
              'isBackgroundProcessing',
              isTrue,
            )
            .having(
              (s) => s.status,
              'status',
              equals(ResultsLoadState.analyzing),
            ),
      ],
    );
  });
}
