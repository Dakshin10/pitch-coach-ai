import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/practice_mode.dart';
import '../../../core/repositories/session_repository.dart';
import '../../../core/services/upload_queue_service.dart';
import '../controllers/interview_session_controller.dart' show RecordingPhase;

// ─────────────────────────────────────────────────────────────────────────────
// Events
// ─────────────────────────────────────────────────────────────────────────────

abstract class PracticeSessionEvent extends Equatable {
  const PracticeSessionEvent();

  @override
  List<Object?> get props => [];
}

class InitPracticeSessionEvent extends PracticeSessionEvent {
  final bool isGuest;
  final PracticeSessionConfig? config;

  const InitPracticeSessionEvent({required this.isGuest, this.config});

  @override
  List<Object?> get props => [isGuest, config?.modeId, config?.prompt.id];
}

class SwitchPracticeModeEvent extends PracticeSessionEvent {
  final String modeId;

  const SwitchPracticeModeEvent(this.modeId);

  @override
  List<Object?> get props => [modeId];
}

class NextPromptEvent extends PracticeSessionEvent {
  const NextPromptEvent();
}

class PreviousPromptEvent extends PracticeSessionEvent {
  const PreviousPromptEvent();
}

class StartRecordingEvent extends PracticeSessionEvent {
  const StartRecordingEvent();
}

class StopRecordingEvent extends PracticeSessionEvent {
  const StopRecordingEvent();
}

class CancelRecordingEvent extends PracticeSessionEvent {
  const CancelRecordingEvent();
}

class RetryUploadEvent extends PracticeSessionEvent {
  const RetryUploadEvent();
}

class RecordingTickEvent extends PracticeSessionEvent {
  final int elapsedSeconds;

  const RecordingTickEvent(this.elapsedSeconds);

  @override
  List<Object?> get props => [elapsedSeconds];
}

class AudioLevelChangedEvent extends PracticeSessionEvent {
  final double level;

  const AudioLevelChangedEvent(this.level);

  @override
  List<Object?> get props => [level];
}

class DurationWarningEvent extends PracticeSessionEvent {
  final String warning;

  const DurationWarningEvent(this.warning);

  @override
  List<Object?> get props => [warning];
}

class RecordingErrorEvent extends PracticeSessionEvent {
  final String errorMessage;

