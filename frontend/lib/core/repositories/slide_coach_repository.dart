import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/slide_coach_models.dart';
import '../services/api_client.dart';

class SlideCoachRepository {
  SlideCoachRepository._();
  static final SlideCoachRepository instance = SlideCoachRepository._();

  final _api = ApiClient.instance;

  String getSlideImageUrl(String deckId, int slideNumber) {
    return '${AppConfig.apiBaseUrl}/slides/$deckId/slides/$slideNumber/image';
  }

  /// Uploads a presentation deck PDF to the backend.
  Future<Map<String, dynamic>> uploadDeck({
    required String filePath,
    required String fileName,
    required String audience,
    required int timeLimitSeconds,
    required String goal,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'audience': audience,
      'time_limit_seconds': timeLimitSeconds,
      'goal': goal,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final resp = await _api.postMultipart(
      '/slides/upload',
      formData,
      onSendProgress: onProgress,
    );
    return Map<String, dynamic>.from(resp as Map);
  }

  /// Polls the processing status of a deck.
  Future<SlideDeckStatusModel> getStatus(String deckId) async {
    final resp = await _api.get('/slides/$deckId/status');
    return SlideDeckStatusModel.fromJson(Map<String, dynamic>.from(resp as Map));
  }

  /// Fetches the full structured coaching output for a deck.
  Future<SlideDeckModel> getDeck(String deckId) async {
    final resp = await _api.get('/slides/$deckId');
    return SlideDeckModel.fromJson(Map<String, dynamic>.from(resp as Map));
  }

  /// Saves user edits to talking points or script for a given slide.
  Future<void> patchSlide(
    String deckId,
    int slideNumber, {
    List<String>? talkingPoints,
    String? suggestedScript,
    String? slideTitle,
    int? targetDurationSeconds,
  }) async {
    final body = <String, dynamic>{};
    if (talkingPoints != null) body['talking_points'] = talkingPoints;
    if (suggestedScript != null) body['suggested_script'] = suggestedScript;
    if (slideTitle != null) body['slide_title'] = slideTitle;
    if (targetDurationSeconds != null) {
      body['target_duration_seconds'] = targetDurationSeconds;
    }

    await _api.patch('/slides/$deckId/slides/$slideNumber', data: body);
  }

  /// Deletes a slide deck and its generated assets.
  Future<void> deleteDeck(String deckId) async {
    await _api.dio.delete('/slides/$deckId');
  }

  /// Submits rehearsal audio and slide transition timestamps.
  Future<DeckRehearsalResponseModel> rehearse({
    required String deckId,
    required String audioPath,
    required List<Map<String, dynamic>> slideTimestamps,
  }) async {
    final formData = FormData.fromMap({
      'slide_timestamps': jsonEncode(slideTimestamps),
      'file': await MultipartFile.fromFile(audioPath, filename: 'rehearsal.m4a'),
    });

    final resp = await _api.postMultipart(
      '/slides/$deckId/rehearse',
      formData,
    );
    return DeckRehearsalResponseModel.fromJson(
        Map<String, dynamic>.from(resp as Map));
  }

  /// Generates audience-targeted Q&A questions for the deck.
  Future<List<QaQuestionModel>> getQaQuestions(String deckId) async {
    final resp = await _api.post('/slides/$deckId/qa/questions');
    final data = Map<String, dynamic>.from(resp as Map);
    final list = data['questions'] as List<dynamic>? ?? [];
    return list
        .map((e) => QaQuestionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Submits audio answer to a Q&A question for evaluation.
  Future<QaEvaluationModel> submitQaAnswer({
    required String deckId,
    required String questionId,
    required String audioPath,
  }) async {
    final formData = FormData.fromMap({
      'question_id': questionId,
      'file': await MultipartFile.fromFile(audioPath, filename: 'answer.m4a'),
    });

    final resp = await _api.postMultipart(
      '/slides/$deckId/qa/answer',
      formData,
    );
    return QaEvaluationModel.fromJson(Map<String, dynamic>.from(resp as Map));
  }

  /// Lists all saved presentation decks for the current user.
  Future<List<SlideDeckModel>> listDecks() async {
    final resp = await _api.get('/slides');
    final list = resp as List<dynamic>? ?? [];
    return list
        .map((e) => SlideDeckModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Triggers re-analysis of an existing deck.
  Future<void> reanalyzeDeck(String deckId) async {
    await _api.post('/slides/$deckId/reanalyze');
  }
}
