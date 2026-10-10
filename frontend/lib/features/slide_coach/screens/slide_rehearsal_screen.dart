import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/models/slide_coach_models.dart';
import '../../../core/providers/slide_coach_provider.dart';
import '../../../core/repositories/slide_coach_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SlideRehearsalScreen extends StatefulWidget {
  const SlideRehearsalScreen({super.key});

  @override
  State<SlideRehearsalScreen> createState() => _SlideRehearsalScreenState();
}

class _SlideRehearsalScreenState extends State<SlideRehearsalScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  int _totalElapsedSeconds = 0;
  int _slideElapsedSeconds = 0;
  int _activeSlideIdx = 0;
  String? _recordedAudioPath;
  bool _hasStarted = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required for rehearsal')),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final audioPath =
        '${tempDir.path}/rehearsal_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: audioPath,
    );

    _recordedAudioPath = audioPath;
    _totalElapsedSeconds = 0;
    _slideElapsedSeconds = 0;
    _activeSlideIdx = 0;
    _hasStarted = true;

    if (!mounted) return;
    final provider = context.read<SlideCoachProvider>();
    provider.startRehearsal();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _totalElapsedSeconds++;
          _slideElapsedSeconds++;
        });
      }
    });

    setState(() {});
  }

  void _nextSlide(List<SlideCoachingModel> slides) {
    if (_activeSlideIdx < slides.length - 1) {
      setState(() {
        _activeSlideIdx++;
        _slideElapsedSeconds = 0;
      });
      final provider = context.read<SlideCoachProvider>();
      provider.recordSlideTransition(slides[_activeSlideIdx].slideNumber);
    }
  }

  void _prevSlide(List<SlideCoachingModel> slides) {
    if (_activeSlideIdx > 0) {
      setState(() {
        _activeSlideIdx--;
        _slideElapsedSeconds = 0;
      });
      final provider = context.read<SlideCoachProvider>();
      provider.recordSlideTransition(slides[_activeSlideIdx].slideNumber);
    }
  }

  Future<void> _finishSession() async {
    _ticker?.cancel();
    final stoppedPath = await _recorder.stop();
    final finalPath = stoppedPath ?? _recordedAudioPath;

    if (finalPath != null && mounted) {
      final provider = context.read<SlideCoachProvider>();
      final report = await provider.finishRehearsal(finalPath);
      if (mounted && report != null) {
        _showReportDialog(report);
      }
    }
  }

  void _showReportDialog(DeckRehearsalResponseModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.scaffoldOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RehearsalReportSheet(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlideCoachProvider>();
    final deck = provider.deck;

    if (deck == null || deck.slides.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldOf(context),
        appBar: AppBar(title: const Text('Rehearsal')),
        body: const Center(child: Text('No slides in deck')),
      );
    }

    final slides = deck.slides;
    final curSlide = slides[_activeSlideIdx];
    final imgUrl = SlideCoachRepository.instance
        .getSlideImageUrl(deck.id, curSlide.slideNumber);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (provider.isAnalyzingRehearsal) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldOf(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryPurple),
              const SizedBox(height: 24),
              Text('Analyzing Rehearsal Performance...', style: AppTextStyles.headingMOf(context)),
              const SizedBox(height: 8),
              Text(
                'Splitting slide transcripts • Counting fillers • Scoring talking points',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryOf(context)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: isLandscape
            ? _buildLandscapeLayout(context, curSlide, slides, imgUrl, deck)
            : _buildPortraitLayout(context, curSlide, slides, imgUrl, deck),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    SlideCoachingModel curSlide,
    List<SlideCoachingModel> slides,
    String imgUrl,
    SlideDeckModel deck,
  ) {
    return Row(
      children: [
        // Left: Slide Image Preview
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.black,
            child: Center(
              child: Image.network(
                imgUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text('Slide ${curSlide.slideNumber}', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),

        // Right: Teleprompter Cues & Controls
        Expanded(
          flex: 4,
          child: Container(
            color: AppColors.cardDark,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopInfoBar(curSlide, slides.length, deck),
                const Divider(color: Colors.white24, height: 20),
                Expanded(child: _buildCuePointsView(curSlide)),
                const SizedBox(height: 12),
                _buildControlButtons(slides),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    SlideCoachingModel curSlide,
    List<SlideCoachingModel> slides,
    String imgUrl,
    SlideDeckModel deck,
  ) {
    return Column(
      children: [
        // Top Slide Image Preview
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.black,
            child: Center(
              child: Image.network(
                imgUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text('Slide ${curSlide.slideNumber}', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),

        // Bottom Teleprompter & Controls
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.cardDark,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopInfoBar(curSlide, slides.length, deck),
                const Divider(color: Colors.white24, height: 16),
                Expanded(child: _buildCuePointsView(curSlide)),
                const SizedBox(height: 12),
                _buildControlButtons(slides),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopInfoBar(
    SlideCoachingModel curSlide,
    int totalSlides,
    SlideDeckModel deck,
  ) {
    final targetTime = curSlide.targetDurationSeconds;
    final isOvertime = _slideElapsedSeconds > targetTime;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Slide ${curSlide.slideNumber} of $totalSlides',
              style: const TextStyle(color: AppColors.auroraCyan, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              width: 160,
              child: Text(
                curSlide.slideTitle,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Slide timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOvertime
                    ? AppColors.dangerRed.withValues(alpha: 0.25)
                    : AppColors.primaryPurple.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOvertime ? AppColors.dangerRed : AppColors.primaryPurple,
                ),
              ),
              child: Text(
                '${_slideElapsedSeconds}s / ${targetTime}s',
                style: TextStyle(
                  color: isOvertime ? AppColors.dangerRed : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Total timer
            Text(
              'Total: ${_totalElapsedSeconds}s',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCuePointsView(SlideCoachingModel curSlide) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY TAKEAWAY: "${curSlide.keyTakeaway}"',
            style: const TextStyle(color: AppColors.warningAmber, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('TALKING POINTS:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...curSlide.talkingPoints.map((pt) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.primaryPurple, fontSize: 14, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(pt, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3))),
                  ],
                ),
              )),
          if (curSlide.transitionToNext.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'NEXT HOOK: "${curSlide.transitionToNext}"',
              style: const TextStyle(color: AppColors.auroraCyan, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButtons(List<SlideCoachingModel> slides) {
    if (!_hasStarted) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _startSession,
          icon: const Icon(Icons.mic, color: Colors.white),
          label: const Text('Start Recording Rehearsal', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
        ),
      );
    }

    return Row(
      children: [
        IconButton(
          onPressed: _activeSlideIdx > 0 ? () => _prevSlide(slides) : null,
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          tooltip: 'Previous Slide',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _nextSlide(slides),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _activeSlideIdx == slides.length - 1 ? 'Last Slide' : 'Next Slide →',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _finishSession,
          icon: const Icon(Icons.stop_circle, color: AppColors.dangerRed, size: 36),
          tooltip: 'Stop & Submit Rehearsal',
        ),
      ],
    );
  }
}

class _RehearsalReportSheet extends StatelessWidget {
  final DeckRehearsalResponseModel report;

  const _RehearsalReportSheet({required this.report});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          controller: scroll,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Rehearsal Report', style: AppTextStyles.headingLOf(context)),
            Text(
              'Total Duration: ${report.totalDurationSeconds.toInt()}s (Target: ${report.timeLimitSeconds}s)',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(height: 16),

            // Top Stat Cards
            Row(
              children: [
                _buildStatPill('Pace', '${report.overallWpm.toInt()} WPM', AppColors.primaryPurple),
                const SizedBox(width: 8),
                _buildStatPill('Fillers', '${report.overallFillerCount}', AppColors.warningAmber),
                const SizedBox(width: 8),
                _buildStatPill('Coverage', '${report.overallCoveragePercentage.toInt()}%', AppColors.successGreen),
              ],
            ),

            const SizedBox(height: 20),

            // Top 3 Improvements
            Text('Top Improvements for Next Run:', style: AppTextStyles.bodyBoldOf(context)),
            const SizedBox(height: 6),
            ...report.overallFeedback.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(tip, style: AppTextStyles.bodyTextOf(context))),
                    ],
                  ),
                )),

            const SizedBox(height: 20),

            // Per Slide Breakdown
            Text('Slide-by-Slide Performance:', style: AppTextStyles.bodyBoldOf(context)),
            const SizedBox(height: 10),
            ...report.slideReports.map((slide) => Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Slide ${slide.slideNumber}: ${slide.slideTitle}', style: AppTextStyles.bodyBoldOf(context)),
                          Text(
                            '${slide.actualDurationSeconds.toInt()}s / ${slide.targetDurationSeconds}s',
                            style: TextStyle(
                              color: slide.actualDurationSeconds > slide.targetDurationSeconds
                                  ? AppColors.dangerRed
                                  : AppColors.successGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'WPM: ${slide.wpm.toInt()} • Fillers: ${slide.fillerCount} • Coverage: ${slide.coveragePercentage.toInt()}%',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryOf(context)),
                      ),
                      if (slide.transcript.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Transcript: "${slide.transcript}"', style: AppTextStyles.caption),
                      ],
                      if (slide.talkingPointsCoverage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Talking Points Coverage:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ...slide.talkingPointsCoverage.map((c) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    c.covered ? Icons.check_circle : Icons.cancel,
                                    size: 14,
                                    color: c.covered ? AppColors.successGreen : AppColors.dangerRed,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(c.point, style: const TextStyle(fontSize: 11))),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
