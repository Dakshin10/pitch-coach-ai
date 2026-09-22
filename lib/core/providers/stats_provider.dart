import 'package:flutter/material.dart';
import '../models/stats_models.dart';
import '../repositories/stats_repository.dart';

enum StatsLoadState { idle, loading, ready, error }

/// Holds stats summary, trend chart data, skill breakdown, and achievements.
/// Used by ProgressScreen and HomeScreen.
class StatsProvider extends ChangeNotifier {
  final _repo = StatsRepository.instance;

  StatsSummary _summary = StatsSummary.empty;
  List<TrendPoint> _trend = [];
  SkillBreakdown _skills = SkillBreakdown.empty;
  List<Achievement> _achievements = [];
  StatsLoadState _state = StatsLoadState.idle;
  String? _error;

  StatsSummary get summary => _summary;
  List<TrendPoint> get trend => _trend;
  SkillBreakdown get skills => _skills;
  List<Achievement> get achievements => _achievements;
  StatsLoadState get state => _state;
  String? get error => _error;
  bool get isLoading => _state == StatsLoadState.loading;

  Future<void> loadAll({String trendRange = 'week'}) async {
    _state = StatsLoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getSummary(),
        _repo.getTrend(range: trendRange),
        _repo.getSkills(),
        _repo.getAchievements(),
      ]);
      _summary = results[0] as StatsSummary;
      _trend = results[1] as List<TrendPoint>;
      _skills = results[2] as SkillBreakdown;
      _achievements = results[3] as List<Achievement>;
      _state = StatsLoadState.ready;
      _error = null;
    } catch (e) {
      _state = StatsLoadState.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> loadSummaryOnly() async {
    try {
      _summary = await _repo.getSummary();
      notifyListeners();
    } catch (_) {}
  }
}
