import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/slide_coach_models.dart';
import '../../../core/providers/slide_coach_provider.dart';
import '../../../core/repositories/slide_coach_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class DeckReviewScreen extends StatefulWidget {
  const DeckReviewScreen({super.key});

  @override
  State<DeckReviewScreen> createState() => _DeckReviewScreenState();
}

class _DeckReviewScreenState extends State<DeckReviewScreen> {
  final TextEditingController _scriptController = TextEditingController();
  final ScrollController _carouselController = ScrollController();
  int _lastSyncedSlideNumber = -1;

  @override
  void dispose() {
    _scriptController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _syncScriptController(SlideCoachingModel? slide) {
    if (slide != null && slide.slideNumber != _lastSyncedSlideNumber) {
      _lastSyncedSlideNumber = slide.slideNumber;
      _scriptController.text = slide.suggestedScript ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlideCoachProvider>();
    final deck = provider.deck;
    final currentSlide = provider.currentSlide;
    _syncScriptController(currentSlide);

    if (deck == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldOf(context),
        appBar: AppBar(title: const Text('Deck Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = deck.deckSummary;

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: Text(deck.filename, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppColors.primaryPurple),
            tooltip: 'Start Rehearsal',
            onPressed: () => context.push('/slide-coach/rehearsal'),
          ),
          IconButton(
            icon: const Icon(Icons.question_answer_outlined, color: AppColors.auroraCyan),
            tooltip: 'Q&A Prep',
            onPressed: () => context.push('/slide-coach/qa'),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ThemeToggleButton(size: 38, compact: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Deck Summary Header Card ──
            if (summary != null) _buildSummaryHeader(context, summary),

            const SizedBox(height: 18),

            // ── 2. Horizontal Slide Carousel ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Slides (${provider.currentSlideIndex + 1}/${deck.slides.length})',
                    style: AppTextStyles.sectionHeaderOf(context),
                  ),
                  Text(
                    'Total limit: ${deck.timeLimitSeconds}s',
                    style: AppTextStyles.caption.copyWith(color: AppColors.primaryPurple),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildSlideCarousel(context, provider, deck),

            const SizedBox(height: 20),

            // ── 3. Current Slide Cue Cards ──
            if (currentSlide != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Slide Headline & Timing Bar
                    _buildSlideHeaderCard(context, currentSlide, provider),

                    const SizedBox(height: 14),

                    // Key Takeaway Card
                    _buildKeyTakeawayCard(context, currentSlide),

                    const SizedBox(height: 14),

                    // Talking Points (Editable)
                    _buildTalkingPointsCard(context, currentSlide, provider),

                    const SizedBox(height: 14),

                    // Suggested Script Accordion (Expandable & Editable)
                    _buildScriptCard(context, currentSlide, provider),

                    const SizedBox(height: 14),

                    // Transition Hook
                    _buildTransitionCard(context, currentSlide),

                    const SizedBox(height: 14),

                    // Visuals & Slide Critique
                    _buildCritiqueCard(context, currentSlide),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          boxShadow: AppColors.softShadowOf(context),
          border: Border(top: BorderSide(color: AppColors.borderOf(context))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/slide-coach/qa'),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Q&A Prep'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  side: const BorderSide(color: AppColors.primaryPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/slide-coach/rehearsal'),
                icon: const Icon(Icons.play_circle_fill, size: 20),
                label: const Text('Rehearse Presentation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, DeckSummaryModel summary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: ${summary.overallScore}/100',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_stories, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 6),
              Text('Story Arc', style: AppTextStyles.bodyBoldOf(context)),
            ],
          ),
          const SizedBox(height: 10),
          Text(summary.storyArc, style: AppTextStyles.bodyTextOf(context)),
          if (summary.missingSections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Missing Pitch Elements:', style: AppTextStyles.captionOf(context).copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: summary.missingSections
                  .map((sec) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.dangerRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                        ),
                        child: Text(sec, style: const TextStyle(color: AppColors.dangerRed, fontSize: 11, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
          if (summary.top3Fixes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Top 3 Fixes:', style: AppTextStyles.captionOf(context).copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...summary.top3Fixes.map((fix) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(fix, style: AppTextStyles.bodyTextOf(context).copyWith(fontSize: 12))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildSlideCarousel(
    BuildContext context,
    SlideCoachProvider provider,
    SlideDeckModel deck,
  ) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        controller: _carouselController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: deck.slides.length,
        itemBuilder: (context, i) {
          final s = deck.slides[i];
          final isSelected = i == provider.currentSlideIndex;
          final imgUrl = SlideCoachRepository.instance.getSlideImageUrl(deck.id, s.slideNumber);

          return GestureDetector(
            onTap: () => provider.selectSlide(i),
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primaryPurple : AppColors.borderOf(context),
                  width: isSelected ? 2.5 : 1,
                ),
                color: AppColors.cardOf(context),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.black12,
                        child: Center(child: Text('Slide ${s.slideNumber}')),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Slide ${s.slideNumber}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${s.targetDurationSeconds}s',
                              style: const TextStyle(color: AppColors.auroraCyan, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlideHeaderCard(
    BuildContext context,
    SlideCoachingModel slide,
    SlideCoachProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Slide ${slide.slideNumber}', style: AppTextStyles.caption.copyWith(color: AppColors.primaryPurple)),
                Text(slide.slideTitle, style: AppTextStyles.bodyBoldOf(context)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.primaryPurple),
                const SizedBox(width: 4),
                Text(
                  '${slide.targetDurationSeconds}s target',
                  style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyTakeawayCard(BuildContext context, SlideCoachingModel slide) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.warningAmber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Key Audience Takeaway', style: AppTextStyles.captionOf(context).copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(slide.keyTakeaway, style: AppTextStyles.bodyTextOf(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTalkingPointsCard(
    BuildContext context,
    SlideCoachingModel slide,
    SlideCoachProvider provider,
  ) {
    return Container(
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
              Text('Talking Points (Say These)', style: AppTextStyles.bodyBoldOf(context)),
              Text('Auto-saved', style: AppTextStyles.caption.copyWith(color: AppColors.successGreen)),
            ],
          ),
          const SizedBox(height: 8),
          ...slide.talkingPoints.asMap().entries.map((entry) {
            final idx = entry.key;
            final pt = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, color: AppColors.primaryPurple)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: pt,
                      style: AppTextStyles.bodyTextOf(context).copyWith(fontSize: 14, color: AppColors.textPrimaryOf(context)),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        hintText: 'Talking point...',
                        hintStyle: TextStyle(color: AppColors.textSecondaryOf(context).withValues(alpha: 0.6)),
                      ),
                      onChanged: (newVal) {
                        final updated = List<String>.from(slide.talkingPoints);
                        updated[idx] = newVal;
                        provider.updateCurrentSlideTalkingPoints(updated);
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScriptCard(
    BuildContext context,
    SlideCoachingModel slide,
    SlideCoachProvider provider,
  ) {
    return ExpansionTile(
      collapsedBackgroundColor: AppColors.cardOf(context),
      backgroundColor: AppColors.cardOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      leading: const Icon(Icons.record_voice_over, color: AppColors.primaryPurple, size: 20),
      title: Text('Word-for-Word Pitch Script', style: AppTextStyles.bodyBoldOf(context)),
      subtitle: Text('Expand to view or edit full speech', style: AppTextStyles.captionOf(context).copyWith(fontSize: 11)),
      childrenPadding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _scriptController,
          maxLines: 5,
          style: AppTextStyles.bodyTextOf(context).copyWith(fontSize: 14, height: 1.4, color: AppColors.textPrimaryOf(context)),
          decoration: InputDecoration(
            hintText: 'Suggested word-for-word spoken speech...',
            hintStyle: TextStyle(color: AppColors.textSecondaryOf(context).withValues(alpha: 0.6)),
            filled: true,
            fillColor: AppColors.scaffoldOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
          ),
          onChanged: (newScript) => provider.updateCurrentSlideScript(newScript),
        ),
      ],
    );
  }

  Widget _buildTransitionCard(BuildContext context, SlideCoachingModel slide) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.compare_arrows, color: AppColors.auroraCyan, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Slide Transition Hook', style: AppTextStyles.captionOf(context).copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('"${slide.transitionToNext}"', style: AppTextStyles.bodyTextOf(context).copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCritiqueCard(BuildContext context, SlideCoachingModel slide) {
    return Container(
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
            children: [
              const Icon(Icons.analytics_outlined, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 6),
              Text('Visual Layout & Critique', style: AppTextStyles.bodyBoldOf(context)),
              const Spacer(),
              if (slide.textDensity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Density: ${slide.textDensity}', style: const TextStyle(fontSize: 11, color: AppColors.primaryPurple)),
                ),
            ],
          ),
          if (slide.visuals != null && slide.visuals!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Visuals Detected: ${slide.visuals}', style: AppTextStyles.bodyTextOf(context).copyWith(fontSize: 12)),
          ],
          if (slide.slideCritique.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...slide.slideCritique.map((crit) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $crit', style: AppTextStyles.captionOf(context).copyWith(color: AppColors.warningAmber, fontSize: 12)),
                )),
          ],
        ],
      ),
    );
  }
}
