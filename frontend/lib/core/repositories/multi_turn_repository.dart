import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/multi_turn_interview.dart';
import '../services/api_client.dart';
import '../utils/local_file.dart';

class MultiTurnRepository {
  MultiTurnRepository._();
  static final MultiTurnRepository instance = MultiTurnRepository._();

  final _api = ApiClient.instance;

  // Cached pending answer to protect against data loss on network failure
  String? _lastPendingAnswer;
  String? _lastPendingAudioPath;

  String? get lastPendingAnswer => _lastPendingAnswer;
  String? get lastPendingAudioPath => _lastPendingAudioPath;

  void stagePendingAnswer({String? text, String? audioPath}) {
    _lastPendingAnswer = text;
    _lastPendingAudioPath = audioPath;
  }

  void clearPendingAnswer() {
    _lastPendingAnswer = null;
    _lastPendingAudioPath = null;
  }

  /// Evaluates a candidate's text answer.
  Future<TurnEvaluateResponse> evaluateTurnText({
    required String question,
    required String candidateAnswer,
    List<TurnMessage> turnHistory = const [],
    int followUpCount = 0,
  }) async {
    stagePendingAnswer(text: candidateAnswer);

    try {
      final res = await _api.post(
        '/interview/evaluate-turn',
        data: {
          'question': question,
          'candidate_answer': candidateAnswer,
          'turn_history': turnHistory.map((t) => t.toJson()).toList(),
          'follow_up_count': followUpCount,
        },
      ) as Map<String, dynamic>;

      clearPendingAnswer();
      return TurnEvaluateResponse.fromJson(res);
    } catch (e) {
      debugPrint('[MultiTurnRepository] evaluateTurnText error: $e');
      rethrow;
    }
  }

  /// Evaluates an audio recording using Groq Whisper + LLM evaluation.
  Future<TurnEvaluateResponse> evaluateTurnAudio({
    required String audioPath,
    required String question,
    List<TurnMessage> turnHistory = const [],
    int followUpCount = 0,
  }) async {
    stagePendingAnswer(audioPath: audioPath);

    if (kIsWeb) {
      // In web demo mode, simulate answer evaluation gracefully
      final response = await evaluateTurnText(
        question: question,
        candidateAnswer:
            'I diagnosed the performance issue and implemented caching.',
        turnHistory: turnHistory,
        followUpCount: followUpCount,
      );
      return response;
    }

    if (!await localFileExistsAndNonEmpty(audioPath)) {
      throw StateError('Recorded audio file is missing or empty.');
    }

    try {
      final formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(
          audioPath,
          filename: 'turn_answer.m4a',
        ),
        'question': question,
        'turn_history_json': jsonEncode(
          turnHistory.map((t) => t.toJson()).toList(),
        ),
        'follow_up_count': followUpCount,
      });

      final res =
          await _api.postMultipart(
                '/interview/evaluate-audio-turn',
                formData,
              )
              as Map<String, dynamic>;

      clearPendingAnswer();
      return TurnEvaluateResponse.fromJson(res);
    } catch (e) {
      debugPrint('[MultiTurnRepository] evaluateTurnAudio error: $e');
      rethrow;
    }
  }

  /// Scores the full multi-turn conversation dialogue.
  Future<ExchangeScoreResponse> scoreExchange({
    required String question,
    required List<TurnMessage> turns,
    double? wpm,
    double? fillerWordsPer100,
    int? pauseCount,
  }) async {
    try {
      final payload = <String, dynamic>{
        'question': question,
        'turns': turns.map((t) => t.toJson()).toList(),
      };
      if (wpm != null) payload['wpm'] = wpm;
      if (fillerWordsPer100 != null) payload['filler_words_per_100'] = fillerWordsPer100;
      if (pauseCount != null) payload['pause_count'] = pauseCount;

      final res = await _api.post(
        '/interview/score-exchange',
        data: payload,
      ) as Map<String, dynamic>;

      return ExchangeScoreResponse.fromJson(res);
    } catch (e) {
      debugPrint('[MultiTurnRepository] scoreExchange error: $e');
      rethrow;
    }
  }
}
