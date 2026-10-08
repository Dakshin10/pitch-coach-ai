import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../../core/models/practice_mode.dart';
import '../../../core/repositories/session_repository.dart';
import '../../../core/services/upload_queue_service.dart';

enum RecordingPhase {
  idle,
  recording,
  uploading,
  failed,
  permissionDenied,
}

/// State Controller managing practice modes, audio recording lifecycle,
/// clip constraints, upload resilience, and mic permissions.
class InterviewSessionController extends ChangeNotifier {
  final bool isGuest;
  final _sessionRepo = SessionRepository.instance;
  final _uploadQueue = UploadQueueService.instance;

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

  InterviewSessionController({
    required this.isGuest,
    PracticeSessionConfig? initialConfig,
  }) {
    if (initialConfig != null) {
      _currentMode = initialConfig.mode;
      final idx = _currentMode.prompts.indexWhere((p) => p.id == initialConfig.prompt.id);
      _promptIndex = idx >= 0 ? idx : 0;
    } else {
      _currentMode = PracticeMode.allModes.first;
      _promptIndex = 0;
    }
  }

  // Getters
  PracticeMode get currentMode => _currentMode;
  int get promptIndex => _promptIndex;
  PracticePrompt get currentPrompt => _currentMode.prompts[_promptIndex];
  int get totalPrompts => _currentMode.prompts.length;

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

  String get formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── Mode and Prompt Selection ─────────────────────────────────────────────

  void switchMode(String modeId) {
    if (isRecording || isUploading) return;
    _currentMode = PracticeMode.fromId(modeId);
    _promptIndex = 0;
    _durationWarning = null;
    _errorMessage = null;
    notifyListeners();
  }

  void nextPrompt() {
    if (isRecording || isUploading) return;
    _promptIndex = (_promptIndex + 1) % _currentMode.prompts.length;
    notifyListeners();
  }

  void previousPrompt() {
    if (isRecording || isUploading) return;
    _promptIndex = (_promptIndex - 1 + _currentMode.prompts.length) % _currentMode.prompts.length;
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
        );
      }
      _activeAudioPath = _sessionRepo.currentAudioPath;
      _phase = RecordingPhase.recording;

      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _sessionRepo.amplitudeStream.listen((amp) {
        _audioLevel = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        notifyListeners();
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsedSeconds++;

        // Warning when approaching 5 minutes limit
        if (_elapsedSeconds >= maxRecordingSeconds) {
          _durationWarning = 'Maximum 5 minute limit reached. Processing recording...';
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
      _errorMessage = 'Could not start microphone recording. Please check audio permissions.';
      notifyListeners();
    }
  }

  void _autoStopAtMax() {
    stopRecording((_) {});
  }

  /// Stops recording and uploads for AI coaching.
  Future<void> stopRecording(void Function(String? sessionId) onComplete) async {
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

    String? resolvedSessionId = _sessionId;
    try {
      if (isGuest) {
        await _sessionRepo.finishDemoRecording();
        _phase = RecordingPhase.idle;
        notifyListeners();
        onComplete(null);
      } else {
        final result = await _sessionRepo.finishSession(_elapsedSeconds.toDouble());
        resolvedSessionId = result?.id ?? _sessionId;
        _phase = RecordingPhase.idle;
        _failedAudioPath = null;
        _failedSessionId = null;
        notifyListeners();
        onComplete(resolvedSessionId);
      }
    } catch (e) {
      // Keep local file and register to offline upload queue
      _phase = RecordingPhase.failed;
      _failedSessionId = _sessionId;
      _failedAudioPath = _activeAudioPath ?? _sessionRepo.currentAudioPath;
      _errorMessage =
          'Upload failed due to connection issues. Your recording is safely saved on this device.';

      if (_failedAudioPath != null) {
        await _uploadQueue.enqueue(
          sessionId: _failedSessionId,
          audioPath: _failedAudioPath!,
          durationSeconds: _elapsedSeconds.toDouble(),
          mode: _currentMode.id,
          topicOrQuestion: currentPrompt.text,
          error: e.toString(),
        );
      }
      notifyListeners();
    }
  }

  /// Retries uploading the saved failed recording.
  Future<void> retryUpload(void Function(String? sessionId) onComplete) async {
    if (_failedAudioPath == null) return;

    _phase = RecordingPhase.uploading;
    _errorMessage = null;
    notifyListeners();

    try {
      final queued = await _uploadQueue.getPendingUploads();
      final item = queued.firstWhere(
        (i) => i.audioPath == _failedAudioPath,
        orElse: () => PendingUploadItem(
          id: _failedSessionId ?? 'retry_${DateTime.now().millisecondsSinceEpoch}',
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
    } catch (e) {
      _phase = RecordingPhase.failed;
      _errorMessage = 'Retry failed: $e. You can try again or save for later.';
      notifyListeners();
    }
  }

  /// Discards the failed take and cleans up local storage.
  Future<void> discardFailedRecording() async {
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
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }
}
