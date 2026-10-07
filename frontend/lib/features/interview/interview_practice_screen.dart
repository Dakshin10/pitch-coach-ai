import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../core/models/practice_mode.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/services/upload_queue_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

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
    // Automatically stop and complete
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
      } else if (_sessionId != null) {
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

// ─────────────────────────────────────────────────────────────────────────────
// Screen UI
// ─────────────────────────────────────────────────────────────────────────────

class InterviewPracticeScreen extends StatelessWidget {
  final PracticeSessionConfig? initialConfig;

  const InterviewPracticeScreen({
    super.key,
    this.initialConfig,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => InterviewSessionController(
        isGuest: context.read<UserProvider>().isGuest,
        initialConfig: initialConfig,
      ),
      child: const _InterviewPracticeContent(),
    );
  }
}

class _InterviewPracticeContent extends StatefulWidget {
  const _InterviewPracticeContent();

  @override
  State<_InterviewPracticeContent> createState() =>
      __InterviewPracticeContentState();
}

class __InterviewPracticeContentState extends State<_InterviewPracticeContent>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Interruption handling for phone calls or switching away mid-recording
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final ctrl = context.read<InterviewSessionController>();
      if (ctrl.isRecording) {
        ctrl.handleAppInterruption();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeaveMidRecording(InterviewSessionController ctrl) async {
    if (!ctrl.isRecording) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDarkElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard Recording?',
          style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
        ),
        content: Text(
          'Leaving now will cancel your active recording. Are you sure you want to discard this take?',
          style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep Recording', style: TextStyle(color: AppColors.primaryPurpleLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard & Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await ctrl.cancelRecording();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<InterviewSessionController>();

    return PopScope(
      canPop: !ctrl.isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final allow = await _confirmLeaveMidRecording(ctrl);
        if (allow && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              children: [
                // 1. Top bar with Mode Title, Back button, and Timer / Target pill
                _buildTopAppBar(context, ctrl),

                const SizedBox(height: 14),

                // 2. Mode selection tabs (only visible when idle)
                if (!ctrl.isRecording && !ctrl.isUploading)
                  _buildModeTabs(ctrl),

                const SizedBox(height: 14),

                // 3. Question Prompt Card (with real Question Bank navigation)
                _buildQuestionCard(ctrl),

                const SizedBox(height: 14),

                // 4. Central Stage: Live Waveform, Instructions, or Error Recovery
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildCentralStage(context, ctrl),
                  ),
                ),

                const SizedBox(height: 12),

                // 5. Bottom Controls (Record, Stop, Cancel, Retry)
                _buildBottomControls(context, ctrl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, InterviewSessionController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () async {
            if (ctrl.isRecording) {
              final allow = await _confirmLeaveMidRecording(ctrl);
              if (allow && context.mounted) context.pop();
            } else {
              context.pop();
            }
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              size: 26,
              color: AppColors.textOnDark,
            ),
          ),
        ),
        Text(
          ctrl.currentMode.title,
          style: AppTextStyles.headingM.copyWith(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        _TimerPill(
          time: ctrl.isRecording ? ctrl.formattedTime : '${ctrl.currentPrompt.targetDurationSeconds}s target',
          isActive: ctrl.isRecording,
        ),
      ],
    );
  }

  Widget _buildModeTabs(InterviewSessionController ctrl) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: PracticeMode.allModes.map((mode) {
          final isSelected = mode.id == ctrl.currentMode.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => ctrl.switchMode(mode.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryPurple.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryPurpleLight
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 16,
                      color: isSelected ? AppColors.primaryPurpleLight : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.title.replaceAll(' Practice', ''),
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected ? AppColors.textOnDark : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuestionCard(InterviewSessionController ctrl) {
    final prompt = ctrl.currentPrompt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Pill + Question Index ("Question X of Y")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prompt.category,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryPurpleLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                'Question ${ctrl.promptIndex + 1} of ${ctrl.totalPrompts}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Question Prompt Text
          Text(
            prompt.text,
            style: AppTextStyles.headingM.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              height: 1.35,
            ),
          ),

          if (prompt.hint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: AppColors.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prompt.hint,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Question Switcher (when not actively recording)
          if (!ctrl.isRecording && !ctrl.isUploading) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: ctrl.previousPrompt,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Previous'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: ctrl.nextPrompt,
                  icon: const Icon(Icons.shuffle_rounded, size: 16),
                  label: const Text('Next Prompt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurpleLight,
                    side: BorderSide(color: AppColors.primaryPurpleLight.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCentralStage(BuildContext context, InterviewSessionController ctrl) {
    if (ctrl.isPermissionDenied) {
      return _buildPermissionDeniedCard(ctrl);
    }

    if (ctrl.isFailed) {
      return _buildUploadFailedRecoveryCard(context, ctrl);
    }

    if (ctrl.isUploading) {
      return _buildUploadingCard();
    }

    if (ctrl.isRecording) {
      return _buildActiveRecordingCard(ctrl);
    }

    // Idle: Preparation State
    return _buildIdlePreparationCard(ctrl);
  }

  Widget _buildIdlePreparationCard(InterviewSessionController ctrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              color: AppColors.primaryPurpleLight,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ready to Rehearse',
            style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a breath, organize your key points, and tap the record button below when ready.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.primaryPurpleLight),
                const SizedBox(width: 8),
                Text(
                  'Recommended: ${ctrl.currentPrompt.targetDurationSeconds}s • Min: 5s • Max: 5m',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRecordingCard(InterviewSessionController ctrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ctrl.durationWarning != null
              ? AppColors.warningAmber.withValues(alpha: 0.4)
              : AppColors.primaryPurple.withValues(alpha: 0.2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Live Recording Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _pulseAnimation,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.dangerRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RECORDING IN PROGRESS',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Elapsed timer display
          Text(
            ctrl.formattedTime,
            style: AppTextStyles.headingXL.copyWith(
              color: AppColors.textOnDark,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(height: 18),

          // Real-time audio waveform strip
          _AudioWaveformVisualizer(level: ctrl.audioLevel),

          const SizedBox(height: 16),

          // Duration warning (if too short or approaching 5m)
          if (ctrl.durationWarning != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warningAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ctrl.durationWarning!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Speak clearly. Your audio will be sent to the AI pipeline upon stop.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurpleLight),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Uploading & Analyzing...',
            style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Transferring audio to server. Deep speech analysis will begin immediately.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedCard(InterviewSessionController ctrl) {
    final isPermanent = ctrl.micPermissionState == MicPermissionState.permanentlyDenied;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_off_rounded,
              color: AppColors.dangerRed,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Microphone Access Required',
            style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          Text(
            ctrl.errorMessage ??
                'Pitch Coach needs microphone permission to record your rehearsal and calculate confidence metrics.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPermanent)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: ctrl.openSettings,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Open Settings'),
                ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textOnDark,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: ctrl.startRecording,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadFailedRecoveryCard(
      BuildContext context, InterviewSessionController ctrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.warningAmber,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload Interrupted',
            style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          Text(
            ctrl.errorMessage ??
                'Network dropped during upload. Don\'t worry—your audio take is preserved safely on your phone.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => ctrl.retryUpload((sessionId) {
                  context.push('/results', extra: sessionId);
                }),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Upload'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerRed,
                  side: BorderSide(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onPressed: ctrl.discardFailedRecording,
                child: const Text('Discard Take'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, InterviewSessionController ctrl) {
    if (ctrl.isUploading) {
      return const SizedBox(height: 80);
    }

    if (ctrl.isRecording) {
      return Column(
        children: [
          // Stop Button
          GestureDetector(
            onTap: () => ctrl.stopRecording((sessionId) {
              context.push('/results', extra: sessionId);
            }),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.dangerRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dangerRed.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final allow = await _confirmLeaveMidRecording(ctrl);
              if (allow && context.mounted) {
                // Recording cancelled and reset
              }
            },
            child: Text(
              'Cancel take',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    // Idle: Big Record Button
    return GestureDetector(
      onTap: ctrl.startRecording,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolated UI Components
// ─────────────────────────────────────────────────────────────────────────────

class _TimerPill extends StatelessWidget {
  final String time;
  final bool isActive;

  const _TimerPill({
    required this.time,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryPurple.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.primaryPurpleLight.withValues(alpha: 0.6)
              : Colors.transparent,
        ),
      ),
      child: Text(
        time,
        style: AppTextStyles.bodySmallBold.copyWith(
          color: isActive ? AppColors.primaryPurpleLight : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _AudioWaveformVisualizer extends StatelessWidget {
  final double level;

  const _AudioWaveformVisualizer({required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(28, (index) {
          final distance = (index - 13.5).abs() / 13.5;
          final barLevel = (level * (1 - distance * 0.5)).clamp(0.05, 1.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 75),
            width: 3.5,
            height: 6 + 40 * barLevel,
            decoration: BoxDecoration(
              color: AppColors.primaryPurpleLight.withValues(
                alpha: (0.3 + 0.7 * barLevel).clamp(0.0, 1.0),
              ),
              borderRadius: BorderRadius.circular(2.5),
            ),
          );
        }),
      ),
    );
  }
}
