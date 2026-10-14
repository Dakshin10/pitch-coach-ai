import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/features/interview/bloc/practice_session_bloc.dart';
import 'package:pitch_coach/features/interview/controllers/interview_session_controller.dart';

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

  group('PracticeSessionBloc Tests', () {
    test('initial state has default mode and idle phase', () {
      final bloc = PracticeSessionBloc(isGuest: true);
      expect(bloc.state.phase, equals(RecordingPhase.idle));
      expect(bloc.state.elapsedSeconds, equals(0));
      expect(bloc.state.audioLevel, equals(0.0));
      expect(bloc.state.isRecording, isFalse);
      expect(bloc.state.formattedTime, equals('00:00'));
      bloc.close();
    });

    blocTest<PracticeSessionBloc, PracticeSessionState>(
      'NextPromptEvent advances promptIndex',
      build: () => PracticeSessionBloc(),
      act: (bloc) => bloc.add(const NextPromptEvent()),
      expect: () => [
        isA<PracticeSessionState>().having(
          (s) => s.promptIndex,
          'promptIndex',
          equals(1),
        ),
      ],
    );

    blocTest<PracticeSessionBloc, PracticeSessionState>(
      'PreviousPromptEvent at index 0 does not loop to last prompt',
      build: () => PracticeSessionBloc(),
      act: (bloc) => bloc.add(const PreviousPromptEvent()),
      expect: () => [],
    );

    blocTest<PracticeSessionBloc, PracticeSessionState>(
      'PreviousPromptEvent decrements promptIndex from 1 to 0',
      build: () => PracticeSessionBloc(),
      seed: () => PracticeSessionState.initial().copyWith(promptIndex: 1),
      act: (bloc) => bloc.add(const PreviousPromptEvent()),
      expect: () => [
        isA<PracticeSessionState>().having(
          (s) => s.promptIndex,
          'promptIndex',
          equals(0),
        ),
      ],
    );

    blocTest<PracticeSessionBloc, PracticeSessionState>(
      'SwitchPracticeModeEvent switches mode and resets promptIndex',
      build: () => PracticeSessionBloc(),
      act: (bloc) => bloc.add(const SwitchPracticeModeEvent('presentation')),
      expect: () => [
        isA<PracticeSessionState>()
            .having((s) => s.currentMode.id, 'mode.id', equals('presentation'))
            .having((s) => s.promptIndex, 'promptIndex', equals(0)),
      ],
    );

    blocTest<PracticeSessionBloc, PracticeSessionState>(
      'RecordingTickEvent updates elapsedSeconds and formattedTime',
      build: () => PracticeSessionBloc(),
      act: (bloc) => bloc.add(const RecordingTickEvent(75)),
      expect: () => [
        isA<PracticeSessionState>()
            .having((s) => s.elapsedSeconds, 'elapsedSeconds', equals(75))
            .having((s) => s.formattedTime, 'formattedTime', equals('01:15')),
      ],
    );

    blocTest<PracticeSessionBloc, PracticeSessionState>(
      'AudioLevelChangedEvent updates audioLevel',
      build: () => PracticeSessionBloc(),
      act: (bloc) => bloc.add(const AudioLevelChangedEvent(0.85)),
      expect: () => [
        isA<PracticeSessionState>().having(
          (s) => s.audioLevel,
          'audioLevel',
          equals(0.85),
        ),
      ],
    );

    blocTest<PracticeSessionBloc, PracticeSessionState>(
      'CancelRecordingEvent resets recording phase and timer back to 0',
      build: () => PracticeSessionBloc(),
      act: (bloc) async {
        bloc.add(const RecordingTickEvent(42));
        bloc.add(const CancelRecordingEvent());
      },
      expect: () => [
        isA<PracticeSessionState>().having(
          (s) => s.elapsedSeconds,
          'elapsedSeconds',
          equals(42),
        ),
        isA<PracticeSessionState>()
            .having((s) => s.phase, 'phase', equals(RecordingPhase.idle))
            .having((s) => s.elapsedSeconds, 'elapsedSeconds', equals(0))
            .having((s) => s.audioLevel, 'audioLevel', equals(0.0)),
      ],
    );
  });
}
