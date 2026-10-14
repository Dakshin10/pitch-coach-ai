import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/practice_mode.dart';
import '../../../core/models/resume_interview.dart';
import '../../../core/models/multi_turn_interview.dart';
import '../../../core/models/pitch_template.dart';
import '../../../core/repositories/session_repository.dart';
import '../../../core/repositories/multi_turn_repository.dart';
import '../../../core/repositories/template_repository.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/local_database_service.dart';
import '../../../core/services/outbox_worker.dart';
import '../../../core/services/upload_queue_service.dart';
import '../../../core/services/rolling_wpm_estimator.dart';
import '../bloc/practice_session_bloc.dart';

enum RecordingPhase { idle, recording, uploading, failed, permissionDenied }

/// State Controller managing practice modes, audio recording lifecycle,
/// clip constraints, upload resilience, and mic permissions.
class InterviewSessionController extends ChangeNotifier {
  final bool isGuest;
  final _sessionRepo = SessionRepository.instance;
  final _uploadQueue = UploadQueueService.instance;
  final _wpmEstimator = RollingWpmEstimator();

  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // ── Limits ────────────────────────────────────────────────────────────────
  static const int minRecordingSeconds = 5;
  static const int maxRecordingSeconds = 300; // 5 minutes limit
  static const int warningThresholdSeconds = 270; // 4m 30s warning

  // ── Mode and Question State ───────────────────────────────────────────────
  late PracticeMode _currentMode;
  int _promptIndex = 0;

  // ── Recording Lifecycle ───────────────────────────────────────────────────
  RecordingPhase _phase = RecordingPhase.idle;
  int _elapsedSeconds = 0;
  double _audioLevel = 0.0;
  String? _durationWarning;
  String? _errorMessage;

  // ── Resilient Upload State ────────────────────────────────────────────────
  String? _sessionId;
  String? _activeAudioPath;
  String? _failedAudioPath;
  String? _failedSessionId;
  MicPermissionState _micPermissionState = MicPermissionState.granted;
  void Function(String? sessionId)? onAutoStop;
  PracticeSessionBloc? _bloc;
  final String? parentSessionId;
  PracticePrompt? _customPrompt;

  // ── Multi-Turn AI Interviewer State ───────────────────────────────────────
  final _multiTurnRepo = MultiTurnRepository.instance;
  final _ttsService = TtsService.instance;
  bool _isMultiTurnEnabled = true;
  int _followUpCount = 0;
  final List<TurnMessage> _dialogueTurns = [];
  String? _currentFollowUp;
  String? _interviewerReason;
  bool _isThinking = false;
  double? _lastTurnLatencyMs;
  ExchangeScoreResponse? _exchangeScore;
  bool _turnEvaluationFailed = false;
  String? _pendingTurnAudioPath;

  /// Exposes the reactive PracticeSessionBloc for BLoC-driven UI components.
  PracticeSessionBloc get bloc => _bloc ??= PracticeSessionBloc(
    isGuest: isGuest,
    initialConfig: PracticeSessionConfig(
      modeId: _currentMode.id,
      prompt: currentPrompt,
      parentSessionId: parentSessionId,
    ),
  );

  InterviewSessionController({
    required this.isGuest,
    PracticeSessionConfig? initialConfig,
  }) : parentSessionId = initialConfig?.parentSessionId {
    if (initialConfig != null) {
      _currentMode = initialConfig.mode;
      final idx = _currentMode.prompts.indexWhere(
        (p) =>
            p.id == initialConfig.prompt.id ||
            p.text == initialConfig.prompt.text,
      );
      if (idx >= 0) {
        _promptIndex = idx;
      } else {
        _customPrompt = initialConfig.prompt;
      }
    } else {
      _currentMode = PracticeMode.allModes.first;
      _promptIndex = 0;
    }
    loadTemplates();
    _ttsService.addListener(notifyListeners);
  }

