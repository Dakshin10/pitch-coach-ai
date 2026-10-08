import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/models/slide_coach_models.dart';
import '../../../core/providers/slide_coach_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SlideQaScreen extends StatefulWidget {
  const SlideQaScreen({super.key});

  @override
  State<SlideQaScreen> createState() => _SlideQaScreenState();
}

class _SlideQaScreenState extends State<SlideQaScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedAudioPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SlideCoachProvider>();
      if (provider.qaQuestions.isEmpty) {
        provider.loadQaQuestions();
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required for answering')),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final audioPath =
        '${tempDir.path}/qa_answer_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: audioPath,
    );

    setState(() {
      _isRecording = true;
      _recordedAudioPath = audioPath;
    });
  }

  Future<void> _stopAndSubmit() async {
    final stoppedPath = await _recorder.stop();
    setState(() => _isRecording = false);
    final finalPath = stoppedPath ?? _recordedAudioPath;

    if (finalPath != null && mounted) {
      final provider = context.read<SlideCoachProvider>();
      await provider.submitAnswer(finalPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlideCoachProvider>();
    final curQ = provider.currentQuestion;
    final totalQ = provider.qaQuestions.length;
    final curIdx = provider.currentQaIndex;
    final eval = provider.latestQaEvaluation;

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Audience Q&A Prep'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: provider.isLoadingQuestions
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryPurple),
                  SizedBox(height: 16),
                  Text('Generating tough audience questions...'),
                ],
              ),
            )
          : curQ == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No questions available'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => provider.loadQaQuestions(),
                        child: const Text('Generate Questions'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Step Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${curIdx + 1} of $totalQ',
                            style: AppTextStyles.caption.copyWith(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Audience: ${provider.deck?.audience ?? "Judges"}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Question Card
                      Container(
                        padding: const EdgeInsets.all(18),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.help_outline, color: AppColors.primaryPurple, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(curQ.question, style: AppTextStyles.headingM),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.psychology, size: 18, color: AppColors.primaryPurple),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Why they ask: ${curQ.whyTheyAsk}',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryPurple),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Recording Controls
                      if (provider.isEvaluatingAnswer) ...[
                        const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryPurple),
                              SizedBox(height: 12),
                              Text('Transcribing and evaluating your spoken response...'),
                            ],
                          ),
                        ),
                      ] else ...[
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _isRecording ? _stopAndSubmit : _startRecording,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: _isRecording ? AppColors.dangerRed : AppColors.primaryPurple,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isRecording ? AppColors.dangerRed : AppColors.primaryPurple)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isRecording ? Icons.stop : Icons.mic,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isRecording
                                    ? 'Recording answer... Tap stop to grade'
                                    : 'Tap microphone to speak your answer',
                                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Evaluation Results Card
                      if (eval != null) ...[
                        const SizedBox(height: 28),
                        _buildEvaluationCard(context, eval),
                      ],

                      const SizedBox(height: 32),

                      // Navigation Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            onPressed: curIdx > 0 ? () => provider.prevQuestion() : null,
                            child: const Text('← Previous'),
                          ),
                          ElevatedButton(
                            onPressed: curIdx < totalQ - 1 ? () => provider.nextQuestion() : null,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
                            child: const Text('Next Question →', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEvaluationCard(BuildContext context, QaEvaluationModel eval) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Evaluation & Scoring', style: AppTextStyles.bodyBold),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${eval.overallScore}/100',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Score Pills
          Row(
            children: [
              _buildScoreBadge('Clarity', eval.clarityScore),
              const SizedBox(width: 6),
              _buildScoreBadge('Directness', eval.directnessScore),
              const SizedBox(width: 6),
              _buildScoreBadge('Evidence', eval.evidenceScore),
              const SizedBox(width: 6),
              _buildScoreBadge('Confidence', eval.confidenceScore),
            ],
          ),

          const SizedBox(height: 14),
          Text('Your Spoken Answer:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('"${eval.spokenTranscript}"', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),

          const SizedBox(height: 12),
          Text('Coach Critique:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(eval.critique, style: AppTextStyles.bodyText),

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Sample Better Answer (Model Answer):',
                      style: AppTextStyles.caption.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(eval.sampleBetterAnswer, style: AppTextStyles.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String label, int score) {
    Color col;
    if (score >= 80) {
      col = AppColors.successGreen;
    } else if (score >= 60) {
      col = AppColors.warningAmber;
    } else {
      col = AppColors.dangerRed;
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$score', style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
