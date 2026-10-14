import '../models/gamification_models.dart';
import '../services/api_client.dart';

/// Repository for weekly rotating challenges and privacy-preserving leaderboard.
class GamificationRepository {
  GamificationRepository._();
  static final GamificationRepository instance = GamificationRepository._();

  final _api = ApiClient.instance;

  Future<List<WeeklyChallenge>> getChallenges() async {
    final raw = await _api.get('/achievements/challenges') as List<dynamic>;
    return raw
        .map((e) => WeeklyChallenge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClaimChallengeResult> claimChallenge(String challengeId) async {
    final raw =
        await _api.post('/achievements/challenges/$challengeId/claim')
            as Map<String, dynamic>;
    return ClaimChallengeResult.fromJson(raw);
  }

  Future<LeaderboardResponse> getLeaderboard({bool? optIn}) async {
    final params = <String, dynamic>{};
    if (optIn != null) {
      params['opt_in'] = optIn;
    }
    final raw =
        await _api.get('/achievements/leaderboard', params: params)
            as Map<String, dynamic>;
    return LeaderboardResponse.fromJson(raw);
  }
}
