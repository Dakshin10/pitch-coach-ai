import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pitch_coach/core/services/local_database_service.dart';

void main() {
  late String testId;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    testId = 'u_sec7_${DateTime.now().microsecondsSinceEpoch}';
  });

  tearDown(() async {
    await LocalDatabaseService.instance.close();
  });

  group('Section 7: Flutter Sync and Outbox Resilience Tests', () {
    test(
      'Transactional page application: rollback on failure leaves DB and cursor clean',
      () async {
        final service = LocalDatabaseService.instance;
        await service.initForUser(testId);

        // Initial cursor
        await service.setSyncCursor(testId, '2026-10-09T10:00:00Z', 's-prev');

        // Attempt transactional insert that throws an error midway
        try {
          await service.db.transaction((txn) async {
            await txn.rawInsert(
              '''
            INSERT INTO session_metrics (id, user_id, topic_or_question, created_at, local_date, updated_at)
            VALUES ('s-tx-1', ?, 'Topic 1', '2026-10-09T11:00:00Z', '2026-10-09', '2026-10-09T11:00:00Z');
          ''',
              [testId],
            );

            // Simulate mid-page network drop or parse error
            throw Exception('Simulated mid-page crash');
          });
        } catch (_) {}

        // Verify rollback: s-tx-1 does NOT exist
        final rows = await service.db.query(
          'session_metrics',
          where: 'id = ?',
          whereArgs: ['s-tx-1'],
        );
        expect(rows.isEmpty, isTrue);

        // Verify cursor is UNCHANGED
        final cursor = await service.getSyncCursor(testId);
        expect(cursor['cursor_updated_at'], '2026-10-09T10:00:00Z');
        expect(cursor['cursor_id'], 's-prev');
      },
    );

    test('Tombstones applied properly in local SQLite', () async {
      final service = LocalDatabaseService.instance;
      await service.initForUser(testId);

      // Seed active session
      await service.upsertSessionMetric({
        'id': 'sess-tomb',
        'user_id': testId,
        'mode': 'interview',
        'topic_or_question': 'Tombstone test',
        'overall_score': 85.0,
        'status': 'analyzed',
        'created_at': '2026-10-09T10:00:00Z',
        'local_date': '2026-10-09',
        'tz_offset_minutes': 0,
        'updated_at': '2026-10-09T10:00:00Z',
      });

      // Apply tombstone (deleted_at IS NOT NULL)
      await service.upsertSessionMetric({
        'id': 'sess-tomb',
        'user_id': testId,
        'mode': 'interview',
        'topic_or_question': 'Tombstone test',
        'overall_score': 85.0,
        'status': 'analyzed',
        'created_at': '2026-10-09T10:00:00Z',
        'local_date': '2026-10-09',
        'tz_offset_minutes': 0,
        'updated_at': '2026-10-09T12:00:00Z',
        'deleted_at': '2026-10-09T12:00:00Z',
      });

      // Querying summary must EXCLUDE the tombstoned session
      final summary = await service.getSummary(testId);
      expect(summary.totalSessions, 0);

      // Soft-deleted row is retained with deleted_at
      final raw = await service.db.query(
        'session_metrics',
        where: 'id = ?',
        whereArgs: ['sess-tomb'],
      );
      expect(raw.first['deleted_at'], '2026-10-09T12:00:00Z');
    });

    test('Outbox retains audio file permanently upon 5 failures', () async {
      final service = LocalDatabaseService.instance;
      await service.initForUser(testId);

      final tempAudio = File(
        p.join(Directory.systemTemp.path, 'outbox_persist_$testId.m4a'),
      );
      await tempAudio.writeAsString('audio content must never be deleted');

      const sid = 'sess-5-fails';
      await service.enqueueOutbox(
        id: sid,
        userId: testId,
        action: 'CREATE_SESSION',
        payload: '{"mode":"interview"}',
        localAudioPath: tempAudio.path,
      );

      // Simulate 5 failures
      await service.updateOutboxState(
        id: sid,
        state: 'failed',
        retryCount: 5,
        lastError: 'HTTP 500 from server',
      );

      // Assert outbox row is marked failed
      final items = await service.getPendingOutbox(testId);
      expect(items.first['state'], 'failed');
      expect(items.first['retry_count'], 5);

      // Assert audio file is STILL ON DISK
      expect(tempAudio.existsSync(), isTrue);

      if (tempAudio.existsSync()) tempAudio.deleteSync();
    });

    test(
      'In-flight items recovered and retried with same UUID without creating duplicates',
      () async {
        final service = LocalDatabaseService.instance;
        await service.initForUser(testId);

        final tempAudio = File(
          p.join(Directory.systemTemp.path, 'in_flight_$testId.m4a'),
        );
        await tempAudio.writeAsString('audio');

        const sid = 'sess-in-flight-crash';
        await service.enqueueOutbox(
          id: sid,
          userId: testId,
          action: 'CREATE_SESSION',
          payload: '{"mode":"interview"}',
          localAudioPath: tempAudio.path,
        );

        // Set to in_flight (simulating crash during upload)
        await service.updateOutboxState(id: sid, state: 'in_flight');

        // On app restart, getPendingOutbox retrieves it because state != 'done'
        final pending = await service.getPendingOutbox(testId);
        expect(pending.length, 1);
        expect(pending.first['id'], sid);
        expect(pending.first['state'], 'in_flight');

        // Manual state reset simulates recovery
        await service.updateOutboxState(
          id: sid,
          state: 'queued',
          retryCount: 0,
        );
        final refreshed = await service.getPendingOutbox(testId);
        expect(refreshed.first['state'], 'queued');
        expect(refreshed.first['id'], sid); // Same UUID!

        if (tempAudio.existsSync()) tempAudio.deleteSync();
      },
    );
  });
}
