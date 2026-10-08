import 'package:flutter/material.dart';
import '../models/stats_models.dart';
import '../repositories/stats_repository.dart';
import '../repositories/demo_repository.dart';

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
  DateTime? _lastLoaded;

  StatsSummary get summary => _summary;
  List<TrendPoint> get trend => _trend;
  SkillBreakdown get skills => _skills;
  List<Achievement> get achievements => _achievements;
  StatsLoadState get state => _state;
  String? get error => _error;
  bool get isLoading => _state == StatsLoadState.loading;
  bool get hasData => _state == StatsLoadState.ready;

  Future<void> loadAll({String trendRange = 'week', bool force = false}) async {
    // If not forced and already loaded recently (< 5 mins), keep current data without reloading
    if (!force && _state == StatsLoadState.ready && _lastLoaded != null) {
      final age = DateTime.now().difference(_lastLoaded!);
      if (age < const Duration(minutes: 5)) {
        return;
      }
    }

    // Only set loading if we don't already have ready data
    if (_state != StatsLoadState.ready) {
      _state = StatsLoadState.loading;
      notifyListeners();
    }

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
      _lastLoaded = DateTime.now();
    } catch (e) {
      // If we don't already have data, report error; otherwise retain cached data
      if (_state != StatsLoadState.ready) {
        _state = StatsLoadState.error;
        _error = e.toString();
      }
    }
    notifyListeners();
  }

  Future<void> loadSummaryOnly({bool force = false}) async {
    if (!force && _summary != StatsSummary.empty && _lastLoaded != null) {
      final age = DateTime.now().difference(_lastLoaded!);
      if (age < const Duration(minutes: 5)) {
        return;
      }
    }
    try {
      _summary = await _repo.getSummary();
      _lastLoaded = DateTime.now();
      notifyListeners();
    } catch (_) {}
  }

  void loadDemo() {
    final demo = DemoRepository.instance;
    _summary = demo.summary;
    _trend = demo.trend;
    _skills = demo.skills;
    _achievements = [];
    _state = StatsLoadState.ready;
    _error = null;
    _lastLoaded = DateTime.now();
    notifyListeners();
  }
}