  // ── Pitch Template State ──────────────────────────────────────────────────
  PitchTemplate? _selectedTemplate;
  List<PitchTemplate> _availableTemplates = PitchTemplate.defaultTemplates;

  PitchTemplate? get selectedTemplate => _selectedTemplate;
  List<PitchTemplate> get availableTemplates => _availableTemplates;

  Future<void> loadTemplates() async {
    try {
      final list = await TemplateRepository.instance.getTemplates();
      if (list.isNotEmpty) {
        _availableTemplates = list;
        notifyListeners();
      }
    } catch (_) {}
  }

  void selectTemplate(PitchTemplate? template) {
    if (isRecording || isUploading) return;
    _selectedTemplate = template;
    if (template != null) {
      _customPrompt = PracticePrompt(
        id: template.id,
        text: '${template.title}: ${template.description}',
        category: 'Pitch Template',
        hint: 'Coach Focus: ${template.coachingFocus}',
        targetDurationSeconds: template.targetDurationSeconds,
      );
    }
    resetMultiTurn();
    notifyListeners();
  }

  // Getters
  PracticeMode get currentMode => _currentMode;
  int get promptIndex => _promptIndex;
  PracticePrompt get currentPrompt =>
      _customPrompt ?? _currentMode.prompts[_promptIndex];
  int get totalPrompts => _currentMode.prompts.length;
  bool get hasPreviousPrompt => _promptIndex > 0;
  bool get hasNextPrompt => _promptIndex < _currentMode.prompts.length - 1;

  RecordingPhase get phase => _phase;
  bool get isRecording => _phase == RecordingPhase.recording;
  bool get isUploading => _phase == RecordingPhase.uploading;
  bool get isFailed => _phase == RecordingPhase.failed;
  bool get isPermissionDenied => _phase == RecordingPhase.permissionDenied;

  int get elapsedSeconds => _elapsedSeconds;
  double get audioLevel => _audioLevel;
  String? get durationWarning => _durationWarning;
  String? get errorMessage => _errorMessage;
  MicPermissionState get micPermissionState => _micPermissionState;
  String? get sessionId => _sessionId;
  String? get activeAudioPath => _activeAudioPath;

  String get formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  RollingWpmEstimator get wpmEstimator => _wpmEstimator;
  double get rollingWpm => _wpmEstimator.currentWpm;
  PacingState get pacingState => _wpmEstimator.pacingState;
  Color get pacingColor => _wpmEstimator.pacingColor;

  @visibleForTesting
  void setWpmForTesting(double wpm) {
    _wpmEstimator.setWpmForTesting(wpm);
    notifyListeners();
  }

