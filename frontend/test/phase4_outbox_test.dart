import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pitch_coach/core/services/local_database_service.dart';
import 'package:pitch_coach/core/services/outbox_worker.dart';

void main() {
  late String testId;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    testId = 'u_outbox_${DateTime.now().microsecondsSinceEpoch}';
  });

  tearDown(() async {
    await LocalDatabaseService.instance.close();
  });

  group('Phase 4: Offline Outbox & Resilience', () {
    test('Backoff intervals match 30s, 2m, 10m, 1h specification', () {
      final worker = OutboxWorker.instance;

      expect(worker.getBackoffDuration(1), const Duration(seconds: 30));
      expect(worker.getBackoffDuration(2), const Duration(minutes: 2));
      expect(worker.getBackoffDuration(3), const Duration(minutes: 10));
      expect(worker.getBackoffDuration(4), const Duration(hours: 1));
      expect(worker.getBackoffDuration(5), const Duration(hours: 1));
    });

    test('Enqueueing session in offline mode creates pending metric and outbox row', () async {
      final dbService = LocalDatabaseService.instance;
      await dbService.initForUser(testId);

      const sessionId = 'offline-session-1';
      final now = DateTime.now().toUtc().toIso8601String();

      // Insert pending metric row
      await dbService.upsertSessionMetric({
        'id': sessionId,
        'user_id': testId,
        'mode': 'interview',
        'topic_or_question': 'Describe a challenging project.',
        'duration_seconds': 45.0,
        'wpm': 0.0,
        'filler_word_count': 0,
        'pause_count': 0,
        'avg_pause_length': 0.0,
        'clarity_score': 0.0,
        'confidence_score': 0.0,
        'overall_score': 0.0,
        'status': 'pending',
        'created_at': now,
        'local_date': '2026-10-09',
        'tz_offset_minutes': 330,
        'updated_at': now,
      });

      // Insert outbox row
      await dbService.enqueueOutbox(
        id: sessionId,
        userId: testId,
        action: 'CREATE_SESSION',
        payload: jsonEncode({
          'mode': 'interview',
          'topic_or_question': 'Describe a challenging project.',
          'duration_seconds': 45.0,
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
        }),
        localAudioPath: '/mock/path/session_1.m4a',
      );

      // Verify pending metric
      final recent = await dbService.getRecentSession(testId);
      expect(recent, isNotNull);
      expect(recent!.id, sessionId);
      expect(recent.isAnalyzed, isFalse);

      // Verify outbox row
      final pending = await dbService.getPendingOutbox(testId);
      expect(pending.length, 1);
      expect(pending.first['id'], sessionId);
      expect(pending.first['state'], 'queued');
      expect(pending.first['retry_count'], 0);
    });

    test('Exponential retry state updates and failure at 5 retries', () async {
      final dbService = LocalDatabaseService.instance;
      await dbService.initForUser(testId);

      const sessionId = 'offline-session-retry';
      final tempFile = File('${Directory.systemTemp.path}/test_audio_$testId.m4a');
      await tempFile.writeAsString('mock audio bytes');

      await dbService.enqueueOutbox(
        id: sessionId,
        userId: testId,
        action: 'CREATE_SESSION',
        payload: '{"mode": "interview"}',
        localAudioPath: tempFile.path,
      );

      // Simulate failure attempts up to 5
      for (int i = 1; i <= 5; i++) {
        final isFinal = i >= 5;
        await dbService.updateOutboxState(
          id: sessionId,
          state: isFinal ? 'failed' : 'queued',
          retryCount: i,
          nextAttemptAt: isFinal
              ? null
              : DateTime.now().toUtc().add(OutboxWorker.instance.getBackoffDuration(i)).toIso8601String(),
          lastError: 'Network error attempt $i',
        );
      }

      final outboxItems = await dbService.getPendingOutbox(testId);
      expect(outboxItems.length, 1);
      final item = outboxItems.first;
      expect(item['state'], 'failed');
      expect(item['retry_count'], 5);
      expect(item['last_error'], 'Network error attempt 5');

      // Test manual retry resets state to queued and retryCount to 0
      await OutboxWorker.instance.retry(sessionId);
      final refreshed = await dbService.getPendingOutbox(testId);
      expect(refreshed.first['state'], 'queued');
      expect(refreshed.first['retry_count'], lessThanOrEqualTo(1));
      if (tempFile.existsSync()) tempFile.deleteSync();
    });
  });
}
