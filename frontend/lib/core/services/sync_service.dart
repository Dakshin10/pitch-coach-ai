import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'local_database_service.dart';

/// SyncService handles pull sync from backend /metrics/changes into local SQLite.
///
/// Principles:
/// - Pull applies each page in one single SQLite transaction.
/// - Keyset pagination advances cursor (updated_at, id) after each page.
/// - Null cursor triggers full history download.
/// - Safe for offline execution: silently aborts if no network.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _api = ApiClient.instance;
  final _localDb = LocalDatabaseService.instance;
  final _syncStreamController = StreamController<String>.broadcast();

  bool _isPulling = false;

  /// Stream of userIds whose data just synced.
  Stream<String> get onSyncCompleted => _syncStreamController.stream;
  bool get isPulling => _isPulling;

  /// Pulls recent changes from backend into local SQLite.
  /// Returns number of sessions synced.
  Future<int> pull({String? userId}) async {
    final effectiveUserId = userId ?? _localDb.currentUserId;
    if (effectiveUserId == null ||
        effectiveUserId.isEmpty ||
        effectiveUserId == 'guest') {
      return 0;
    }

    if (_isPulling) return 0;
    _isPulling = true;

    try {
      // 1. Verify network connectivity
      bool hasConnection = true;
      try {
        final connectivityResults = await Connectivity().checkConnectivity();
        hasConnection = connectivityResults.any(
          (c) => c != ConnectivityResult.none,
        );
      } catch (_) {
        hasConnection = true;
      }
      if (!hasConnection) {
        debugPrint('[SyncService] Offline: skipping pull sync.');
        return 0;
      }

      // Ensure local database is open for this user
      if (!_localDb.isOpen || _localDb.currentUserId != effectiveUserId) {
        await _localDb.initForUser(effectiveUserId);
      }

      // 2. Read sync cursor
      final cursor = await _localDb.getSyncCursor(effectiveUserId);
      String? cursorUpdatedAt = cursor['cursor_updated_at'];
      String? cursorId = cursor['cursor_id'];

      int totalSynced = 0;
      bool hasMore = true;

      // 3. Paginate through /metrics/changes
      while (hasMore) {
        final queryParams = <String, dynamic>{'limit': '200'};
        if (cursorUpdatedAt != null && cursorUpdatedAt.isNotEmpty) {
          queryParams['cursor_updated_at'] = cursorUpdatedAt;
        }
        if (cursorId != null && cursorId.isNotEmpty) {
          queryParams['cursor_id'] = cursorId;
        }

        final response =
            await _api.get('/metrics/changes', params: queryParams)
                as Map<String, dynamic>;

        final sessions = (response['sessions'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final fillers = (response['fillers'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final achievements = (response['achievements'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final nextCursorUpdatedAt =
            response['next_cursor_updated_at'] as String?;
        final nextCursorId = response['next_cursor_id'] as String?;
        hasMore = response['has_more'] as bool? ?? false;

        // Group fillers by session_id
        final fillersBySession = <String, List<Map<String, dynamic>>>{};
        for (final f in fillers) {
          final sid = f['session_id'] as String;
          fillersBySession.putIfAbsent(sid, () => []).add(f);
        }

        // Apply page in ONE atomic transaction
        await _localDb.db.transaction((txn) async {
          // Upsert sessions
          for (final row in sessions) {
            await txn.rawInsert(
              '''
              INSERT INTO session_metrics (
                id, user_id, mode, topic_or_question, duration_seconds, wpm,
                filler_word_count, pause_count, avg_pause_length, clarity_score,
                confidence_score, overall_score, status, created_at, local_date,
                tz_offset_minutes, updated_at, deleted_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                user_id = excluded.user_id,
                mode = excluded.mode,
                topic_or_question = excluded.topic_or_question,
                duration_seconds = excluded.duration_seconds,
                wpm = excluded.wpm,
                filler_word_count = excluded.filler_word_count,
                pause_count = excluded.pause_count,
                avg_pause_length = excluded.avg_pause_length,
                clarity_score = excluded.clarity_score,
                confidence_score = excluded.confidence_score,
                overall_score = excluded.overall_score,
                status = excluded.status,
                created_at = excluded.created_at,
                local_date = excluded.local_date,
                tz_offset_minutes = excluded.tz_offset_minutes,
                updated_at = excluded.updated_at,
                deleted_at = excluded.deleted_at;
            ''',
              [
                row['id'],
                row['user_id'],
                row['mode'] ?? 'interview',
                row['topic_or_question'] ?? '',
                (row['duration_seconds'] as num?)?.toDouble() ?? 0.0,
                (row['wpm'] as num?)?.toDouble() ?? 0.0,
                (row['filler_word_count'] as num?)?.toInt() ?? 0,
                (row['pause_count'] as num?)?.toInt() ?? 0,
                (row['avg_pause_length'] as num?)?.toDouble() ?? 0.0,
                (row['clarity_score'] as num?)?.toDouble() ?? 0.0,
                (row['confidence_score'] as num?)?.toDouble() ?? 0.0,
                (row['overall_score'] as num?)?.toDouble() ?? 0.0,
                row['status'] ?? 'pending',
                row['created_at'],
                row['local_date'],
                (row['tz_offset_minutes'] as num?)?.toInt() ?? 0,
                row['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
                row['deleted_at'],
              ],
            );
          }

          // Upsert fillers for updated sessions
          for (final entry in fillersBySession.entries) {
            await txn.rawDelete(
              'DELETE FROM session_fillers WHERE session_id = ?;',
              [entry.key],
            );
            for (final f in entry.value) {
              await txn.rawInsert(
                '''
                INSERT OR REPLACE INTO session_fillers (session_id, filler_word, count)
                VALUES (?, ?, ?);
              ''',
                [
                  entry.key,
                  f['filler_word'] as String,
                  (f['count'] as num?)?.toInt() ?? 1,
                ],
              );
            }
          }

          // Upsert achievements
          for (final a in achievements) {
            await txn.rawInsert(
              '''
              INSERT INTO user_achievements (user_id, achievement_key, unlocked_at, updated_at)
              VALUES (?, ?, ?, ?)
              ON CONFLICT(user_id, achievement_key) DO UPDATE SET
                unlocked_at = excluded.unlocked_at,
                updated_at = excluded.updated_at;
            ''',
              [
                a['user_id'] ?? effectiveUserId,
                a['achievement_key'],
                a['unlocked_at'],
                a['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
              ],
            );
          }

          // Advance cursor inside the same transaction
          if (nextCursorUpdatedAt != null) {
            await txn.rawInsert(
              '''
              INSERT INTO sync_state (user_id, last_cursor_updated_at, last_cursor_id)
              VALUES (?, ?, ?)
              ON CONFLICT(user_id) DO UPDATE SET
                last_cursor_updated_at = excluded.last_cursor_updated_at,
                last_cursor_id = excluded.last_cursor_id;
            ''',
              [effectiveUserId, nextCursorUpdatedAt, nextCursorId],
            );
          }
        });

        totalSynced += sessions.length;
        cursorUpdatedAt = nextCursorUpdatedAt;
        cursorId = nextCursorId;

        // If no items were returned or no advance, prevent infinite loop
        if (sessions.isEmpty && achievements.isEmpty) {
          break;
        }
      }

      _syncStreamController.add(effectiveUserId);
      debugPrint(
        '[SyncService] Successfully pulled $totalSynced sessions for $effectiveUserId.',
      );
      return totalSynced;
    } catch (e, stack) {
      debugPrint('[SyncService] Error during pull sync: $e\n$stack');
      return 0;
    } finally {
      _isPulling = false;
    }
  }

  void dispose() {
    _syncStreamController.close();
  }
}
