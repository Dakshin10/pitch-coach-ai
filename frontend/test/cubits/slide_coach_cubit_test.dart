import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/cubits/slide_coach_cubit.dart';
import 'package:pitch_coach/core/models/slide_coach_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDeck = SlideDeckModel(
    id: 'deck-1',
    filename: 'pitch_deck.pdf',
    audience: 'investors',
    timeLimitSeconds: 180,
    goal: 'Raise Seed',
    status: 'done',
    stage: 'completed',
    progress: 100,
    pageCount: 3,
    slides: [
      SlideCoachingModel(
        slideNumber: 1,
        slideTitle: 'Title Slide',
        targetDurationSeconds: 30,
        keyTakeaway: 'Introduce company',
        talkingPoints: ['Problem', 'Solution'],
        suggestedScript: 'Hello investors...',
        transitionToNext: 'Now look at market',
        slideCritique: [],
        readabilityIssues: [],
      ),
      SlideCoachingModel(
        slideNumber: 2,
        slideTitle: 'Market Size',
        targetDurationSeconds: 60,
        keyTakeaway: r'$10B TAM',
        talkingPoints: ['TAM', 'SAM'],
        suggestedScript: 'Our market is massive...',
        transitionToNext: 'Here is our traction',
        slideCritique: [],
        readabilityIssues: [],
      ),
      SlideCoachingModel(
        slideNumber: 3,
        slideTitle: 'Traction',
        targetDurationSeconds: 45,
        keyTakeaway: '100% MoM growth',
        talkingPoints: ['ARR', 'Users'],
        suggestedScript: 'We are growing fast...',
        transitionToNext: 'Thank you',
        slideCritique: [],
        readabilityIssues: [],
      ),
    ],
    createdAt: DateTime.now().toIso8601String(),
    updatedAt: DateTime.now().toIso8601String(),
  );

  group('SlideCoachCubit Tests', () {
    test('initial state has default empty values', () {
      final cubit = SlideCoachCubit();
      expect(cubit.state.deck, isNull);
      expect(cubit.state.currentSlideIndex, equals(0));
      expect(cubit.state.isUploading, isFalse);
      expect(cubit.state.isRehearsing, isFalse);
      expect(cubit.state.currentSlide, isNull);
      cubit.close();
    });

    blocTest<SlideCoachCubit, SlideCoachState>(
      'setDeck updates state with deck and resets slide index to 0',
      build: () => SlideCoachCubit(),
      act: (cubit) => cubit.setDeck(testDeck),
      expect: () => [
        isA<SlideCoachState>()
            .having((s) => s.deck?.id, 'deck.id', equals('deck-1'))
            .having((s) => s.currentSlideIndex, 'currentSlideIndex', equals(0))
            .having(
              (s) => s.currentSlide?.slideTitle,
              'title',
              equals('Title Slide'),
            ),
      ],
    );

    blocTest<SlideCoachCubit, SlideCoachState>(
      'selectSlide updates currentSlideIndex within bounds',
      build: () => SlideCoachCubit(),
      seed: () => SlideCoachState(deck: testDeck, currentSlideIndex: 0),
      act: (cubit) => cubit.selectSlide(2),
      expect: () => [
        isA<SlideCoachState>()
            .having((s) => s.currentSlideIndex, 'currentSlideIndex', equals(2))
            .having(
              (s) => s.currentSlide?.slideTitle,
              'title',
              equals('Traction'),
            ),
      ],
    );

    blocTest<SlideCoachCubit, SlideCoachState>(
      'nextSlide increments currentSlideIndex',
      build: () => SlideCoachCubit(),
      seed: () => SlideCoachState(deck: testDeck, currentSlideIndex: 0),
      act: (cubit) => cubit.nextSlide(),
      expect: () => [
        isA<SlideCoachState>()
            .having((s) => s.currentSlideIndex, 'currentSlideIndex', equals(1))
            .having(
              (s) => s.currentSlide?.slideTitle,
              'title',
              equals('Market Size'),
            ),
      ],
    );

    blocTest<SlideCoachCubit, SlideCoachState>(
      'previousSlide decrements currentSlideIndex',
      build: () => SlideCoachCubit(),
      seed: () => SlideCoachState(deck: testDeck, currentSlideIndex: 2),
      act: (cubit) => cubit.previousSlide(),
      expect: () => [
        isA<SlideCoachState>().having(
          (s) => s.currentSlideIndex,
          'currentSlideIndex',
          equals(1),
        ),
      ],
    );

    blocTest<SlideCoachCubit, SlideCoachState>(
      'startRehearsal activates isRehearsing in state',
      build: () => SlideCoachCubit(),
      seed: () => SlideCoachState(deck: testDeck),
      act: (cubit) => cubit.startRehearsal(),
      expect: () => [
        isA<SlideCoachState>()
            .having((s) => s.isRehearsing, 'isRehearsing', isTrue)
            .having((s) => s.rehearsalError, 'rehearsalError', isNull),
      ],
    );

    blocTest<SlideCoachCubit, SlideCoachState>(
      'dismissCompletedAnnouncement clears completedDeckToAnnounce',
      build: () => SlideCoachCubit(),
      seed: () => SlideCoachState(completedDeckToAnnounce: testDeck),
      act: (cubit) => cubit.dismissCompletedAnnouncement(),
      expect: () => [
        isA<SlideCoachState>().having(
          (s) => s.completedDeckToAnnounce,
          'completedDeckToAnnounce',
          isNull,
        ),
      ],
    );
  });
}
