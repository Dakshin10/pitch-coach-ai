import '../models/stats_models.dart';
import '../services/api_client.dart';

/// Stats and achievements API calls.
class StatsRepository {
  StatsRepository._();
  static final StatsRepository instance = StatsRepository._();

  final _api = ApiClient.instance;

  Future<StatsSummary> getSummary() async {
    final raw = await _api.get('/stats/summary') as Map<String, dynamic>;
    return StatsSummary.fromJson(raw);
  }

  Future<List<TrendPoint>> getTrend({String range = 'week'}) async {
    final raw = await _api.get('/stats/trend', params: {'range': range}) as List<dynamic>;
    return raw.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SkillBreakdown> getSkills() async {
    final raw = await _api.get('/stats/skills') as Map<String, dynamic>;
    return SkillBreakdown.fromJson(raw);
  }

  Future<List<Achievement>> getAchievements() async {
    final raw = await _api.get('/achievements') as List<dynamic>;
    return raw.map((e) => Achievement.fromJson(e as Map<String, dynamic>)).toList();
  }
}
