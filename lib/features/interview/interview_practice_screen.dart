import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/session_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/circular_gauge_painter.dart';

/// State Controller managing speech analysis metrics and session timers.
class InterviewSessionController extends ChangeNotifier {
  Timer? _timer;
  final bool isGuest;

  InterviewSessionController({required this.isGuest});

  int _elapsedSeconds = 0;
  double _confidenceScore = 0;
  int _fillerWordsCount = 0;
  int _speakingSpeedWpm = 0;
  int _pausesCount = 0;
  int _clarityPercentage = 0;
  String _liveMessage = 'Preparing your recording...';
  String? _errorMessage;
  bool _isProcessing = false;

  int get elapsedSeconds => _elapsedSeconds;
  double get confidenceScore => _confidenceScore;
  int get fillerWordsCount => _fillerWordsCount;
  int get speakingSpeedWpm => _speakingSpeedWpm;
  int get pausesCount => _pausesCount;
  int get clarityPercentage => _clarityPercentage;
  String get liveMessage => _liveMessage;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  String get formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── Recording state ──────────────────────────────────────────────────────
  String? _sessionId;
  final _sessionRepo = SessionRepository.instance;

  String? get sessionId => _sessionId;

  Future<void> startSession() async {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _errorMessage = null;

    try {
      if (isGuest) {
        _sessionId = 'demo-session';
      } else {
        final hasPermission = await _sessionRepo.requestMicPermission();
        if (!hasPermission) {
          _errorMessage = 'Microphone permission was denied. Enable it in Settings to practice.';
          _liveMessage = _errorMessage!;
          notifyListeners();
          return;
        }
        _sessionId = await _sessionRepo.startSession(
            mode: 'interview', topicOrQuestion: 'Tell me about yourself.');
      }
    } catch (e) {
      _errorMessage = 'Unable to start recording. Check your microphone permission and connection.';
      _liveMessage = _errorMessage!;
      notifyListeners();
      return;
    }

    // Start elapsed-time timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });

    _liveMessage = isGuest
        ? 'Demo recording in progress.'
        : 'Recording. Analysis starts after upload.';
    notifyListeners();
  }

  Future<void> stopSession(void Function(String? sessionId) onComplete) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    _timer?.cancel();
    String? resolvedSessionId = _sessionId;
    try {
      if (isGuest) {
        resolvedSessionId = null;
      } else if (_sessionId != null) {
        // Upload audio — pipeline runs in background on server
        final result = await _sessionRepo.finishSession(
          _elapsedSeconds.toDouble(),
        );
        resolvedSessionId = result?.id ?? _sessionId;
      }
    } catch (e) {
      _errorMessage = 'We could not upload your recording. Check your connection and try again.';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }

