import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pitch_coach/core/models/pitch_template.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/core/repositories/template_repository.dart';
import 'package:pitch_coach/features/interview/interview_practice_screen.dart';

void main() {
  group('PitchTemplate Models & Serialization', () {
    test('PitchTemplate JSON serializes and deserializes properly', () {
      const template = PitchTemplate(
        id: 'sample_pitch',
        title: 'Sample Pitch',
        description: 'Test pitch template for verification.',
        targetDurationSeconds: 120,
        sections: [
          TemplateSection(
            id: 'sec_1',
            name: 'Opening Hook',
            description: 'Quick hook',
            weight: 50.0,
            keywords: ['hook', 'opening'],
          ),
          TemplateSection(
            id: 'sec_2',
            name: 'Closing Ask',
            description: 'Call to action',
            weight: 50.0,
            keywords: ['ask', 'closing'],
          ),
        ],
        rubric: {
          'sec_1': 'Did it capture attention in 10s?',
          'sec_2': 'Was the monetary ask explicit?',
        },
        coachingFocus: 'Direct delivery and strong close.',
      );

      final json = template.toJson();
      expect(json['id'], 'sample_pitch');
      expect(json['target_duration_seconds'], 120);
      expect((json['sections'] as List).length, 2);

      final parsed = PitchTemplate.fromJson(json);
      expect(parsed.id, 'sample_pitch');
      expect(parsed.title, 'Sample Pitch');
      expect(parsed.sections.length, 2);
      expect(parsed.sections[0].weight, 50.0);
      expect(parsed.rubric['sec_1'], 'Did it capture attention in 10s?');
      expect(parsed.coachingFocus, 'Direct delivery and strong close.');
    });

    test('Default templates contain investor, hackathon, elevator, and viva', () {
      final defaults = PitchTemplate.defaultTemplates;
      final ids = defaults.map((t) => t.id).toList();
      expect(ids, containsAll([
        'investor_pitch',
        'hackathon_demo',
        'elevator_pitch',
        'viva',
      ]));

      final investor = defaults.firstWhere((t) => t.id == 'investor_pitch');
      expect(investor.targetDurationSeconds, 180);
      expect(investor.sections.length, 5);
      expect(investor.rubric, contains('the_ask'));

      final elevator = defaults.firstWhere((t) => t.id == 'elevator_pitch');
      expect(elevator.targetDurationSeconds, 60);
      expect(elevator.sections.length, 3);
    });

    test('SessionResult parses template and structure metrics', () {
      final json = {
        'id': 'sess-test-123',
        'mode': 'presentation',
        'topic_or_question': 'Investor Pitch Demo',
        'duration_seconds': 175.0,
        'wpm': 142.0,
        'filler_word_count': 3,
        'filler_word_breakdown': {'um': 3},
        'pause_count': 2,
        'avg_pause_length': 1.1,
        'clarity_score': 82.0,
        'confidence_score': 85.0,
        'overall_score': 83.5,
        'ai_feedback': [],
        'created_at': DateTime.now().toIso8601String(),
        'is_analyzed': true,
        'template_id': 'investor_pitch',
        'structure_score': 90.0,
        'template_sections_detected': ['Hook & Problem', 'Solution & Product', 'The Ask & Use of Funds'],
        'template_sections_missing': ['Traction & TAM', 'Business Model'],
      };

      final result = SessionResult.fromJson(json);
      expect(result.templateId, 'investor_pitch');
      expect(result.structureScore, 90.0);
      expect(result.templateSectionsDetected.length, 3);
      expect(result.templateSectionsMissing.length, 2);
      expect(result.templateSectionsMissing, contains('Traction & TAM'));
    });
  });

  group('InterviewSessionController Template Selection', () {
    test('selectTemplate updates selectedTemplate and custom prompt', () {
      final controller = InterviewSessionController(isGuest: true);
      final investor = PitchTemplate.defaultTemplates.firstWhere((t) => t.id == 'investor_pitch');

      controller.selectTemplate(investor);
      expect(controller.selectedTemplate?.id, 'investor_pitch');
      expect(controller.currentPrompt.text, contains('Investor Pitch'));

      // Deselecting template restores default state
      controller.selectTemplate(null);
      expect(controller.selectedTemplate, isNull);
    });

    test('TemplateRepository provides offline default templates', () async {
      final repo = TemplateRepository();
      final templates = await repo.getTemplates();
      expect(templates, isNotEmpty);
      expect(templates.length, greaterThanOrEqualTo(4));

      final template = await repo.getTemplate('hackathon_demo');
      expect(template, isNotNull);
      expect(template?.targetDurationSeconds, 120);
    });
  });

  group('InterviewPracticeScreen Pitch Templates UI', () {
    testWidgets('Renders template chips and updates roadmap disclosure upon selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(home: InterviewPracticeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Template picker title and chips exist
      expect(find.text('Pitch Templates & Rubrics'), findsOneWidget);
      expect(find.byKey(const Key('template_chip_investor_pitch')), findsOneWidget);
      expect(find.byKey(const Key('template_chip_elevator_pitch')), findsOneWidget);

      // Initially roadmap card is not shown
      expect(find.byKey(const Key('template_roadmap_card')), findsNothing);

      // 2. Tap on Investor Pitch chip
      await tester.tap(find.byKey(const Key('template_chip_investor_pitch')));
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Roadmap card appears with sections and duration
      expect(find.byKey(const Key('template_roadmap_card')), findsOneWidget);
      expect(find.text('Target Sections (5)'), findsOneWidget);
      expect(find.text('Hook & Problem (20%)'), findsOneWidget);
      expect(find.text('Clear Template'), findsOneWidget);

      // 4. Tap Clear Template
      await tester.tap(find.text('Clear Template'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('template_roadmap_card')), findsNothing);
    });
  });
}
