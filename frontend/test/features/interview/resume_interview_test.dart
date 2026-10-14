import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/resume_interview.dart';
import 'package:pitch_coach/core/repositories/resume_repository.dart';
import 'package:pitch_coach/features/interview/controllers/interview_session_controller.dart';
import 'package:pitch_coach/features/interview/widgets/resume_interview_modal.dart';

class _MockResumeRepository extends ResumeRepository {
  final ResumeQuestionsResult? resultToReturn;
  final Exception? errorToThrow;

  _MockResumeRepository({this.resultToReturn, this.errorToThrow})
      : super();

  @override
  Future<ResumeQuestionsResult> generateQuestions({
    String? pdfPath,
    dynamic pdfBytes,
    String? pdfFileName,
    String? jdText,
    String? resumeText,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return resultToReturn ??
        const ResumeQuestionsResult(
          candidateProjects: ['Task Manager App', 'Distributed Cache'],
          candidateSkills: ['Flutter', 'Dart', 'FastAPI'],
          behavioralQuestions: [
            'Tell me about building Task Manager App.',
            'Describe a hard deadline you met.',
            'How did you resolve a disagreement in your team?',
            'What was your biggest mistake and learning?',
            'How do you prioritize backlog tasks?',
          ],
          technicalQuestions: [
            'Explain how your distributed cache handles eviction.',
            'How do you structure BLoC state management in Flutter?',
            'What database concurrency issues did you encounter?',
            'How do you profile app startup latency?',
            'Walk me through your CI/CD and automated test suite.',
          ],
        );
  }
}

void main() {
  group('Feature 3: Resume Interview Model & Controller Tests', () {
    test('ResumeQuestionsResult serializes and returns combined questions', () {
      final json = {
        'candidate_projects': ['Search Engine', 'E-commerce API'],
        'candidate_skills': ['Go', 'PostgreSQL', 'Docker'],
        'behavioral_questions': [
          'Tell me about your search engine project.',
          'Describe a challenging sprint.',
          'How do you mentor juniors?',
          'Tell me about a trade-off you made.',
          'What is your proudest feature?',
        ],
        'technical_questions': [
          'How do you index inverted lists?',
          'Explain ACID transaction guarantees in PostgreSQL.',
          'How do you handle container orchestration with Docker?',
          'Explain profiling memory leaks in Go.',
          'How do you design idempotent API endpoints?',
        ],
        'sanitized_snippet': 'Developer Resume Snippet...',
      };

      final result = ResumeQuestionsResult.fromJson(json);
      expect(result.candidateProjects.length, 2);
      expect(result.candidateSkills.length, 3);
      expect(result.behavioralQuestions.length, 5);
      expect(result.technicalQuestions.length, 5);
      expect(result.allQuestions.length, 10);
      expect(result.allQuestions.first, 'How do you index inverted lists?');
      expect(result.sanitizedSnippet, 'Developer Resume Snippet...');
    });

    test('InterviewSessionController loads resume questions as tailored prompts', () {
      final controller = InterviewSessionController(isGuest: true);
      const generated = ResumeQuestionsResult(
        candidateProjects: ['AI Pitch Coach'],
        candidateSkills: ['Flutter', 'Python'],
        behavioralQuestions: [
          'Behavioral 1',
          'Behavioral 2',
          'Behavioral 3',
          'Behavioral 4',
          'Behavioral 5',
        ],
        technicalQuestions: [
          'Technical 1',
          'Technical 2',
          'Technical 3',
          'Technical 4',
          'Technical 5',
        ],
      );

      controller.loadResumeQuestions(generated);

      expect(controller.currentMode.title, 'Resume Interview');
      expect(controller.totalPrompts, 10);
      expect(controller.currentPrompt.text, 'Technical 1');
      expect(controller.currentPrompt.category, 'Resume Technical');

      controller.nextPrompt();
      expect(controller.currentPrompt.text, 'Technical 2');
    });
  });

  group('Feature 3: ResumeInterviewModal Widget Tests', () {
    testWidgets('Empty state triggers error when submitted without PDF or JD', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ResumeInterviewModal(
              resumeRepository: _MockResumeRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resume & JD Practice'), findsOneWidget);
      expect(find.text('1. Upload Resume PDF'), findsOneWidget);
      expect(find.text('Generate 10 Interview Questions'), findsOneWidget);

      // Tap generate without selecting anything
      await tester.tap(find.text('Generate 10 Interview Questions'));
      await tester.pumpAndSettle();

      // Expect error banner
      expect(
        find.text('Please choose a resume PDF or paste job description text.'),
        findsOneWidget,
      );
    });

    testWidgets('Displays server error (e.g. Scanned PDF error) gracefully', (tester) async {
      final mockRepo = _MockResumeRepository(
        errorToThrow: Exception(
          'Scanned PDF not supported yet. Please upload a PDF with selectable text.',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ResumeInterviewModal(
              resumeRepository: mockRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter some text in JD field to satisfy the non-empty validation
      await tester.enterText(
        find.byType(TextField),
        'Software Engineer with React experience',
      );
      await tester.pumpAndSettle();

      // Tap generate
      await tester.tap(find.text('Generate 10 Interview Questions'));
      await tester.pumpAndSettle();

      // Expect the scanned PDF error message to be displayed clearly
      expect(
        find.text('Scanned PDF not supported yet. Please upload a PDF with selectable text.'),
        findsOneWidget,
      );
    });

    testWidgets('Generates and returns custom questions on success', (tester) async {
      const customQuestions = ResumeQuestionsResult(
        candidateProjects: ['E-Commerce App'],
        candidateSkills: ['Flutter'],
        behavioralQuestions: ['Tell me about your app.'],
        technicalQuestions: ['How did you test your app?'],
      );
      final mockRepo = _MockResumeRepository(resultToReturn: customQuestions);
      ResumeQuestionsResult? generatedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  generatedResult = await ResumeInterviewModal.show(ctx, resumeRepository: mockRepo);
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Role requirements');
      await tester.tap(find.text('Generate 10 Interview Questions'));
      await tester.pumpAndSettle();

      expect(generatedResult?.candidateProjects.first, 'E-Commerce App');
    });
  });
}
