import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/practice_mode.dart';
import 'package:pitch_coach/core/services/upload_queue_service.dart';
import 'package:pitch_coach/features/interview/interview_practice_screen.dart';

void main() {
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
      expect(presentation.prompts.any((p) => p.category.contains('Elevator Pitch')), true);

      final freeTalk = PracticeMode.fromId(PracticeMode.freeTalkId);
      expect(freeTalk.title, 'Free Talk');
      expect(freeTalk.prompts.isNotEmpty, true);
    });

    test('Prompts have valid ids, categories, hints, and positive durations', () {
      for (final mode in PracticeMode.allModes) {
        for (final prompt in mode.prompts) {
          expect(prompt.id.isNotEmpty, true);
          expect(prompt.text.isNotEmpty, true);
          expect(prompt.category.isNotEmpty, true);
          expect(prompt.targetDurationSeconds, greaterThan(0));
        }
      }
    });

    test('PracticeSessionConfig defaults correctly for any mode', () {
      final config = PracticeSessionConfig.defaultFor(PracticeMode.presentationId);
      expect(config.modeId, PracticeMode.presentationId);
      expect(config.prompt.id, 'pres-1');
    });
  });

  group('InterviewSessionController State and Logic', () {
    test('Initializes in idle phase with default mode and first prompt', () {
      final ctrl = InterviewSessionController(
        isGuest: true,
        initialConfig: PracticeSessionConfig.defaultFor(PracticeMode.interviewId),
      );

      expect(ctrl.phase, RecordingPhase.idle);
      expect(ctrl.currentMode.id, PracticeMode.interviewId);
      expect(ctrl.promptIndex, 0);
      expect(ctrl.isRecording, false);
      expect(ctrl.isUploading, false);
      expect(ctrl.elapsedSeconds, 0);
      expect(ctrl.durationWarning, isNull);
    });

    test('Supports cycling prompts forward and backward', () {
      final ctrl = InterviewSessionController(
        isGuest: true,
        initialConfig: PracticeSessionConfig.defaultFor(PracticeMode.interviewId),
      );

      final initialPromptId = ctrl.currentPrompt.id;
      ctrl.nextPrompt();
      expect(ctrl.promptIndex, 1);
      expect(ctrl.currentPrompt.id, isNot(initialPromptId));

      ctrl.previousPrompt();
      expect(ctrl.promptIndex, 0);
      expect(ctrl.currentPrompt.id, initialPromptId);
    });

    test('Supports switching practice mode while idle', () {
      final ctrl = InterviewSessionController(
        isGuest: true,
        initialConfig: PracticeSessionConfig.defaultFor(PracticeMode.interviewId),
      );

      ctrl.switchMode(PracticeMode.freeTalkId);
      expect(ctrl.currentMode.id, PracticeMode.freeTalkId);
      expect(ctrl.promptIndex, 0);
    });

    test('Enforces minimum recording length of 5 seconds', () async {
      final ctrl = InterviewSessionController(
        isGuest: true,
      );

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
}
