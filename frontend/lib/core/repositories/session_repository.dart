import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../models/session_result.dart';
import '../services/api_client.dart';
import '../utils/local_file.dart';

enum MicPermissionState {
  granted,
  denied,
  permanentlyDenied,
}

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
  String? get currentAudioPath => _currentAudioPath;

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<MicPermissionState> requestMicPermissionStatus() async {
    final current = await Permission.microphone.status;
    if (current.isGranted) return MicPermissionState.granted;
    if (current.isPermanentlyDenied) return MicPermissionState.permanentlyDenied;

    final result = await Permission.microphone.request();
    if (result.isGranted) return MicPermissionState.granted;
    if (result.isPermanentlyDenied) return MicPermissionState.permanentlyDenied;
    return MicPermissionState.denied;
  }

  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<bool> isRecording() async => await _recorder.isRecording();

  /// Guest Mode records locally for a genuine microphone experience, but never
  /// creates a backend session or uploads the resulting file.
  Future<void> startDemoRecording() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required to record.');
    }
    final dir = await getApplicationDocumentsDirectory();
    _currentAudioPath =
        '${dir.path}/demo_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: _currentAudioPath!,
    );
  }

  Future<String> finishDemoRecording() async {
    final path = await _recorder.stop() ?? _currentAudioPath;
    final recordedPath = path;
    _currentAudioPath = null;
    if (recordedPath == null) throw StateError('Recording did not produce an audio file.');
    if (!await localFileExistsAndNonEmpty(recordedPath)) {
      throw StateError('The recording is missing or empty. Please try again.');
    }
    return recordedPath;
  }

  // ── Session lifecycle ─────────────────────────────────────────────────────

  /// Step 1: create session row on backend and start recording.
  Future<String?> startSession({
    required String mode,
    required String topicOrQuestion,
  }) async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required to record.');
    }
    // 1a. Create session on backend after permission is known.
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

  /// Stops recorder without uploading. Returns the local audio file path.
  Future<String?> stopAudioRecorder() async {
    final path = await _recorder.stop();
    return path ?? _currentAudioPath;
  }

  /// Step 2: stop recording and upload audio → triggers AI pipeline on server.
  Future<SessionResult?> finishSession(double durationSeconds) async {
    if (_currentSessionId == null) return null;

    // Stop recorder — returns the file path
    final path = await _recorder.stop();
    final audioPath = path ?? _currentAudioPath;
    if (audioPath == null) {
      throw StateError('Recording did not produce an audio file.');
    }

    if (!await localFileExistsAndNonEmpty(audioPath)) {
      throw StateError('The recording is missing or empty. Please try again.');
    }

    // MultipartFile.fromFile is unavailable on web; bytes path works everywhere.
    final MultipartFile audioPart;
    if (kIsWeb) {
      throw StateError(
        'Audio upload from Chrome is not supported yet. '
        'Use the Android/iOS app or Windows desktop build for live sessions.',
      );
    } else {
      audioPart = await MultipartFile.fromFile(
        audioPath,
        filename: 'recording.m4a',
      );
    }

    final formData = FormData.fromMap({
      'audio_file': audioPart,
      'duration_seconds': durationSeconds.toString(),
    });

    final sessionId = _currentSessionId!;
    final raw = await _api.postMultipart(
      '/sessions/$sessionId/finish',
      formData,
    ) as Map<String, dynamic>;

    // Delete local audio after a successful upload to save device disk space
    await deleteLocalFile(audioPath);
    _audioPathCache.remove(sessionId);
    _currentAudioPath = null;
    _currentSessionId = null;

    return SessionResult.fromJson(raw);
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

  /// Asks the server to re-run analysis on an already-uploaded recording.
  Future<void> retryAnalysis(String sessionId) async {
    await _api.post('/sessions/$sessionId/retry');
  }

  /// History list — used by HistoryScreen.
  Future<List<SessionSummary>> listSessions({
    String? mode,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (mode != null) params['mode'] = mode;
    if (search != null) params['search'] = search;
    final raw = await _api.get('/sessions', params: params) as List<dynamic>;
    return raw
        .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> cancelSession() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    if (_currentAudioPath != null) {
      await deleteLocalFile(_currentAudioPath);
    }
    _currentSessionId = null;
    _currentAudioPath = null;
  }

  void dispose() {
    _recorder.dispose();
  }
}
