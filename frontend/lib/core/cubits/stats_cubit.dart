import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/stats_models.dart';
import '../providers/stats_provider.dart';
import '../repositories/demo_repository.dart';
import '../repositories/stats_repository.dart';
import '../services/local_database_service.dart';
import '../services/sync_service.dart';

/// Immutable state for user stats, charts, and achievements.
class StatsState extends Equatable {
  final StatsSummary summary;
  final List<TrendPoint> trend;
  final SkillBreakdown skills;
  final List<Achievement> achievements;
  final StatsLoadState state;
  final String? error;
  final DateTime? lastLoaded;

  const StatsState({
    this.summary = StatsSummary.empty,
    this.trend = const [],
    this.skills = SkillBreakdown.empty,
    this.achievements = const [],
    this.state = StatsLoadState.idle,
    this.error,
    this.lastLoaded,
  });

  bool get isLoading => state == StatsLoadState.loading;
  bool get hasData => state == StatsLoadState.ready;

  StatsState copyWith({
    StatsSummary? summary,
    List<TrendPoint>? trend,
    SkillBreakdown? skills,
    List<Achievement>? achievements,
    StatsLoadState? state,
    String? error,
    DateTime? lastLoaded,
  }) {
    return StatsState(
      summary: summary ?? this.summary,
      trend: trend ?? this.trend,
      skills: skills ?? this.skills,
      achievements: achievements ?? this.achievements,
      state: state ?? this.state,
      error: error,
      lastLoaded: lastLoaded ?? this.lastLoaded,
    );
  }

  @override
  List<Object?> get props => [
    summary,
    trend,
    skills,
    achievements,
    state,
    error,
    lastLoaded,
  ];
}

/// Cubit managing stats calculation, SQLite reads, and sync updates.
class StatsCubit extends Cubit<StatsState> {
  final StatsRepository _repo;
  final LocalDatabaseService _localDb;
  final SyncService _sync;
  StreamSubscription<String>? _syncSub;

  StatsCubit({
    StatsRepository? statsRepository,
    LocalDatabaseService? localDbService,
    SyncService? syncService,
  }) : _repo = statsRepository ?? StatsRepository.instance,
       _localDb = localDbService ?? LocalDatabaseService.instance,
       _sync = syncService ?? SyncService.instance,
       super(const StatsState()) {
    _syncSub = _sync.onSyncCompleted.listen((userId) {
      if (_localDb.isOpen && _localDb.currentUserId == userId) {
        _reloadFromLocalDb(userId);
      }
    });
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
  }

  Future<void> loadDashboard(
    String userId, {
    bool force = false,
    String trendRange = 'week',
  }) => loadAll(trendRange: trendRange, force: force, userId: userId);

  Future<void> loadAll({
    String trendRange = 'week',
    bool force = false,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _localDb.currentUserId;

    if (effectiveUserId == null ||
        effectiveUserId == 'guest' ||
        effectiveUserId == 'demo-guest') {
      loadDemo();
      return;
    }

    if (!force &&
        state.lastLoaded != null &&
        DateTime.now().difference(state.lastLoaded!) <
            const Duration(seconds: 30)) {
      return;
    }

    // 1. Instant load from local SQLite
    if (_localDb.isOpen && _localDb.currentUserId == effectiveUserId) {
      try {
        final localSummary = await _localDb.getSummary(effectiveUserId);
        final localTrend = await _localDb.getTrend(
          effectiveUserId,
          days: trendRange == 'week' ? 7 : 30,
        );
        final localAchievements = await _localDb.getUserAchievements(
          effectiveUserId,
        );

        if (localSummary.totalSessions > 0 || localAchievements.isNotEmpty) {
          emit(
            state.copyWith(
              summary: localSummary,
              trend: localTrend,
              achievements: localAchievements,
              state: StatsLoadState.ready,
            ),
          );
        }
      } catch (e) {
        debugPrint('[StatsCubit] Error loading from local SQLite: $e');
      }
    }

    if (state.state != StatsLoadState.ready) {
      emit(state.copyWith(state: StatsLoadState.loading));
    }

    // 2. Refresh via pull sync and fetch remote skills
    try {
      _sync
          .pull(userId: effectiveUserId)
          .then((_) {
            if (_localDb.isOpen && _localDb.currentUserId == effectiveUserId) {
              _reloadFromLocalDb(effectiveUserId, trendRange: trendRange);
            }
          })
          .catchError((_) {});

      final skills = await _repo.getSkills();
      emit(
        state.copyWith(
          skills: skills,
          state: StatsLoadState.ready,
          lastLoaded: DateTime.now(),
        ),
      );
    } catch (e) {
      if (state.state != StatsLoadState.ready) {
        emit(state.copyWith(state: StatsLoadState.error, error: e.toString()));
      }
    }
  }

  void loadDemo() {
    final demo = DemoRepository.instance;
    emit(
      state.copyWith(
        summary: demo.summary,
        trend: demo.trend,
        skills: demo.skills,
        achievements: const [],
        state: StatsLoadState.ready,
        error: null,
        lastLoaded: DateTime.now(),
      ),
    );
  }

  Future<void> _reloadFromLocalDb(
    String userId, {
    String trendRange = 'week',
  }) async {
    try {
      final summary = await _localDb.getSummary(userId);
      final trend = await _localDb.getTrend(
        userId,
        days: trendRange == 'week' ? 7 : 30,
      );
      final achievements = await _localDb.getUserAchievements(userId);

      emit(
        state.copyWith(
          summary: summary,
          trend: trend,
          achievements: achievements.isNotEmpty
              ? achievements
              : state.achievements,
          state: StatsLoadState.ready,
          lastLoaded: DateTime.now(),
        ),
      );
    } catch (e) {
      if (state.state != StatsLoadState.ready) {
        emit(state.copyWith(state: StatsLoadState.error, error: e.toString()));
      }
    }
  }
}
