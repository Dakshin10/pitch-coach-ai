import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/lesson_model.dart';
import '../../core/models/practice_mode.dart';
import '../../features/auth/login_screen.dart';
import '../../features/demo/design_system_demo_page.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/interview/interview_practice_screen.dart';
import '../../features/learn/lesson_detail_screen.dart';
import '../../features/learn/lessons_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/results/results_screen.dart';

abstract class AppRouter {
  static const String onboarding = '/';
  static const String login = '/login';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String history = '/history';
  static const String interview = '/interview';
  static const String results = '/results';
  static const String progress = '/progress';
  static const String profile = '/profile';
  static const String demo = '/demo';
  static const String lessons = '/lessons';
  static const String lessonDetail = '/lessons/detail';

  /// Bottom-tab destinations — no transition so phone nav stays responsive.
  static const Set<String> _tabPaths = {
    home,
    history,
    progress,
    profile,
  };

  static Page<T> _buildPage<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    if (_tabPaths.contains(state.matchedLocation) ||
        _tabPaths.contains(state.uri.path)) {
      return NoTransitionPage<T>(
        key: state.pageKey,
        child: child,
      );
    }

    // Lightweight fade only — avoid undisposed CurvedAnimations and
    // expensive slide+fade stacks on every push.
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = animation.drive(CurveTween(curve: Curves.easeOut));
        return FadeTransition(opacity: fade, child: child);
      },
    );
  }

  static final GoRouter router = GoRouter(
    initialLocation: onboarding,
    routes: [
      GoRoute(
        path: onboarding,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: login,
        pageBuilder: (context, state) {
          final isSignUp = state.extra as bool? ?? false;
          return _buildPage(
            context: context,
            state: state,
            child: LoginScreen(isSignUpInitial: isSignUp),
          );
        },
      ),
      GoRoute(
        path: profileSetup,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const ProfileSetupScreen(),
        ),
      ),
      GoRoute(
        path: home,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: history,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const HistoryScreen(),
        ),
      ),
      GoRoute(
        path: interview,
        pageBuilder: (context, state) {
          PracticeSessionConfig? config;
          if (state.extra is PracticeSessionConfig) {
            config = state.extra as PracticeSessionConfig;
          } else if (state.extra is String) {
            config = PracticeSessionConfig.defaultFor(state.extra as String);
          } else if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            config = PracticeSessionConfig.defaultFor(map['mode'] as String?);
          }
          return _buildPage(
            context: context,
            state: state,
            child: InterviewPracticeScreen(initialConfig: config),
          );
        },
      ),
      GoRoute(
        path: results,
        pageBuilder: (context, state) {
          final sessionId = state.extra as String?;
          return _buildPage(
            context: context,
            state: state,
            child: ResultsScreen(sessionId: sessionId),
          );
        },
      ),
      GoRoute(
        path: progress,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const ProgressScreen(),
        ),
      ),
      GoRoute(
        path: profile,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: demo,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const DesignSystemDemoPage(),
        ),
      ),
      GoRoute(
        path: lessons,
        pageBuilder: (context, state) => _buildPage(
          context: context,
          state: state,
          child: const LessonsScreen(),
        ),
      ),
      GoRoute(
        path: lessonDetail,
        pageBuilder: (context, state) {
          final lesson = state.extra as Lesson;
          return _buildPage(
            context: context,
            state: state,
            child: LessonDetailScreen(lesson: lesson),
          );
        },
      ),
    ],
  );
}
