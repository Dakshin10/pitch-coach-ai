import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/gamification_models.dart';
import 'package:pitch_coach/core/providers/gamification_provider.dart';
import 'package:pitch_coach/core/repositories/gamification_repository.dart';
import 'package:pitch_coach/features/progress/widgets/challenges_card.dart';
import 'package:pitch_coach/features/progress/widgets/leaderboard_card.dart';
import 'package:provider/provider.dart';

class MockGamificationRepository implements GamificationRepository {
  List<WeeklyChallenge> challengesList;
  LeaderboardResponse leaderboardData;
  bool claimCalled = false;
  String? claimedChallengeId;
  bool? toggledOptIn;

  MockGamificationRepository({
    required this.challengesList,
    required this.leaderboardData,
  });

  @override
  Future<List<WeeklyChallenge>> getChallenges() async {
    return challengesList;
  }

  @override
  Future<ClaimChallengeResult> claimChallenge(String challengeId) async {
    claimCalled = true;
    claimedChallengeId = challengeId;
    return ClaimChallengeResult(
      success: true,
      challengeId: challengeId,
      rewardPoints: 100,
      totalClaimedPoints: 100,
      message: 'Claimed successfully',
    );
  }

  @override
  Future<LeaderboardResponse> getLeaderboard({bool? optIn}) async {
    if (optIn != null) {
      toggledOptIn = optIn;
      leaderboardData = LeaderboardResponse(
        weekId: leaderboardData.weekId,
        weekStart: leaderboardData.weekStart,
        userOptedIn: optIn,
        entries: leaderboardData.entries,
        currentUserEntry: leaderboardData.currentUserEntry,
      );
    }
    return leaderboardData;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testChallenges = [
    const WeeklyChallenge(
      id: 'zero_fillers',
      title: 'Zero Fillers Take',
      description: 'Complete a session with 0 filler words.',
      icon: 'shield-check',
      currentProgress: 1,
      target: 1,
      isCompleted: true,
      isClaimed: false,
      rewardPoints: 100,
    ),
    const WeeklyChallenge(
      id: 'pacing_pro',
      title: 'Pacing Pro',
      description: 'Deliver within 120-160 WPM pace.',
      icon: 'speed',
      currentProgress: 0,
      target: 1,
      isCompleted: false,
      isClaimed: false,
      rewardPoints: 150,
    ),
  ];

  final testLeaderboard = const LeaderboardResponse(
    weekId: '2026-W42',
    weekStart: '2026-10-12T00:00:00Z',
    userOptedIn: false,
    entries: [
      LeaderboardEntry(
        rank: 1,
        displayName: 'Anonymous Speaker #420',
        score: 94.5,
        sessionsCount: 5,
        isCurrentUser: false,
      ),
      LeaderboardEntry(
        rank: 2,
        displayName: 'Anonymous Speaker #101',
        score: 89.0,
        sessionsCount: 3,
        isCurrentUser: true,
      ),
    ],
    currentUserEntry: LeaderboardEntry(
      rank: 2,
      displayName: 'Anonymous Speaker #101',
      score: 89.0,
      sessionsCount: 3,
      isCurrentUser: true,
    ),
  );

  Widget createTestWidget({
    required GamificationProvider provider,
    required Widget child,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<GamificationProvider>.value(
          value: provider,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('Feature 11: Gamification & Challenges Tests', () {
    test('Model parsing from JSON', () {
      final challengeJson = {
        'id': 'zero_fillers',
        'title': 'Zero Fillers Take',
        'description': 'Complete a session with 0 fillers',
        'icon': 'shield-check',
        'current_progress': 1,
        'target': 1,
        'is_completed': true,
        'is_claimed': false,
        'reward_points': 100,
      };

      final c = WeeklyChallenge.fromJson(challengeJson);
      expect(c.id, equals('zero_fillers'));
      expect(c.isCompleted, isTrue);
      expect(c.rewardPoints, equals(100));

      final lbJson = {
        'week_id': '2026-W42',
        'week_start': '2026-10-12T00:00:00Z',
        'user_opted_in': false,
        'entries': [
          {
            'rank': 1,
            'display_name': 'Anonymous Speaker #12',
            'score': 92.0,
            'sessions_count': 3,
            'is_current_user': true,
          },
        ],
        'current_user_entry': {
          'rank': 1,
          'display_name': 'Anonymous Speaker #12',
          'score': 92.0,
          'sessions_count': 3,
          'is_current_user': true,
        },
      };

      final lb = LeaderboardResponse.fromJson(lbJson);
      expect(lb.weekId, equals('2026-W42'));
      expect(lb.entries.length, equals(1));
      expect(lb.entries.first.displayName, equals('Anonymous Speaker #12'));
    });

    testWidgets('ChallengesCard renders challenges, progress, and claims', (
      tester,
    ) async {
      final mockRepo = MockGamificationRepository(
        challengesList: List.from(testChallenges),
        leaderboardData: testLeaderboard,
      );
      final provider = GamificationProvider(repo: mockRepo);
      await provider.loadGamificationData();

      await tester.pumpWidget(
        createTestWidget(provider: provider, child: const ChallengesCard()),
      );
      await tester.pump();

      // Check titles
      expect(find.text('Weekly Challenges'), findsOneWidget);
      expect(find.text('Zero Fillers Take'), findsOneWidget);
      expect(find.text('Pacing Pro'), findsOneWidget);

      // Completed challenge has claim button
      final claimButton = find.byKey(
        const Key('claim_button_zero_fillers'),
      );
      expect(claimButton, findsOneWidget);
      expect(find.text('Claim +100 XP'), findsOneWidget);

      // Uncompleted challenge displays +150 XP tag
      expect(find.text('+150 XP'), findsOneWidget);

      // Tap claim button
      await tester.tap(claimButton);
      await tester.pump();

      expect(mockRepo.claimCalled, isTrue);
      expect(mockRepo.claimedChallengeId, equals('zero_fillers'));
      expect(find.text('Claimed'), findsOneWidget);
    });

    testWidgets('LeaderboardCard renders ranks, pseudonyms, and opt-in switch', (
      tester,
    ) async {
      final mockRepo = MockGamificationRepository(
        challengesList: List.from(testChallenges),
        leaderboardData: testLeaderboard,
      );
      final provider = GamificationProvider(repo: mockRepo);
      await provider.loadGamificationData();

      await tester.pumpWidget(
        createTestWidget(provider: provider, child: const LeaderboardCard()),
      );
      await tester.pump();

      // Verify header and week ID
      expect(find.text('Weekly Leaderboard'), findsOneWidget);
      expect(find.text('2026-W42'), findsOneWidget);

      // Verify privacy pseudonyms rendered
      expect(find.text('Anonymous Speaker #420'), findsOneWidget);
      expect(find.text('You'), findsWidgets);
      expect(find.text('94.5 pts'), findsOneWidget);

      // Verify privacy opt-in switch
      final switchFinder = find.byKey(
        const Key('leaderboard_opt_in_switch'),
      );
      expect(switchFinder, findsOneWidget);

      // Toggle switch
      await tester.tap(switchFinder);
      await tester.pump();

      expect(mockRepo.toggledOptIn, isTrue);
    });
  });
}
