import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../models/session_result.dart';
import '../services/api_client.dart';

/// Encapsulates recording and the session API lifecycle.
/// Used by InterviewSessionController.
class SessionRepository {
  SessionRepository._();
  static final SessionRepository instance = SessionRepository._();

  final _api = ApiClient.instance;
  final AudioRecorder _recorder = AudioRecorder();

  String? _currentSessionId;
  String? _currentAudioPath;
  static final Map<String, String> _audioPathCache = {};

  String? get currentSessionId => _currentSessionId;

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Session lifecycle ─────────────────────────────────────────────────────

  /// Step 1: create session row on backend and start recording.
  Future<String?> startSession({
    required String mode,
    required String topicOrQuestion,
  }) async {
    // 1a. Create session on backend
    final data = await _api.post('/sessions/start', data: {
      'mode': mode,
      'topic_or_question': topicOrQuestion,
    }) as Map<String, dynamic>;
    _currentSessionId = data['session_id'] as String;

    // 1b. Start recording
    final dir = await getApplicationDocumentsDirectory();
    _currentAudioPath =
        '${dir.path}/session_${_currentSessionId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: _currentAudioPath!,
    );

    return _currentSessionId;
  }

  /// Step 2: stop recording and upload audio → triggers AI pipeline on server.
  Future<SessionResult?> finishSession(double durationSeconds) async {
    if (_currentSessionId == null) return null;

    // Stop recorder — returns the file path
    final path = await _recorder.stop();
    final audioPath = path ?? _currentAudioPath;
    if (audioPath == null) return null;

    final file = File(audioPath);
    if (!await file.exists()) return null;

    final formData = FormData.fromMap({
      'audio_file': await MultipartFile.fromFile(
        audioPath,
        filename: 'recording.m4a',
      ),
      'duration_seconds': durationSeconds.toString(),
    });

    final sessionId = _currentSessionId!;
    final raw = await _api.postMultipart(
      '/sessions/$sessionId/finish',
      formData,
    ) as Map<String, dynamic>;

    _audioPathCache[sessionId] = audioPath;
    _currentAudioPath = null;
    return SessionResult.fromJson(raw).copyWith(audioPath: audioPath);
  }

  /// Step 3 (polling): fetch session until is_analyzed = true.
  Future<SessionResult> getSession(String sessionId) async {
    final raw = await _api.get('/sessions/$sessionId') as Map<String, dynamic>;
    final result = SessionResult.fromJson(raw);
    final cachedPath = _audioPathCache[sessionId];
    if (cachedPath != null) {
      return result.copyWith(audioPath: cachedPath);
    }
    return result;
  }

  /// History list — used by HistoryScreen.
  Future<List<SessionSummary>> listSessions({
    String? mode,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _api.get('/sessions', params: {
      'mode': ?mode,
      'search': ?search,
      'page': page.toString(),
      'limit': limit.toString(),
    }) as List<dynamic>;
    return raw
        .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> cancelSession() async {
    await _recorder.stop();
    _currentSessionId = null;
    _currentAudioPath = null;
  }

  void dispose() {
    _recorder.dispose();
  }
}
