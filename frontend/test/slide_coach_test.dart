import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/slide_coach_models.dart';
import 'package:pitch_coach/core/providers/slide_coach_provider.dart';

void main() {
  group('Slide Coach Models Serialization & Defaults', () {
    test('DeckSummaryModel serialization and deserialization', () {
      final json = {
        'story_arc': 'Classic problem-solution structure',
        'missing_sections': ['Financial Moat'],
        'overall_score': 88,
        'top_3_fixes': ['Add traction metric', 'Clarify pricing model'],
      };

      final summary = DeckSummaryModel.fromJson(json);
      expect(summary.storyArc, 'Classic problem-solution structure');
      expect(summary.missingSections, ['Financial Moat']);
      expect(summary.overallScore, 88);
      expect(summary.top3Fixes.length, 2);

      final serialized = summary.toJson();
      expect(serialized['overall_score'], 88);
      expect(serialized['missing_sections'], ['Financial Moat']);
    });

    test('SlideCoachingModel serialization and deserialization', () {
      final json = {
        'slide_number': 1,
        'slide_title': 'Introduction',
        'target_duration_seconds': 30,
        'key_takeaway': 'Hook the audience with the vision',
        'talking_points': ['Welcome judges', 'Pitch Coach transforms speaking'],
        'suggested_script': 'Good morning everyone, welcome to Pitch Coach.',
        'transition_to_next': 'Now let us examine the pain point.',
        'slide_critique': ['Clean layout', 'Punchy header'],
        'image_url': '/api/slides/deck-123/slide/1',
        'visuals': 'Hero image with title banner',
        'text_density': 'Light',
        'readability_issues': [],
      };

      final slide = SlideCoachingModel.fromJson(json);
      expect(slide.slideNumber, 1);
      expect(slide.slideTitle, 'Introduction');
      expect(slide.targetDurationSeconds, 30);
      expect(slide.talkingPoints.length, 2);
      expect(slide.suggestedScript, contains('Good morning'));
      expect(slide.imageUrl, '/api/slides/deck-123/slide/1');

      final serialized = slide.toJson();
      expect(serialized['slide_number'], 1);
      expect(serialized['slide_title'], 'Introduction');
    });

    test('SlideDeckModel serialization and deserialization', () {
      final json = {
        'id': 'deck-123',
        'filename': 'pitch_deck.pdf',
        'audience': 'investors',
        'time_limit_seconds': 180,
        'goal': 'Raise Seed Round',
        'status': 'done',
        'stage': 'ready',
        'progress': 100,
        'page_count': 2,
        'deck_summary': {
          'story_arc': 'Strong arc',
          'missing_sections': [],
          'overall_score': 90,
          'top_3_fixes': ['Highlight revenue run-rate'],
        },
        'slides': [
          {
            'slide_number': 1,
            'slide_title': 'Title',
            'target_duration_seconds': 30,
            'key_takeaway': 'Welcome',
            'talking_points': ['Point 1'],
            'transition_to_next': 'Next',
            'slide_critique': ['Good'],
            'readability_issues': [],
          },
        ],
        'created_at': '2026-10-07T12:00:00Z',
        'updated_at': '2026-10-07T12:05:00Z',
      };

      final deck = SlideDeckModel.fromJson(json);
      expect(deck.id, 'deck-123');
      expect(deck.filename, 'pitch_deck.pdf');
      expect(deck.timeLimitSeconds, 180);
      expect(deck.status, 'done');
      expect(deck.deckSummary?.overallScore, 90);
      expect(deck.slides.length, 1);
      expect(deck.slides.first.slideTitle, 'Title');

      final serialized = deck.toJson();
      expect(serialized['id'], 'deck-123');
      expect(serialized['time_limit_seconds'], 180);
    });

    test('SlideDeckStatusModel parsing', () {
      final json = {
        'deck_id': 'deck-123',
        'status': 'processing',
        'stage': 'reading_slides',
        'progress': 45,
        'error': null,
      };

      final status = SlideDeckStatusModel.fromJson(json);
      expect(status.deckId, 'deck-123');
      expect(status.status, 'processing');
      expect(status.stage, 'reading_slides');
      expect(status.progress, 45);
      expect(status.error, isNull);
    });

    test(
      'DeckRehearsalResponseModel and SlideRehearsalReportModel serialization',
      () {
        final json = {
          'rehearsal_id': 'reh-123',
          'deck_id': 'deck-123',
          'total_duration_seconds': 125.5,
          'time_limit_seconds': 180,
          'overall_wpm': 144.2,
          'overall_filler_count': 2,
          'overall_coverage_percentage': 92.5,
          'overall_feedback': ['Terrific pacing', 'Clear transitions'],
          'slide_reports': [
            {
              'slide_number': 1,
              'slide_title': 'Intro',
              'target_duration_seconds': 30,
              'actual_duration_seconds': 28.5,
              'wpm': 142.0,
              'filler_count': 1,
              'filler_breakdown': {'um': 1},
              'transcript': 'Hello everyone, welcome to the presentation.',
              'talking_points_coverage': [
                {
                  'point': 'Welcome judges',
                  'covered': true,
                  'evidence': 'Hello everyone, welcome',
                },
              ],
              'coverage_percentage': 100.0,
              'ai_feedback': [
                {'type': 'pacing', 'comment': 'On target'},
              ],
            },
          ],
          'created_at': '2026-10-07T12:10:00Z',
        };

        final rehearsal = DeckRehearsalResponseModel.fromJson(json);
        expect(rehearsal.rehearsalId, 'reh-123');
        expect(rehearsal.totalDurationSeconds, 125.5);
        expect(rehearsal.overallWpm, 144.2);
        expect(rehearsal.overallFillerCount, 2);
        expect(rehearsal.overallCoveragePercentage, 92.5);
        expect(rehearsal.slideReports.length, 1);

        final report = rehearsal.slideReports.first;
        expect(report.slideNumber, 1);
        expect(report.fillerBreakdown['um'], 1);
        expect(report.talkingPointsCoverage.first.covered, true);
      },
    );

    test('QaQuestionModel and QaEvaluationModel serialization', () {
      final qJson = {
        'id': 'q-1',
        'question': 'How do you defend against big tech competitors?',
        'why_they_ask': 'Tests market moat and proprietary defensibility.',
        'targeted_slide_number': 2,
      };

      final q = QaQuestionModel.fromJson(qJson);
      expect(q.id, 'q-1');
      expect(q.question, contains('big tech'));
      expect(q.whyTheyAsk, contains('moat'));
      expect(q.targetedSlideNumber, 2);

      final evalJson = {
        'question_id': 'q-1',
        'question': 'How do you defend against big tech competitors?',
        'spoken_transcript':
            'We have proprietary speech models and enterprise contracts.',
        'clarity_score': 85,
        'directness_score': 82,
        'evidence_score': 80,
        'confidence_score': 90,
        'overall_score': 84,
        'critique': 'Strong, confident response. Add retention metrics.',
        'sample_better_answer':
            'Mention our 95% retention rate and patent portfolio.',
      };

      final eval = QaEvaluationModel.fromJson(evalJson);
      expect(eval.questionId, 'q-1');
      expect(eval.overallScore, 84);
      expect(eval.clarityScore, 85);
      expect(eval.confidenceScore, 90);
      expect(eval.sampleBetterAnswer, contains('retention rate'));
    });
  });

  group('SlideCoachProvider State Tests', () {
    test('Initializes with idle default state', () {
      final provider = SlideCoachProvider();
      expect(provider.isUploading, false);
      expect(provider.uploadProgress, 0.0);
      expect(provider.uploadError, isNull);
      expect(provider.activeDeckId, isNull);
      expect(provider.status, isNull);
      expect(provider.isPolling, false);
      expect(provider.deck, isNull);
      expect(provider.currentSlideIndex, 0);
      expect(provider.currentSlide, isNull);
      expect(provider.isRehearsing, false);
      expect(provider.isAnalyzingRehearsal, false);
      expect(provider.latestRehearsalResult, isNull);
      expect(provider.qaQuestions.isEmpty, true);
      expect(provider.currentQuestion, isNull);
    });

    test('Slide selection bounds check', () {
      final provider = SlideCoachProvider();
      // When deck is null, selecting slide is a safe no-op
      provider.selectSlide(3);
      expect(provider.currentSlideIndex, 0);
    });
  });
}