    if (_errorMessage == null) onComplete(resolvedSessionId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class InterviewPracticeScreen extends StatelessWidget {
  const InterviewPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final ctrl = InterviewSessionController(
          isGuest: context.read<UserProvider>().isGuest,
        );
        // Start async — must not await in create callback
        ctrl.startSession();
        return ctrl;
      },
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
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InterviewSessionController>();

    return Scaffold(
      backgroundColor: AppColors.background, // Dark Navy Background matching reference image
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // 1. Top App Bar (Dark Theme)
              _buildTopAppBar(context, controller),

              const SizedBox(height: 16),

              // 2. Question Prompt Area (White text on dark)
              _buildQuestionPromptArea(),

              const SizedBox(height: 16),

              // 3. Live Feedback Card & Stat Grid (Dark Cards)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildLiveFeedbackCard(controller),

                      const SizedBox(height: 16),

                      // 4. 2x2 Grid of Stat Cards with Dark Background & Green Sparklines
                      controller.isGuest
                          ? _buildStatCardGrid(controller)
                          : _buildPostRecordingNotice(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 5. Bottom Recording Control & Waveform
              _buildBottomRecordingControl(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(
    BuildContext context,
    InterviewSessionController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back Chevron Button
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 36,
            height: 36,
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

        // Title in White Text
        Text(
          'Interview Practice',
          style: AppTextStyles.headingM.copyWith(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
          ),
        ),

        // Timer Badge Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            controller.formattedTime,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.primaryPurpleLight,
              fontWeight: FontWeight.w700,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionPromptArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell me about yourself.',
          style: AppTextStyles.headingL.copyWith(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (index) {
            final isCurrent = index == 1; // 2nd dot active per prompt specification
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: isCurrent ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primaryPurpleLight
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLiveFeedbackCard(InterviewSessionController controller) {
    if (!controller.isGuest) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            const Icon(Icons.graphic_eq_rounded,
                color: AppColors.primaryPurpleLight, size: 42),
            const SizedBox(height: 12),
            Text('Recording your practice',
                style: AppTextStyles.headingM.copyWith(color: AppColors.textOnDark)),
            const SizedBox(height: 8),
            Text(controller.liveMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row: "Live Feedback" + Pulsing Recording Dot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Feedback',
                style: AppTextStyles.headingM.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.dangerRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Recording',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.dangerRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Animated Big Circular Gauge Ring (Dark background track)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 60.0,
              end: controller.confidenceScore,
            ),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return CircularGauge(
                value: val,
                size: 190,
                strokeWidth: 12,
                centerBigText: '${val.round()}',
                centerSmallLabel: 'Confidence',
                trackColor: const Color(0xFF232042),
                gradientColors: const [
                  AppColors.primaryPurpleLight,
                  AppColors.primaryPurple,
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // Status Line with AnimatedSwitcher Fade Transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: Text(
              controller.liveMessage,
              key: ValueKey(controller.liveMessage),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.primaryPurpleLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardGrid(InterviewSessionController controller) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildDarkSparklineStatCard(
                label: 'Filler Words',
                value: '${controller.fillerWordsCount}',
                status: 'Good',
                statusColor: AppColors.successGreen,
                sparklineData: const [0.6, 0.4, 0.5, 0.3, 0.2, 0.3, 0.2],
              ),
              const SizedBox(height: 12),
              _buildDarkSparklineStatCard(
                label: 'Pauses',
                value: '${controller.pausesCount}',
                status: 'Good',
                statusColor: AppColors.successGreen,
                sparklineData: const [0.3, 0.5, 0.4, 0.6, 0.3, 0.4, 0.3],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildDarkSparklineStatCard(
                label: 'Speaking Speed',
                value: '${controller.speakingSpeedWpm}',
                unit: 'WPM',
                status: 'Optimal',
                statusColor: AppColors.successGreen,
                sparklineData: const [0.4, 0.6, 0.7, 0.65, 0.8, 0.75, 0.85],
              ),
              const SizedBox(height: 12),
              _buildDarkSparklineStatCard(
                label: 'Clarity',
                value: '${controller.clarityPercentage}%',
                status: 'Good',
                statusColor: AppColors.successGreen,
                sparklineData: const [0.7, 0.75, 0.8, 0.78, 0.82, 0.85, 0.88],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostRecordingNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        'Live metrics are not shown because the connected backend analyzes the completed recording. Stop when you are ready to upload for real AI feedback.',
        style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildDarkSparklineStatCard({
    required String label,
    required String value,
    String? unit,
    required String status,
    required Color statusColor,
    required List<double> sparklineData,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.headingXL.copyWith(
                      color: AppColors.textOnDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: CustomPaint(
              size: const Size(42, 22),
              painter: _SparklinePainter(
                values: sparklineData,
                color: statusColor.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRecordingControl(
    BuildContext context,
    InterviewSessionController controller,
  ) {
    return Column(
      children: [
        // Horizontal Waveform Strip
        const _AudioWaveformStrip(),

        const SizedBox(height: 12),

        // Large Circular Stop Button (72px)
        GestureDetector(
          onTap: () async {
            await controller.stopSession((sessionId) {
              context.push('/results', extra: sessionId);
            });
            if (context.mounted && controller.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(controller.errorMessage!),
                backgroundColor: AppColors.dangerRed,
              ));
            }
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: controller.isProcessing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Home indicator handle pill (iOS style bar)
        Container(
          width: 120,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final dx = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - (values[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}

class _AudioWaveformStrip extends StatefulWidget {
  const _AudioWaveformStrip();

  @override
  State<_AudioWaveformStrip> createState() => _AudioWaveformStripState();
}

class _AudioWaveformStripState extends State<_AudioWaveformStrip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(40, (index) {
              final phase = (index * 0.1) % 1.0;
              final animVal =
                  (Curves.easeInOut.transform((_controller.value + phase) % 1.0));
              final height = 6.0 + 26.0 * animVal;
              final opacity = 0.35 + 0.65 * animVal;

              return Container(
                width: 3.0,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurpleLight.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
