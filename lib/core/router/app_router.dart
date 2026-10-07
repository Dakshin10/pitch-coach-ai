import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/lesson_model.dart';
import '../../features/auth/login_screen.dart';
import '../../features/demo/design_system_demo_page.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../core/models/practice_mode.dart';
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

  static CustomTransitionPage<T> _buildSlideFadeTransition<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  static final GoRouter router = GoRouter(
    initialLocation: onboarding,
    routes: [
      GoRoute(
        path: onboarding,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
          context: context,
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: login,
        pageBuilder: (context, state) {
          final isSignUp = state.extra as bool? ?? false;
          return _buildSlideFadeTransition(
            context: context,
            state: state,
            child: LoginScreen(isSignUpInitial: isSignUp),
          );
        },
      ),
      GoRoute(
        path: profileSetup,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
          context: context,
          state: state,
          child: const ProfileSetupScreen(),
        ),
      ),
      GoRoute(
        path: home,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: history,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
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
          return _buildSlideFadeTransition(
            context: context,
            state: state,
            child: InterviewPracticeScreen(initialConfig: config),
          );
        },
      ),
      GoRoute(
        path: results,
        pageBuilder: (context, state) {
          // Extra is the session_id string set by InterviewPracticeScreen on stop
          final sessionId = state.extra as String?;
          return _buildSlideFadeTransition(
            context: context,
            state: state,
            child: ResultsScreen(sessionId: sessionId),
          );
        },
      ),
      GoRoute(
        path: progress,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
          context: context,
          state: state,
          child: const ProgressScreen(),
        ),
      ),
      GoRoute(
        path: profile,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
          context: context,
          state: state,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: demo,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
          context: context,
          state: state,
          child: const DesignSystemDemoPage(),
        ),
      ),
      GoRoute(
        path: lessons,
        pageBuilder: (context, state) => _buildSlideFadeTransition(
          context: context,
          state: state,
          child: const LessonsScreen(),
        ),
      ),
      GoRoute(
        path: lessonDetail,
        pageBuilder: (context, state) {
          final lesson = state.extra as Lesson;
          return _buildSlideFadeTransition(
            context: context,
            state: state,
            child: LessonDetailScreen(lesson: lesson),
          );
        },
      ),
    ],
  );
}
