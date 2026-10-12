import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/lesson_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _controller = null;

    final candidateUrls = [
      widget.lesson.videoUrl,
      'https://vjs.zencdn.net/v/oceans.mp4',
    ];

    for (final url in candidateUrls) {
      if (!mounted) return;
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        _controller = controller;
        controller.addListener(_onVideoUpdate);
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        return;
      } catch (e) {
        debugPrint('Video init failed for $url: $e');
      }
    }

    if (mounted) setState(() => _hasError = true);
  }

  void _onVideoUpdate() {
    final ctrl = _controller;
    if (mounted && ctrl != null) {
      final playing = ctrl.value.isPlaying;
      if (playing != _isPlaying) {
        setState(() => _isPlaying = playing);
      }
    }
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
    setState(() => _isPlaying = ctrl.value.isPlaying);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
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
                    'Lesson',
                    style: AppTextStyles.headingMOf(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const ThemeToggleButton(size: 38, compact: true),
                ],
              ),
            ),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── VIDEO PLAYER ──────────────────────────────────────
                    _buildVideoPlayer(),

                    const SizedBox(height: 20),

                    // ── Lesson Title ─────────────────────────────────────
                    Text(
                      widget.lesson.title,
                      style: AppTextStyles.headingXLOf(
                        context,
                      ).copyWith(fontSize: 22),
                    ),

                    const SizedBox(height: 4),

                    // Category + Duration row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _capitalize(widget.lesson.category),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.lesson.duration,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Description ──────────────────────────────────────
                    Text(
                      widget.lesson.description,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Key Takeaways ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderOf(context)),
                        boxShadow: AppColors.softShadowOf(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_rounded,
                                color: AppColors.warningAmber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Key Takeaways',
                                style: AppTextStyles.headingMOf(
                                  context,
                                ).copyWith(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...widget.lesson.takeaways.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppColors.successGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t,
                                      style: AppTextStyles.bodyMOf(context)
                                          .copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13.5,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Practice This Skill Button ────────────────────────
                    GradientButton(
                      text: 'Practice This Skill',
                      icon: Icons.mic_rounded,
                      onPressed: () => context.push('/interview'),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video or placeholder
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio > 0
                      ? _controller!.value.aspectRatio
                      : (16 / 9),
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_hasError)
            _buildVideoError()
          else
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryPurple,
              ),
            ),

          // Play/Pause overlay
          if (_isInitialized)
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlay,
                behavior: HitTestBehavior.translucent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom progress + controls bar
          if (_isInitialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildVideoControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress slider
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller!,
            builder: (context, value, child) {
              final position = value.position;
              final duration = value.duration;
              final progress = duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      activeTrackColor: AppColors.primaryPurple,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                      thumbColor: Colors.white,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (val) {
                        final seekTo = Duration(
                          milliseconds: (val * duration.inMilliseconds).toInt(),
                        );
                        _controller?.seekTo(seekTo);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 40),
        const SizedBox(height: 8),
        const Text(
          'Could not load video',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _isInitialized = false;
              _hasError = false;
            });
            _initVideo();
          },
          child: const Text(
            'Retry',
            style: TextStyle(color: AppColors.primaryPurple),
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
