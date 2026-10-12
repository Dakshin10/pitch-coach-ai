import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/cubits/user_cubit.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserCubit Tests', () {
    test('initial state has default guest user and unauthenticated state', () {
      final cubit = UserCubit();
      expect(cubit.state.authState, equals(AuthState.unauthenticated));
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.isLoggedIn, isFalse);
      cubit.close();
    });

    blocTest<UserCubit, UserState>(
      'setUser updates user profile and marks as authenticated',
      build: () => UserCubit(),
      act: (cubit) {
        final profile = UserProfile(
          id: 'user-123',
          name: 'Jane Doe',
          email: 'jane@example.com',
          role: 'Founder',
          targetGoal: 'Pitch to VCs',
          experienceLevel: 'Advanced',
          targetIndustry: 'Fintech',
          feedbackTone: 'Direct',
          isGuest: false,
        );
        cubit.setUser(profile);
      },
      expect: () => [
        isA<UserState>()
            .having((s) => s.user.name, 'name', equals('Jane Doe'))
            .having((s) => s.user.email, 'email', equals('jane@example.com'))
            .having(
              (s) => s.authState,
              'authState',
              equals(AuthState.authenticated),
            )
            .having((s) => s.isAuthenticated, 'isAuthenticated', isTrue)
            .having((s) => s.isLoggedIn, 'isLoggedIn', isTrue),
      ],
    );

    blocTest<UserCubit, UserState>(
      'loginAsGuest sets guest profile and guest authState',
      build: () => UserCubit(),
      act: (cubit) => cubit.loginAsGuest(),
      expect: () => [
        isA<UserState>().having((s) => s.isLoading, 'isLoading', isTrue),
        isA<UserState>()
            .having((s) => s.user.isGuest, 'isGuest', isTrue)
            .having((s) => s.user.id, 'id', equals('demo-guest'))
            .having((s) => s.authState, 'authState', equals(AuthState.guest))
            .having((s) => s.isGuest, 'isGuest', isTrue)
            .having((s) => s.isLoggedIn, 'isLoggedIn', isTrue)
            .having((s) => s.isLoading, 'isLoading', isFalse),
      ],
    );

    blocTest<UserCubit, UserState>(
      'updateProfile updates profile fields in state',
      build: () => UserCubit(),
      act: (cubit) {
        cubit.setUser(
          UserProfile(
            id: 'guest',
            name: 'Old Name',
            email: '',
            role: 'Student',
            targetGoal: 'Goal',
            experienceLevel: 'Beginner',
            targetIndustry: 'Tech',
            feedbackTone: 'Direct',
            isGuest: true,
          ),
        );
        cubit.updateProfile(name: 'New Name', role: 'CTO');
      },
      expect: () => [
        isA<UserState>().having((s) => s.user.name, 'name', equals('Old Name')),
        isA<UserState>()
            .having((s) => s.user.name, 'name', equals('New Name'))
            .having((s) => s.user.role, 'role', equals('CTO')),
      ],
    );

    blocTest<UserCubit, UserState>(
      'logout clears user session back to initial unauthenticated state',
      build: () => UserCubit(),
      act: (cubit) async {
        cubit.setUser(
          UserProfile(
            id: 'user-999',
            name: 'Logged In User',
            email: 'test@example.com',
            role: 'Designer',
            targetGoal: 'Interviews',
            experienceLevel: 'Mid',
            targetIndustry: 'Design',
            feedbackTone: 'Gentle',
          ),
        );
        await cubit.logout();
      },
      expect: () => [
        isA<UserState>().having(
          (s) => s.user.name,
          'name',
          equals('Logged In User'),
        ),
        isA<UserState>().having((s) => s.isLoading, 'isLoading', isTrue),
        isA<UserState>()
            .having(
              (s) => s.authState,
              'authState',
              equals(AuthState.unauthenticated),
            )
            .having((s) => s.user.name, 'name', equals('Guest')),
      ],
    );
  });
}
