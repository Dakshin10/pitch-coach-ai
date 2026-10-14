import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/practice_mode.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/providers/session_results_provider.dart';
import 'package:pitch_coach/core/repositories/session_repository.dart';
import 'package:pitch_coach/core/services/upload_queue_service.dart';
import 'package:pitch_coach/features/interview/interview_practice_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Practice Modes and Question Bank', () {
    test('All 3 core modes exist with rich question banks', () {
      expect(PracticeMode.allModes.length, 3);

      final interview = PracticeMode.fromId(PracticeMode.interviewId);
      expect(interview.title, 'Interview Practice');
      expect(interview.prompts.isNotEmpty, true);
      expect(interview.prompts.any((p) => p.category.contains('STAR')), true);

      final presentation = PracticeMode.fromId(PracticeMode.presentationId);
      expect(presentation.title, 'Presentation Practice');
      expect(presentation.prompts.isNotEmpty, true);
      expect(
        presentation.prompts.any((p) => p.category.contains('Elevator Pitch')),
        true,
      );

      final freeTalk = PracticeMode.fromId(PracticeMode.freeTalkId);
      expect(freeTalk.title, 'Free Talk');
      expect(freeTalk.prompts.isNotEmpty, true);
    });

    test(
      'Prompts have valid ids, categories, hints, and positive durations',
      () {
        for (final mode in PracticeMode.allModes) {
          for (final prompt in mode.prompts) {
            expect(prompt.id.isNotEmpty, true);
            expect(prompt.text.isNotEmpty, true);
            expect(prompt.category.isNotEmpty, true);
            expect(prompt.targetDurationSeconds, greaterThan(0));
          }
        }
      },
    );

    test('PracticeSessionConfig defaults correctly for any mode', () {
      final config = PracticeSessionConfig.defaultFor(
        PracticeMode.presentationId,
      );
      expect(config.modeId, PracticeMode.presentationId);
      expect(config.prompt.id, 'pres-1');
    });
  });

  group('InterviewSessionController State and Logic', () {
    test('Initializes in idle phase with default mode and first prompt', () {
      final ctrl = InterviewSessionController(
        isGuest: true,
        initialConfig: PracticeSessionConfig.defaultFor(
          PracticeMode.interviewId,
        ),
      );

      expect(ctrl.phase, RecordingPhase.idle);
      expect(ctrl.currentMode.id, PracticeMode.interviewId);
      expect(ctrl.promptIndex, 0);
      expect(ctrl.isRecording, false);
      expect(ctrl.isUploading, false);
      expect(ctrl.elapsedSeconds, 0);
      expect(ctrl.durationWarning, isNull);
    });

    test('Supports cycling prompts forward and backward without looping at bounds', () {
      final ctrl = InterviewSessionController(
        isGuest: true,
        initialConfig: PracticeSessionConfig.defaultFor(
          PracticeMode.interviewId,
        ),
      );

      final initialPromptId = ctrl.currentPrompt.id;
      expect(ctrl.hasPreviousPrompt, isFalse);
      expect(ctrl.hasNextPrompt, isTrue);

      // Bound check: previousPrompt at index 0 must not loop to the end
      ctrl.previousPrompt();
      expect(ctrl.promptIndex, 0);
      expect(ctrl.currentPrompt.id, initialPromptId);

      // Advance to next prompt
      ctrl.nextPrompt();
      expect(ctrl.promptIndex, 1);
      expect(ctrl.hasPreviousPrompt, isTrue);
      expect(ctrl.currentPrompt.id, isNot(initialPromptId));

      // Go back to first prompt
      ctrl.previousPrompt();
      expect(ctrl.promptIndex, 0);
      expect(ctrl.currentPrompt.id, initialPromptId);

      // Advance to the last prompt and ensure it does not loop
      for (int i = 0; i < ctrl.totalPrompts + 3; i++) {
        ctrl.nextPrompt();
      }
      expect(ctrl.promptIndex, ctrl.totalPrompts - 1);
      expect(ctrl.hasNextPrompt, isFalse);
      expect(ctrl.hasPreviousPrompt, isTrue);

      // Next at the end should stay at the end
      ctrl.nextPrompt();
      expect(ctrl.promptIndex, ctrl.totalPrompts - 1);
    });

    test('Supports switching practice mode while idle', () {
      final ctrl = InterviewSessionController(
        isGuest: true,
        initialConfig: PracticeSessionConfig.defaultFor(
          PracticeMode.interviewId,
        ),
      );

      ctrl.switchMode(PracticeMode.freeTalkId);
      expect(ctrl.currentMode.id, PracticeMode.freeTalkId);
      expect(ctrl.promptIndex, 0);
    });

    test('Enforces minimum recording length of 5 seconds', () async {
      final ctrl = InterviewSessionController(isGuest: true);

      // Attempting to stop when not recording or elapsed < 5s
      bool completed = false;
      await ctrl.stopRecording((_) => completed = true);
      expect(completed, false);
    });

    test('PendingUploadItem serialization round-trip', () {
      final now = DateTime.now();
      final item = PendingUploadItem(
        id: 'test-123',
        sessionId: 'session-xyz',
        audioPath: '/tmp/test.m4a',
        durationSeconds: 42.5,
        mode: 'presentation',
        topicOrQuestion: 'Pitch idea',
        createdAt: now,
        retryCount: 1,
        lastError: 'Network 503',
      );

      final json = item.toJson();
      final recovered = PendingUploadItem.fromJson(json);

      expect(recovered.id, item.id);
      expect(recovered.sessionId, item.sessionId);
      expect(recovered.audioPath, item.audioPath);
      expect(recovered.durationSeconds, item.durationSeconds);
      expect(recovered.mode, item.mode);
      expect(recovered.topicOrQuestion, item.topicOrQuestion);
      expect(recovered.retryCount, item.retryCount);
      expect(recovered.lastError, item.lastError);
    });
  });

  group('SessionResult Caching and Background Architecture', () {
    test('SessionResult getters format metrics cleanly', () {
      final result = SessionResult(
        id: 'sess-abc-123',
        mode: 'interview',
        topicOrQuestion: 'Tell me about yourself',
        durationSeconds: 125.0,
        wpm: 142.0,
        fillerWordCount: 4,
        fillerWordBreakdown: {'like': 2, 'um': 2},
        pauseCount: 3,
        avgPauseLength: 1.2,
        clarityScore: 88.0,
        confidenceScore: 92.0,
        overallScore: 90.0,
        aiFeedback: const [],
        createdAt: DateTime.now(),
        isAnalyzed: true,
      );

      expect(result.sessionId, 'sess-abc-123');
      expect(result.modeLabel, 'Interview');
      expect(result.totalFillerCount, 4);
      expect(result.durationFormatted, '02:05');
    });

    test(
      'SessionRepository in-memory cache stores and retrieves instantaneously',
      () {
        final repo = SessionRepository.instance;
        final result = SessionResult(
          id: 'sess-cache-test-1',
          mode: 'presentation',
          topicOrQuestion: 'Product Launch',
          durationSeconds: 60.0,
          wpm: 130.0,
          fillerWordCount: 1,
          fillerWordBreakdown: {'uh': 1},
          pauseCount: 2,
          avgPauseLength: 1.0,
          clarityScore: 95.0,
          confidenceScore: 90.0,
          overallScore: 93.0,
          aiFeedback: const [],
          createdAt: DateTime.now(),
          isAnalyzed: true,
        );

        repo.cacheSession(result);
        final cached = repo.getCachedSession('sess-cache-test-1');
        expect(cached, isNotNull);
        expect(cached!.id, 'sess-cache-test-1');
        expect(cached.overallScore, 93.0);

        repo.invalidateSessionResult('sess-cache-test-1');
        expect(repo.getCachedSession('sess-cache-test-1'), isNull);
      },
    );

    test(
      'SessionResultsProvider background tracking and announcement dismissal',
      () {
        final provider = SessionResultsProvider();
        expect(provider.hasActiveBackgroundProcessing, false);
        expect(provider.completedSessionToAnnounce, isNull);

        // Start background processing
        provider.startBackgroundProcessing(
          sessionId: 'bg-sess-456',
          topic: 'Tell me about a challenging project',
          mode: 'interview',
        );

        expect(provider.hasActiveBackgroundProcessing, true);
        expect(provider.activeSessionId, 'bg-sess-456');
        expect(provider.activeTopic, 'Tell me about a challenging project');
        expect(provider.activeMode, 'interview');

        // Dismiss announcement
        provider.dismissCompletedAnnouncement();
        expect(provider.completedSessionToAnnounce, isNull);
      },
    );
  });
}
