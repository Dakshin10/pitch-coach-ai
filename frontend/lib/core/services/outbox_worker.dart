import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/session_result.dart';
import 'api_client.dart';
import 'local_database_service.dart';
import 'sync_service.dart';

/// Worker responsible for offline-first session creation and sync outbox processing.
///
/// Principles:
/// - Runs on connectivity change and app start.
/// - Processes outbox items in order (upload audio, call POST /sessions, update local row, delete outbox row).
/// - Exponential backoff: 30s, 2m, 10m, 1h.
/// - After 5 failures, sets state='failed' and preserves the local audio file forever.
class OutboxWorker {
  OutboxWorker._();
  static final OutboxWorker instance = OutboxWorker._();

  final _api = ApiClient.instance;
  final _localDb = LocalDatabaseService.instance;
  final _sync = SyncService.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isProcessing = false;

  void init() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint(
          '[OutboxWorker] Connectivity restored. Triggering outbox processing.',
        );
        process();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Duration getBackoffDuration(int retryCount) {
    switch (retryCount) {
      case 1:
        return const Duration(seconds: 30);
      case 2:
        return const Duration(minutes: 2);
      case 3:
        return const Duration(minutes: 10);
      case 4:
      default:
        return const Duration(hours: 1);
    }
  }

  /// Processes all pending outbox items for the active user.
  Future<void> process({String? userId}) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      bool hasConnection = true;
      try {
        final connectivity = await Connectivity().checkConnectivity();
        hasConnection = connectivity.any((c) => c != ConnectivityResult.none);
      } catch (_) {
        hasConnection = true;
      }
      if (!hasConnection) {
        debugPrint('[OutboxWorker] Offline: skipping outbox processing.');
        return;
      }

      final effectiveUserId = userId ?? _localDb.currentUserId;
      if (effectiveUserId == null ||
          effectiveUserId.isEmpty ||
          effectiveUserId == 'guest') {
        return;
      }

      if (!_localDb.isOpen || _localDb.currentUserId != effectiveUserId) {
        await _localDb.initForUser(effectiveUserId);
      }

      final pendingItems = await _localDb.getPendingOutbox(effectiveUserId);
      if (pendingItems.isEmpty) return;

      for (final item in pendingItems) {
        final id = item['id'] as String;
        final state = item['state'] as String? ?? 'queued';
        final retryCount = (item['retry_count'] as num?)?.toInt() ?? 0;
        final nextAttemptStr = item['next_attempt_at'] as String?;

        // Skip permanently failed items until manual retry
        if (state == 'failed') {
          continue;
        }

        // Check if backoff window has expired
        if (nextAttemptStr != null && nextAttemptStr.isNotEmpty) {
          final nextAttempt = DateTime.tryParse(nextAttemptStr);
          if (nextAttempt != null &&
              DateTime.now().toUtc().isBefore(nextAttempt)) {
            continue;
          }
        }

        // Set state to in_flight
        await _localDb.updateOutboxState(id: id, state: 'in_flight');

        final action = item['action'] as String;
        if (action == 'CREATE_SESSION') {
          await _processCreateSession(item, effectiveUserId, retryCount);
        }
      }
    } catch (e, stack) {
      debugPrint(
        '[OutboxWorker] Unexpected error processing outbox: $e\n$stack',
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processCreateSession(
    Map<String, dynamic> item,
    String userId,
    int currentRetryCount,
  ) async {
    final id = item['id'] as String;
    final audioPath = item['local_audio_path'] as String?;
    final rawPayload = item['payload'] as String? ?? '{}';
    final payload = (jsonDecode(rawPayload) as Map<String, dynamic>?) ?? {};

    if (audioPath == null || !await File(audioPath).exists()) {
      debugPrint(
        '[OutboxWorker] Audio file not found at $audioPath. Marking outbox item failed.',
      );
      await _localDb.updateOutboxState(
        id: id,
        state: 'failed',
        lastError: 'Local audio file not found.',
      );
      return;
    }

    try {
      final multipartFile = await MultipartFile.fromFile(
        audioPath,
        filename: 'recording.m4a',
      );

      final formData = FormData.fromMap({
        'audio_file': multipartFile,
        'session_id': id,
        'mode': payload['mode'] ?? 'interview',
        'topic_or_question': payload['topic_or_question'] ?? 'Practice session',
        'duration_seconds': (payload['duration_seconds'] ?? 0.0).toString(),
        'local_date': payload['local_date'],
        'tz_offset_minutes': (payload['tz_offset_minutes'] ?? 0).toString(),
      });

      final raw =
          await _api.postMultipart('/sessions', formData)
              as Map<String, dynamic>;
      final result = SessionResult.fromJson(raw);

      // 1. Update local session_metrics row with analyzed results
      await _localDb.upsertSessionMetric({
        'id': result.id,
        'user_id': userId,
        'mode': result.mode,
        'topic_or_question': result.topicOrQuestion,
        'duration_seconds': result.durationSeconds,
        'wpm': result.wpm,
        'filler_word_count': result.fillerWordCount,
        'pause_count': result.pauseCount,
        'avg_pause_length': result.avgPauseLength,
        'clarity_score': result.clarityScore,
        'confidence_score': result.confidenceScore,
        'overall_score': result.overallScore,
        'status': result.isAnalyzed
            ? (result.analysisFailed ? 'failed' : 'analyzed')
            : 'analyzing',
        'created_at': result.createdAt.toUtc().toIso8601String(),
        'local_date': result.localDate,
        'tz_offset_minutes': result.tzOffsetMinutes ?? 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Update local fillers
      if (result.fillerWordBreakdown.isNotEmpty) {
        final fillers = result.fillerWordBreakdown.entries
            .map((e) => {'filler_word': e.key, 'count': e.value})
            .toList();
        await _localDb.replaceFillers(result.id, fillers);
      }

      // 3. Delete outbox row on success
      await _localDb.deleteOutbox(id);
      debugPrint(
        '[OutboxWorker] Successfully synced session $id and removed from outbox.',
      );

      // 4. Trigger pull sync to refresh all stats and achievements
      await _sync.pull(userId: userId);
    } catch (e) {
      final newRetryCount = currentRetryCount + 1;
      final isFinalFailure = newRetryCount >= 5;

      final nextAttempt = isFinalFailure
          ? null
          : DateTime.now()
                .toUtc()
                .add(getBackoffDuration(newRetryCount))
                .toIso8601String();

      await _localDb.updateOutboxState(
        id: id,
        state: isFinalFailure ? 'failed' : 'queued',
        retryCount: newRetryCount,
        nextAttemptAt: nextAttempt,
        lastError: e.toString(),
      );

      debugPrint(
        '[OutboxWorker] Upload failed for session $id (attempt $newRetryCount/5). '
        'Next attempt: $nextAttempt. Error: $e',
      );
    }
  }

  /// Manually retry an outbox item that failed.
  Future<void> retry(String id) async {
    await _localDb.updateOutboxState(
      id: id,
      state: 'queued',
      retryCount: 0,
      nextAttemptAt: null,
      lastError: null,
    );
    await process();
  }
}
