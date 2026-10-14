import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/cubits/stats_cubit.dart';
import 'package:pitch_coach/core/providers/stats_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatsCubit Tests', () {
    test('initial state has empty summary and idle load state', () {
      final cubit = StatsCubit();
      expect(cubit.state.state, equals(StatsLoadState.idle));
      expect(cubit.state.summary.totalSessions, equals(0));
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.hasData, isFalse);
      cubit.close();
    });

    blocTest<StatsCubit, StatsState>(
      'loadDemo populates summary, trend, and skills with ready state',
      build: () => StatsCubit(),
      act: (cubit) => cubit.loadDemo(),
      expect: () => [
        isA<StatsState>()
            .having((s) => s.state, 'state', equals(StatsLoadState.ready))
            .having(
              (s) => s.summary.totalSessions,
              'totalSessions',
              greaterThan(0),
            )
            .having((s) => s.trend, 'trend', isNotEmpty)
            .having((s) => s.hasData, 'hasData', isTrue)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<StatsCubit, StatsState>(
      'loadAll with guest userId automatically loads demo data',
      build: () => StatsCubit(),
      act: (cubit) => cubit.loadAll(userId: 'guest'),
      expect: () => [
        isA<StatsState>()
            .having((s) => s.state, 'state', equals(StatsLoadState.ready))
            .having(
              (s) => s.summary.totalSessions,
              'totalSessions',
              greaterThan(0),
            )
            .having((s) => s.trend, 'trend', isNotEmpty),
      ],
    );

    blocTest<StatsCubit, StatsState>(
      'loadDashboard with demo-guest userId loads demo data',
      build: () => StatsCubit(),
      act: (cubit) => cubit.loadDashboard('demo-guest'),
      expect: () => [
        isA<StatsState>()
            .having((s) => s.state, 'state', equals(StatsLoadState.ready))
            .having(
              (s) => s.summary.totalSessions,
              'totalSessions',
              greaterThan(0),
            ),
      ],
    );
  });
}
