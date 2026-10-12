import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/practice_mode.dart';
import '../../core/providers/session_results_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/theme_toggle_button.dart';
import 'bloc/practice_session_bloc.dart';
export 'controllers/interview_session_controller.dart';
import 'controllers/interview_session_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen UI
// ─────────────────────────────────────────────────────────────────────────────

class InterviewPracticeScreen extends StatelessWidget {
  final PracticeSessionConfig? initialConfig;

  const InterviewPracticeScreen({super.key, this.initialConfig});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => InterviewSessionController(
        isGuest: context.read<UserProvider>().isGuest,
        initialConfig: initialConfig,
      ),
      child: Builder(
        builder: (context) {
          final ctrl = context.read<InterviewSessionController>();
          return BlocProvider<PracticeSessionBloc>.value(
            value: ctrl.bloc,
            child: const _InterviewPracticeContent(),
          );
        },
      ),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = context.read<InterviewSessionController>();
      ctrl.onAutoStop = (sessionId) {
        if (!mounted) return;
        if (sessionId != null) {
          context.read<SessionResultsProvider>().startBackgroundProcessing(
            sessionId: sessionId,
            topic: ctrl.currentPrompt.text,
            mode: ctrl.currentMode.id,
          );
          context.push('/results', extra: sessionId);
        } else {
          context.push('/results');
        }
      };
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Interruption handling for phone calls or switching away mid-recording
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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

  Future<bool> _confirmLeaveMidRecording(
    InterviewSessionController ctrl,
  ) async {
    if (!ctrl.isRecording) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderOf(context)),
        ),
        title: Text(
          'Discard Recording?',
          style: AppTextStyles.headingMOf(context),
        ),
        content: Text(
          'Leaving now will cancel your active recording. Are you sure you want to discard this take?',
          style: AppTextStyles.bodyMOf(
            context,
          ).copyWith(color: AppColors.textSecondaryOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep Recording',
              style: TextStyle(color: AppColors.primaryPurpleLight),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AppAtmosphere(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
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
      ),
    );
  }

  Widget _buildTopAppBar(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
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
              color: AppColors.iconButtonBgOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 26,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ),
        Text(
          ctrl.currentMode.title,
          style: AppTextStyles.headingMOf(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TimerPill(
              time: ctrl.isRecording
                  ? ctrl.formattedTime
                  : '${ctrl.currentPrompt.targetDurationSeconds}s target',
              isActive: ctrl.isRecording,
            ),
            const SizedBox(width: 8),
            const ThemeToggleButton(size: 38, compact: true),
          ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryPurple.withValues(alpha: 0.18)
                      : AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.borderOf(context),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 16,
                      color: isSelected
                          ? AppColors.primaryPurple
                          : AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.title.replaceAll(' Practice', ''),
                      style: AppTextStyles.captionOf(context).copyWith(
                        color: isSelected
                            ? AppColors.primaryPurple
                            : AppColors.textSecondaryOf(context),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
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
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Pill + Question Index ("Question X of Y")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prompt.category,
                  style: AppTextStyles.captionOf(context).copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                'Question ${ctrl.promptIndex + 1} of ${ctrl.totalPrompts}',
                style: AppTextStyles.captionOf(context).copyWith(
                  color: AppColors.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Question Prompt Text
          Text(
            prompt.text,
            style: AppTextStyles.headingMOf(
              context,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 18, height: 1.35),
          ),

          if (prompt.hint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtleOf(context),
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
                    side: BorderSide(
                      color: AppColors.primaryPurpleLight.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCentralStage(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
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
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
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
              color: AppColors.primaryPurple,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text('Ready to Rehearse', style: AppTextStyles.headingMOf(context)),
          const SizedBox(height: 8),
          Text(
            'Take a breath, organize your key points, and tap the record button below when ready.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMOf(
              context,
            ).copyWith(color: AppColors.textSecondaryOf(context), height: 1.35),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtleOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommended: ${ctrl.currentPrompt.targetDurationSeconds}s • Min: 5s • Max: 5m',
                  style: AppTextStyles.captionOf(
                    context,
                  ).copyWith(color: AppColors.textSecondaryOf(context)),
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
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ctrl.durationWarning != null
              ? AppColors.warningAmber.withValues(alpha: 0.4)
              : AppColors.primaryPurple.withValues(alpha: 0.3),
        ),
        boxShadow: AppColors.softShadowOf(context),
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
            style: AppTextStyles.headingXLOf(context).copyWith(
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
                border: Border.all(
                  color: AppColors.warningAmber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warningAmber,
                  ),
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
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
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
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Uploading & Analyzing...',
            style: AppTextStyles.headingMOf(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Transferring audio to server. Deep speech analysis will begin immediately.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMOf(
              context,
            ).copyWith(color: AppColors.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedCard(InterviewSessionController ctrl) {
    final isPermanent =
        ctrl.micPermissionState == MicPermissionState.permanentlyDenied;
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
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
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.warningAmber.withValues(alpha: 0.4),
        ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: () => ctrl.retryUpload((sessionId) {
                  if (sessionId != null && context.mounted) {
                    context
                        .read<SessionResultsProvider>()
                        .startBackgroundProcessing(
                          sessionId: sessionId,
                          topic: ctrl.currentPrompt.text,
                          mode: ctrl.currentMode.id,
                        );
                    context.push('/results', extra: sessionId);
                  } else if (context.mounted) {
                    context.push('/results');
                  }
                }),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Upload'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerRed,
                  side: BorderSide(
                    color: AppColors.dangerRed.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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

  Widget _buildBottomControls(
    BuildContext context,
    InterviewSessionController ctrl,
  ) {
    if (ctrl.isUploading) {
      return const SizedBox(height: 80);
    }

    if (ctrl.isRecording) {
      return Column(
        children: [
          // Stop Button
          GestureDetector(
            onTap: () => ctrl.stopRecording((sessionId) {
              if (sessionId != null && context.mounted) {
                context
                    .read<SessionResultsProvider>()
                    .startBackgroundProcessing(
                      sessionId: sessionId,
                      topic: ctrl.currentPrompt.text,
                      mode: ctrl.currentMode.id,
                    );
                context.push('/results', extra: sessionId);
              } else if (context.mounted) {
                context.push('/results');
              }
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
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
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
          child: Icon(Icons.mic_rounded, color: Colors.white, size: 36),
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

  const _TimerPill({required this.time, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryPurple.withValues(alpha: 0.18)
            : AppColors.surfaceSubtleOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.primaryPurple
              : AppColors.borderOf(context),
        ),
      ),
      child: Text(
        time,
        style: AppTextStyles.bodySmallBoldOf(context).copyWith(
          color: isActive
              ? AppColors.primaryPurple
              : AppColors.textSecondaryOf(context),
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