  @visibleForTesting
  void setRecordingPhaseForTesting(RecordingPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  // ── Multi-Turn Getters & Controls ─────────────────────────────────────────
  bool get isMultiTurnEnabled => _isMultiTurnEnabled;
  int get followUpCount => _followUpCount;
  List<TurnMessage> get dialogueTurns => List.unmodifiable(_dialogueTurns);
  String? get currentFollowUp => _currentFollowUp;
  String? get interviewerReason => _interviewerReason;
  bool get isThinking => _isThinking;
  double? get lastTurnLatencyMs => _lastTurnLatencyMs;
  ExchangeScoreResponse? get exchangeScore => _exchangeScore;
  bool get turnEvaluationFailed => _turnEvaluationFailed;
  bool get isTtsEnabled => _ttsService.isEnabled;
  bool get isTtsSpeaking => _ttsService.isSpeaking;
  bool get showCaptions => _ttsService.showCaptions;
  String? get currentCaption => _ttsService.currentCaption;

  void toggleTts() {
    _ttsService.toggleEnabled();
    notifyListeners();
  }

  void toggleCaptions() {
    _ttsService.toggleCaptions();
    notifyListeners();
  }

  void toggleMultiTurn(bool enabled) {
    _isMultiTurnEnabled = enabled;
    notifyListeners();
  }

  void resetMultiTurn() {
    _followUpCount = 0;
    _dialogueTurns.clear();
    _currentFollowUp = null;
    _interviewerReason = null;
    _isThinking = false;
    _lastTurnLatencyMs = null;
    _exchangeScore = null;
    _turnEvaluationFailed = false;
    _pendingTurnAudioPath = null;
    notifyListeners();
  }

  // ── Mode and Prompt Selection ─────────────────────────────────────────────

  void switchMode(String modeId) {
    if (isRecording || isUploading) return;
    _currentMode = PracticeMode.fromId(modeId);
    _customPrompt = null;
    _promptIndex = 0;
    _durationWarning = null;
    _errorMessage = null;
    resetMultiTurn();
    notifyListeners();
  }

  void nextPrompt() {
    if (isRecording || isUploading) return;
    if (_promptIndex < _currentMode.prompts.length - 1) {
      _customPrompt = null;
      _promptIndex++;
      resetMultiTurn();
      notifyListeners();
    }
  }

  void previousPrompt() {
    if (isRecording || isUploading) return;
    if (_promptIndex > 0) {
      _customPrompt = null;
      _promptIndex--;
      resetMultiTurn();
      notifyListeners();
    }
  }

  /// Loads tailored questions generated from a candidate's resume/JD.
  void loadResumeQuestions(ResumeQuestionsResult questions) {
    if (questions.allQuestions.isEmpty) return;
    final resumePrompts = <PracticePrompt>[];
    for (int i = 0; i < questions.technicalQuestions.length; i++) {
      resumePrompts.add(
        PracticePrompt(
          id: 'resume-tech-$i',
          text: questions.technicalQuestions[i],
          category: 'Resume Technical',
          hint:
              'Anchor your answer in specific implementation decisions, architectural trade-offs, and metrics from your project.',
          targetDurationSeconds: 90,
        ),
      );
    }
    for (int i = 0; i < questions.behavioralQuestions.length; i++) {
      resumePrompts.add(
        PracticePrompt(
          id: 'resume-behav-$i',
          text: questions.behavioralQuestions[i],
          category: 'Resume Behavioral',
          hint:
              'Use the STAR framework (Situation, Task, Action, Result) with concrete quantifiable outcomes.',
          targetDurationSeconds: 90,
        ),
      );
    }
    _currentMode = PracticeMode(
      id: PracticeMode.interviewId,
      title: 'Resume Interview',
      subtitle: 'Questions tailored to your resume projects & skills',
      icon: Icons.badge_outlined,
      prompts: resumePrompts,
      defaultTargetSeconds: 90,
    );
    _customPrompt = null;
    _promptIndex = 0;
    _durationWarning = null;
    _errorMessage = null;
    resetMultiTurn();
    notifyListeners();
  }

  // ── Recording Lifecycle ───────────────────────────────────────────────────

  Future<void> startRecording() async {
    if (isRecording || isUploading) return;

    _durationWarning = null;
    _errorMessage = null;

    // Check microphone permission
    final permStatus = await _sessionRepo.requestMicPermissionStatus();
    _micPermissionState = permStatus;

    if (permStatus != MicPermissionState.granted) {
      _phase = RecordingPhase.permissionDenied;
      _errorMessage = permStatus == MicPermissionState.permanentlyDenied
          ? 'Microphone permission is permanently denied. Please enable it in Settings.'
          : 'Microphone permission was denied. Tap below to grant access.';
      notifyListeners();
      return;
    }

    try {
      _elapsedSeconds = 0;
      if (isGuest) {
        await _sessionRepo.startDemoRecording();
        _sessionId = 'demo-session';
      } else {
        _sessionId = await _sessionRepo.startSession(
          mode: _currentMode.id,
          topicOrQuestion: currentPrompt.text,
          parentSessionId: parentSessionId,
        );
      }
      _activeAudioPath = _sessionRepo.currentAudioPath;
      _phase = RecordingPhase.recording;
      _wpmEstimator.reset();

      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _sessionRepo.amplitudeStream.listen((amp) {
        _audioLevel = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        _wpmEstimator.updateWithAmplitude(_audioLevel);
        notifyListeners();
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsedSeconds++;

        // Warning when approaching 5 minutes limit
        if (_elapsedSeconds >= maxRecordingSeconds) {
          _durationWarning =
              'Maximum 5 minute limit reached. Processing recording...';
          notifyListeners();
          _autoStopAtMax();
        } else if (_elapsedSeconds >= warningThresholdSeconds) {
          final remaining = maxRecordingSeconds - _elapsedSeconds;
          _durationWarning = 'Approaching 5m limit (${remaining}s remaining)';
          notifyListeners();
        } else {
          notifyListeners();
        }
      });

      notifyListeners();
    } catch (e) {
      _phase = RecordingPhase.failed;
      _errorMessage =
          'Could not start microphone recording. Please check audio permissions.';
      notifyListeners();
    }
  }

  void _autoStopAtMax() {
    stopRecording(onAutoStop ?? (_) {});
  }

  /// Stops recording and uploads for AI coaching.
  Future<void> stopRecording(
    void Function(String? sessionId) onComplete,
  ) async {
    if (!isRecording) return;

    // Enforce minimum clip length (5 seconds)
    if (_elapsedSeconds < minRecordingSeconds) {
      _durationWarning =
          'Recording is too short ($_elapsedSeconds s). Minimum 5 seconds required to evaluate speech.';
      notifyListeners();
      return;
    }

    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    _phase = RecordingPhase.uploading;
    _durationWarning = null;
    notifyListeners();

    if (isGuest) {
      await _sessionRepo.finishDemoRecording();
      _phase = RecordingPhase.idle;
      notifyListeners();
      onComplete(null);
      return;
    }

    final audioPath = await _sessionRepo.stopAudioRecorder();
    _activeAudioPath = audioPath;

    final isInterview = _currentMode.id == PracticeMode.interviewId ||
        _currentMode.title.toLowerCase().contains('interview');

    if (_isMultiTurnEnabled && isInterview) {
      _isThinking = true;
      notifyListeners();

      final sw = Stopwatch()..start();
      try {
        final evalResult = await _multiTurnRepo.evaluateTurnAudio(
          audioPath: audioPath ?? '',
          question: _currentFollowUp ?? currentPrompt.text,
          turnHistory: _dialogueTurns,
          followUpCount: _followUpCount,
        );
        sw.stop();
        _lastTurnLatencyMs =
            evalResult.latencyMs ?? sw.elapsedMilliseconds.toDouble();
        _turnEvaluationFailed = false;
        _pendingTurnAudioPath = null;

        // If vague and follow-up cap not reached, present follow-up!
        if (!evalResult.moveOn &&
            evalResult.followUp != null &&
            _followUpCount < 2) {
          _followUpCount++;
          _currentFollowUp = evalResult.followUp;
          _interviewerReason = evalResult.reason;
          _dialogueTurns.add(
            TurnMessage(
              role: TurnRole.candidate,
              content: evalResult.transcription ?? 'Candidate answer',
            ),
          );
          _dialogueTurns.add(
            TurnMessage(
              role: TurnRole.interviewer,
              content: evalResult.followUp!,
            ),
          );
          _isThinking = false;
          _phase = RecordingPhase.idle;
          notifyListeners();
          if (_ttsService.isEnabled) {
            _ttsService.speak(evalResult.followUp!);
          }
          return;
        }

        // Strong answer or reached max 2 follow-ups -> score full exchange
        _dialogueTurns.add(
          TurnMessage(
            role: TurnRole.candidate,
            content: evalResult.transcription ?? 'Candidate answer',
          ),
        );

        try {
          _exchangeScore = await _multiTurnRepo.scoreExchange(
            question: currentPrompt.text,
            turns: _dialogueTurns,
          );
        } catch (scoreErr) {
          debugPrint(
            '[InterviewSessionController] scoreExchange notice: $scoreErr',
          );
        }

        _isThinking = false;
        notifyListeners();
      } catch (evalErr) {
        sw.stop();
        _isThinking = false;
        _phase = RecordingPhase.failed;
        _turnEvaluationFailed = true;
        _pendingTurnAudioPath = audioPath;
        _errorMessage =
            'Network issue while evaluating answer. Your recording is preserved. Tap Retry Evaluation to submit.';
        notifyListeners();
        return;
      }
    }

    await _finalizeSessionUpload(audioPath, onComplete);
  }

  /// Retries evaluating the turn answer if connection failed mid-turn.
  Future<void> retryTurnEvaluation(
    void Function(String? sessionId) onComplete,
  ) async {
    if (_pendingTurnAudioPath == null) return;
    final audioPath = _pendingTurnAudioPath;
    _phase = RecordingPhase.uploading;
    _isThinking = true;
    _errorMessage = null;
    _turnEvaluationFailed = false;
    notifyListeners();

    final sw = Stopwatch()..start();
    try {
      final evalResult = await _multiTurnRepo.evaluateTurnAudio(
        audioPath: audioPath!,
        question: _currentFollowUp ?? currentPrompt.text,
        turnHistory: _dialogueTurns,
        followUpCount: _followUpCount,
      );
      sw.stop();
      _lastTurnLatencyMs =
          evalResult.latencyMs ?? sw.elapsedMilliseconds.toDouble();
      _pendingTurnAudioPath = null;

      if (!evalResult.moveOn &&
          evalResult.followUp != null &&
          _followUpCount < 2) {
        _followUpCount++;
        _currentFollowUp = evalResult.followUp;
        _interviewerReason = evalResult.reason;
        _dialogueTurns.add(
          TurnMessage(
            role: TurnRole.candidate,
            content: evalResult.transcription ?? 'Candidate answer',
          ),
        );
        _dialogueTurns.add(
          TurnMessage(
            role: TurnRole.interviewer,
            content: evalResult.followUp!,
          ),
        );
        _isThinking = false;
        _phase = RecordingPhase.idle;
        notifyListeners();
        if (_ttsService.isEnabled) {
          _ttsService.speak(evalResult.followUp!);
        }
        return;
      }

      _dialogueTurns.add(
        TurnMessage(
          role: TurnRole.candidate,
          content: evalResult.transcription ?? 'Candidate answer',
        ),
      );

      try {
        _exchangeScore = await _multiTurnRepo.scoreExchange(
          question: currentPrompt.text,
          turns: _dialogueTurns,
        );
      } catch (_) {}

      _isThinking = false;
      notifyListeners();
      await _finalizeSessionUpload(audioPath, onComplete);
    } catch (e) {
      sw.stop();
      _isThinking = false;
      _phase = RecordingPhase.failed;
      _turnEvaluationFailed = true;
      _pendingTurnAudioPath = audioPath;
      _errorMessage =
          'Retry failed. Your recording is preserved. Tap Retry to try again.';
      notifyListeners();
    }
  }

  /// Concludes multi-turn dialogue early and scores current turns.
  Future<void> skipFollowUpAndFinish(
    void Function(String? sessionId) onComplete,
  ) async {
    if (isRecording) {
      await stopRecording(onComplete);
      return;
    }
    _phase = RecordingPhase.uploading;
    notifyListeners();

    try {
      if (_dialogueTurns.isNotEmpty) {
        _exchangeScore = await _multiTurnRepo.scoreExchange(
          question: currentPrompt.text,
          turns: _dialogueTurns,
        );
      }
    } catch (_) {}

    await _finalizeSessionUpload(_activeAudioPath, onComplete);
  }

  Future<void> _finalizeSessionUpload(
    String? audioPath,
    void Function(String? sessionId) onComplete,
  ) async {
    final effectiveSessionId = _sessionId ?? const Uuid().v4();
    _sessionId = effectiveSessionId;
    _activeAudioPath = audioPath;

    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tzOffsetMinutes = now.timeZoneOffset.inMinutes;
    final userId = LocalDatabaseService.instance.currentUserId ?? 'user';

    // 1. Insert local session_metrics row with status='pending'
    if (LocalDatabaseService.instance.isOpen) {
      try {
        await LocalDatabaseService.instance.upsertSessionMetric({
          'id': effectiveSessionId,
          'user_id': userId,
          'mode': _currentMode.id,
          'topic_or_question': currentPrompt.text,
          'duration_seconds': _elapsedSeconds.toDouble(),
          'wpm': 0.0,
          'filler_word_count': 0,
          'pause_count': 0,
          'avg_pause_length': 0.0,
          'clarity_score': _exchangeScore?.clarityScore ?? 0.0,
          'confidence_score': _exchangeScore?.confidenceScore ?? 0.0,
          'overall_score': _exchangeScore?.overallScore ?? 0.0,
          'status': 'pending',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'local_date': localDate,
          'tz_offset_minutes': tzOffsetMinutes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });

        // 2. Insert sync_outbox row (CREATE_SESSION)
        await LocalDatabaseService.instance.enqueueOutbox(
          id: effectiveSessionId,
          userId: userId,
          action: 'CREATE_SESSION',
          payload: jsonEncode({
            'mode': _currentMode.id,
            'topic_or_question': currentPrompt.text,
            'duration_seconds': _elapsedSeconds.toDouble(),
            'local_date': localDate,
            'tz_offset_minutes': tzOffsetMinutes,
            'parent_session_id': parentSessionId,
            'template_id': _selectedTemplate?.id,
          }),
          localAudioPath: audioPath,
        );
      } catch (e) {
        debugPrint(
          '[InterviewSessionController] Error saving pending session to SQLite: $e',
        );
      }
    }

    // Also register in legacy upload queue for file backup
    if (audioPath != null) {
      await _uploadQueue.enqueue(
        sessionId: effectiveSessionId,
        audioPath: audioPath,
        durationSeconds: _elapsedSeconds.toDouble(),
        mode: _currentMode.id,
        topicOrQuestion: currentPrompt.text,
      );
    }

    // 3. Process via OutboxWorker
    try {
      await OutboxWorker.instance.process(userId: userId);

      // Check if outbox item succeeded
      bool isStillQueued = false;
      if (LocalDatabaseService.instance.isOpen) {
        final pending = await LocalDatabaseService.instance.getPendingOutbox(
          userId,
        );
        isStillQueued = pending.any((i) => i['id'] == effectiveSessionId);
      }

      if (!isStillQueued) {
        _phase = RecordingPhase.idle;
        _failedAudioPath = null;
        _failedSessionId = null;
        notifyListeners();
        onComplete(effectiveSessionId);
      } else {
        _phase = RecordingPhase.failed;
        _failedSessionId = effectiveSessionId;
        _failedAudioPath = audioPath;
        _errorMessage =
            'Waiting to sync. Your recording is safely saved and will upload automatically.';
        notifyListeners();
      }
    } catch (e) {
      _phase = RecordingPhase.failed;
      _failedSessionId = effectiveSessionId;
      _failedAudioPath = audioPath;
      _errorMessage =
          'Waiting to sync. Your recording is safely saved on this device.';
      notifyListeners();
    }
  }

  /// Retries uploading the saved failed recording.
  Future<void> retryUpload(void Function(String? sessionId) onComplete) async {
    if (_failedAudioPath == null && _failedSessionId == null) return;

    _phase = RecordingPhase.uploading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_failedSessionId != null) {
        await OutboxWorker.instance.retry(_failedSessionId!);
        final userId = LocalDatabaseService.instance.currentUserId ?? 'user';
        final pending = await LocalDatabaseService.instance.getPendingOutbox(
          userId,
        );
        final isStillQueued = pending.any((i) => i['id'] == _failedSessionId);

        if (!isStillQueued) {
          _phase = RecordingPhase.idle;
          _failedAudioPath = null;
          _failedSessionId = null;
          notifyListeners();
          onComplete(_failedSessionId);
          return;
        }
      }

      // Fallback: legacy queue retry
      if (_failedAudioPath != null) {
        final queued = await _uploadQueue.getPendingUploads();
        final item = queued.firstWhere(
          (i) => i.audioPath == _failedAudioPath,
          orElse: () => PendingUploadItem(
            id:
                _failedSessionId ??
                'retry_${DateTime.now().millisecondsSinceEpoch}',
            sessionId: _failedSessionId,
            audioPath: _failedAudioPath!,
            durationSeconds: _elapsedSeconds.toDouble(),
            mode: _currentMode.id,
            topicOrQuestion: currentPrompt.text,
            createdAt: DateTime.now(),
          ),
        );
        final result = await _uploadQueue.retryUpload(item);
        _phase = RecordingPhase.idle;
        _failedAudioPath = null;
        _failedSessionId = null;
        notifyListeners();
        onComplete(result.id);
      }
    } catch (e) {
      _phase = RecordingPhase.failed;
      _errorMessage =
          'Retry failed: $e. You can try again or wait for network.';
      notifyListeners();
    }
  }

  /// Discards the failed take and cleans up local storage.
  Future<void> discardFailedRecording() async {
    if (_failedSessionId != null && LocalDatabaseService.instance.isOpen) {
      await LocalDatabaseService.instance.deleteOutbox(_failedSessionId!);
    }
    if (_failedAudioPath != null) {
      await _uploadQueue.remove(_failedSessionId ?? '', deleteAudio: true);
    }
    _phase = RecordingPhase.idle;
    _failedAudioPath = null;
    _failedSessionId = null;
    _errorMessage = null;
    _durationWarning = null;
    _elapsedSeconds = 0;
    notifyListeners();
  }

  /// Cancels an in-progress recording take and removes local audio.
  Future<void> cancelRecording() async {
    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _sessionRepo.cancelSession();

    _phase = RecordingPhase.idle;
    _elapsedSeconds = 0;
    _durationWarning = null;
    _errorMessage = null;
    _audioLevel = 0.0;
    notifyListeners();
  }

  /// Safely pauses or saves take if app is backgrounded or a phone call arrives.
  Future<void> handleAppInterruption() async {
    if (isRecording) {
      _timer?.cancel();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      try {
        final path = await _sessionRepo.stopAudioRecorder();
        if (path != null && _elapsedSeconds >= minRecordingSeconds) {
          _failedAudioPath = path;
          _failedSessionId = _sessionId;
          await _uploadQueue.enqueue(
            sessionId: _sessionId,
            audioPath: path,
            durationSeconds: _elapsedSeconds.toDouble(),
            mode: _currentMode.id,
            topicOrQuestion: currentPrompt.text,
            error: 'Interrupted by app backgrounding / phone call',
          );
          _phase = RecordingPhase.failed;
          _errorMessage =
              'Recording paused because the app was interrupted. Your take is saved and ready to upload.';
        } else {
          await _sessionRepo.cancelSession();
          _phase = RecordingPhase.idle;
        }
      } catch (_) {
        _phase = RecordingPhase.idle;
      }
      notifyListeners();
    }
  }

  Future<void> openSettings() async {
    await _sessionRepo.openSettings();
  }

  @override
  void dispose() {
    _ttsService.removeListener(notifyListeners);
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _bloc?.close();
    super.dispose();
  }
}