  const RecordingErrorEvent(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class PracticeSessionState extends Equatable {
  final PracticeMode currentMode;
  final int promptIndex;
  final RecordingPhase phase;
  final int elapsedSeconds;
  final double audioLevel;
  final String? durationWarning;
  final String? errorMessage;
  final String? sessionId;
  final String? activeAudioPath;
  final MicPermissionState micPermissionState;
  final bool isGuest;
  final String? parentSessionId;

  const PracticeSessionState({
    required this.currentMode,
    this.promptIndex = 0,
    this.phase = RecordingPhase.idle,
    this.elapsedSeconds = 0,
    this.audioLevel = 0.0,
    this.durationWarning,
    this.errorMessage,
    this.sessionId,
    this.activeAudioPath,
    this.micPermissionState = MicPermissionState.granted,
    this.isGuest = false,
    this.parentSessionId,
  });

  PracticePrompt get currentPrompt => currentMode.prompts[promptIndex];
  int get totalPrompts => currentMode.prompts.length;
  bool get hasPreviousPrompt => promptIndex > 0;
  bool get hasNextPrompt => promptIndex < currentMode.prompts.length - 1;

  bool get isRecording => phase == RecordingPhase.recording;
  bool get isUploading => phase == RecordingPhase.uploading;
  bool get isFailed => phase == RecordingPhase.failed;
  bool get isPermissionDenied => phase == RecordingPhase.permissionDenied;

  String get formattedTime {
    final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  factory PracticeSessionState.initial({
    bool isGuest = false,
    PracticeSessionConfig? config,
  }) {
    final mode = config != null ? config.mode : PracticeMode.allModes.first;
    int index = 0;
    if (config != null) {
      final found = mode.prompts.indexWhere((p) => p.id == config.prompt.id);
      index = found >= 0 ? found : 0;
    }
    return PracticeSessionState(
      currentMode: mode,
      promptIndex: index,
      isGuest: isGuest,
      parentSessionId: config?.parentSessionId,
    );
  }

  PracticeSessionState copyWith({
    PracticeMode? currentMode,
    int? promptIndex,
    RecordingPhase? phase,
    int? elapsedSeconds,
    double? audioLevel,
    String? durationWarning,
    String? errorMessage,
    String? sessionId,
    String? activeAudioPath,
    MicPermissionState? micPermissionState,
    bool? isGuest,
    String? parentSessionId,
  }) {
    return PracticeSessionState(
      currentMode: currentMode ?? this.currentMode,
      promptIndex: promptIndex ?? this.promptIndex,
      phase: phase ?? this.phase,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      audioLevel: audioLevel ?? this.audioLevel,
      durationWarning: durationWarning,
      errorMessage: errorMessage,
      sessionId: sessionId ?? this.sessionId,
      activeAudioPath: activeAudioPath ?? this.activeAudioPath,
      micPermissionState: micPermissionState ?? this.micPermissionState,
      isGuest: isGuest ?? this.isGuest,
      parentSessionId: parentSessionId ?? this.parentSessionId,
    );
  }

  @override
  List<Object?> get props => [
    currentMode.id,
    promptIndex,
    phase,
    elapsedSeconds,
    audioLevel,
    durationWarning,
    errorMessage,
    sessionId,
    activeAudioPath,
    micPermissionState,
    isGuest,
    parentSessionId,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLoC
// ─────────────────────────────────────────────────────────────────────────────

class PracticeSessionBloc
    extends Bloc<PracticeSessionEvent, PracticeSessionState> {
  final SessionRepository _sessionRepo;
  final UploadQueueService _uploadQueue;

  Timer? _timer;
  StreamSubscription<dynamic>? _amplitudeSub;

  static const int minRecordingSeconds = 5;
  static const int maxRecordingSeconds = 300;
  static const int warningThresholdSeconds = 270;

  PracticeSessionBloc({
    SessionRepository? sessionRepository,
    UploadQueueService? uploadQueueService,
    bool isGuest = false,
    PracticeSessionConfig? initialConfig,
  }) : _sessionRepo = sessionRepository ?? SessionRepository.instance,
       _uploadQueue = uploadQueueService ?? UploadQueueService.instance,
       super(
         PracticeSessionState.initial(isGuest: isGuest, config: initialConfig),
       ) {
    on<InitPracticeSessionEvent>(_onInit);
    on<SwitchPracticeModeEvent>(_onSwitchMode);
    on<NextPromptEvent>(_onNextPrompt);
    on<PreviousPromptEvent>(_onPreviousPrompt);
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<CancelRecordingEvent>(_onCancelRecording);
    on<RetryUploadEvent>(_onRetryUpload);
    on<RecordingTickEvent>(_onRecordingTick);
    on<AudioLevelChangedEvent>(_onAudioLevelChanged);
    on<DurationWarningEvent>(_onDurationWarning);
    on<RecordingErrorEvent>(_onRecordingError);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    return super.close();
  }

  void _onInit(
    InitPracticeSessionEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    emit(
      PracticeSessionState.initial(
        isGuest: event.isGuest,
        config: event.config,
      ),
    );
  }

  void _onSwitchMode(
    SwitchPracticeModeEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    if (state.isRecording || state.isUploading) return;
    final newMode = PracticeMode.fromId(event.modeId);
    emit(
      state.copyWith(
        currentMode: newMode,
        promptIndex: 0,
        durationWarning: null,
        errorMessage: null,
      ),
    );
  }

  void _onNextPrompt(
    NextPromptEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    if (state.isRecording || state.isUploading) return;
    if (state.promptIndex < state.currentMode.prompts.length - 1) {
      emit(state.copyWith(promptIndex: state.promptIndex + 1));
    }
  }

  void _onPreviousPrompt(
    PreviousPromptEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    if (state.isRecording || state.isUploading) return;
    if (state.promptIndex > 0) {
      emit(state.copyWith(promptIndex: state.promptIndex - 1));
    }
  }

  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<PracticeSessionState> emit,
  ) async {
    if (state.isRecording || state.isUploading) return;

    final permStatus = await _sessionRepo.requestMicPermissionStatus();
    if (permStatus != MicPermissionState.granted) {
      emit(
        state.copyWith(
          phase: RecordingPhase.permissionDenied,
          micPermissionState: permStatus,
          errorMessage: permStatus == MicPermissionState.permanentlyDenied
              ? 'Microphone permission is permanently denied. Please enable it in Settings.'
              : 'Microphone permission was denied. Tap below to grant access.',
        ),
      );
      return;
    }

    try {
      String sessionId;
      if (state.isGuest) {
        await _sessionRepo.startDemoRecording();
        sessionId = 'demo-session';
      } else {
        final startedId = await _sessionRepo.startSession(
          mode: state.currentMode.id,
          topicOrQuestion: state.currentPrompt.text,
          parentSessionId: state.parentSessionId,
        );
        sessionId = startedId ?? const Uuid().v4();
      }

      emit(
        state.copyWith(
          phase: RecordingPhase.recording,
          elapsedSeconds: 0,
          audioLevel: 0.0,
          sessionId: sessionId,
          activeAudioPath: _sessionRepo.currentAudioPath,
          micPermissionState: MicPermissionState.granted,
          durationWarning: null,
          errorMessage: null,
        ),
      );

      await _amplitudeSub?.cancel();
      _amplitudeSub = _sessionRepo.amplitudeStream.listen((amp) {
        final level = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        add(AudioLevelChangedEvent(level));
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final nextSeconds = state.elapsedSeconds + 1;
        add(RecordingTickEvent(nextSeconds));
      });
    } catch (e) {
      emit(
        state.copyWith(
          phase: RecordingPhase.failed,
          errorMessage:
              'Could not start microphone recording. Please check audio permissions.',
        ),
      );
    }
  }

  void _onRecordingTick(
    RecordingTickEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    final nextSec = event.elapsedSeconds;
    String? warning;

    if (nextSec >= maxRecordingSeconds) {
      warning = 'Maximum 5 minute limit reached. Processing recording...';
      add(const StopRecordingEvent());
    } else if (nextSec >= warningThresholdSeconds) {
      final remaining = maxRecordingSeconds - nextSec;
      warning = 'Approaching 5m limit (${remaining}s remaining)';
    }

    emit(state.copyWith(elapsedSeconds: nextSec, durationWarning: warning));
  }

  void _onAudioLevelChanged(
    AudioLevelChangedEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    emit(state.copyWith(audioLevel: event.level));
  }

  void _onDurationWarning(
    DurationWarningEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    emit(state.copyWith(durationWarning: event.warning));
  }

  void _onRecordingError(
    RecordingErrorEvent event,
    Emitter<PracticeSessionState> emit,
  ) {
    emit(
      state.copyWith(
        phase: RecordingPhase.failed,
        errorMessage: event.errorMessage,
      ),
    );
  }

  Future<void> _onStopRecording(
    StopRecordingEvent event,
    Emitter<PracticeSessionState> emit,
  ) async {
    if (!state.isRecording) return;

    _timer?.cancel();
    await _amplitudeSub?.cancel();

    if (state.elapsedSeconds < minRecordingSeconds) {
      emit(
        state.copyWith(
          durationWarning:
              'Recording too short (minimum $minRecordingSeconds seconds required).',
        ),
      );
      return;
    }

    emit(state.copyWith(phase: RecordingPhase.uploading));

    try {
      if (state.isGuest) {
        final audioPath = await _sessionRepo.finishDemoRecording();
        emit(
          state.copyWith(
            phase: RecordingPhase.idle,
            activeAudioPath: audioPath,
          ),
        );
        return;
      }

      final audioPath = await _sessionRepo.stopAudioRecorder();
      if (state.sessionId != null && audioPath != null) {
        await _uploadQueue.enqueue(
          sessionId: state.sessionId!,
          audioPath: audioPath,
          durationSeconds: state.elapsedSeconds.toDouble(),
          mode: state.currentMode.id,
          topicOrQuestion: state.currentPrompt.text,
        );
      }

      emit(
        state.copyWith(phase: RecordingPhase.idle, activeAudioPath: audioPath),
      );
    } catch (e) {
      emit(
        state.copyWith(
          phase: RecordingPhase.failed,
          errorMessage: 'Failed to process audio recording.',
        ),
      );
    }
  }

  Future<void> _onCancelRecording(
    CancelRecordingEvent event,
    Emitter<PracticeSessionState> emit,
  ) async {
    _timer?.cancel();
    await _amplitudeSub?.cancel();

    try {
      await _sessionRepo.cancelSession();
    } catch (_) {}

    emit(
      state.copyWith(
        phase: RecordingPhase.idle,
        elapsedSeconds: 0,
        audioLevel: 0.0,
        durationWarning: null,
        errorMessage: null,
      ),
    );
  }

  Future<void> _onRetryUpload(
    RetryUploadEvent event,
    Emitter<PracticeSessionState> emit,
  ) async {
    if (state.activeAudioPath == null || state.sessionId == null) return;
    emit(state.copyWith(phase: RecordingPhase.uploading));
    try {
      await _uploadQueue.enqueue(
        sessionId: state.sessionId!,
        audioPath: state.activeAudioPath!,
        durationSeconds: state.elapsedSeconds.toDouble(),
        mode: state.currentMode.id,
        topicOrQuestion: state.currentPrompt.text,
      );
      emit(state.copyWith(phase: RecordingPhase.idle));
    } catch (e) {
      emit(
        state.copyWith(
          phase: RecordingPhase.failed,
          errorMessage: 'Retry failed: ${e.toString()}',
        ),
      );
    }
  }
}
