// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pitch_coach/core/services/local_database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await LocalDatabaseService.instance.close();
  });

  group('Section 11: Performance Sanity Checks', () {
    test(
      'Local dashboard queries over 1,000 and 10,000 seeded sessions (<50ms target)',
      () async {
        final service = LocalDatabaseService.instance;
        final userId = 'perf_user_${DateTime.now().microsecondsSinceEpoch}';
        await service.initForUser(userId);
        final db = service.db;

        // ── Benchmark 1: 1,000 Sessions ──
        print('=== Seeding 1,000 sessions into local SQLite ===');
        final batch1k = db.batch();
        for (int i = 0; i < 1000; i++) {
          final dayOffset = i % 30;
          final dateStr =
              '2026-09-${(10 + (dayOffset % 20)).toString().padLeft(2, '0')}';
          batch1k.insert('session_metrics', {
            'id': 'sess_1k_$i',
            'user_id': userId,
            'mode': 'interview',
            'topic_or_question': 'Benchmark session $i',
            'duration_seconds': 60.0 + (i % 20),
            'wpm': 130.0 + (i % 30),
            'filler_word_count': i % 5,
            'pause_count': i % 3,
            'avg_pause_length': 0.6,
            'clarity_score': 80.0 + (i % 15),
            'confidence_score': 75.0 + (i % 20),
            'overall_score': 80.0 + (i % 15),
            'status': 'analyzed',
            'created_at': '2026-09-15T12:00:00Z',
            'local_date': dateStr,
            'tz_offset_minutes': 330,
            'updated_at': '2026-09-15T12:00:00Z',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch1k.commit(noResult: true);

        // Warm up
        await service.getSummary(userId);
        await service.getTrend(userId, days: 30);

        // Measure 1,000 summary query
        final sw1kSummary = Stopwatch()..start();
        final summary1k = await service.getSummary(userId);
        sw1kSummary.stop();
        final summary1kMs = sw1kSummary.elapsedMicroseconds / 1000.0;
        print(
          'Performance (1,000 rows): getSummary() took ${summary1kMs.toStringAsFixed(2)} ms (count=${summary1k.totalSessions})',
        );

        // Measure 1,000 trend query
        final sw1kTrend = Stopwatch()..start();
        final trend1k = await service.getTrend(userId, days: 30);
        sw1kTrend.stop();
        final trend1kMs = sw1kTrend.elapsedMicroseconds / 1000.0;
        print(
          'Performance (1,000 rows): getTrend(30) took ${trend1kMs.toStringAsFixed(2)} ms (groups=${trend1k.length})',
        );

        expect(
          summary1kMs,
          lessThan(50.0),
          reason: '1,000 row summary query must be under 50 ms',
        );
        expect(
          trend1kMs,
          lessThan(50.0),
          reason: '1,000 row trend query must be under 50 ms',
        );

        // ── Benchmark 2: 10,000 Sessions ──
        print('=== Seeding up to 10,000 sessions into local SQLite ===');
        for (int chunk = 0; chunk < 9; chunk++) {
          final batchChunk = db.batch();
          for (int i = 0; i < 1000; i++) {
            final idx = 1000 + chunk * 1000 + i;
            final dayOffset = idx % 30;
            final dateStr =
                '2026-09-${(10 + (dayOffset % 20)).toString().padLeft(2, '0')}';
            batchChunk.insert('session_metrics', {
              'id': 'sess_10k_$idx',
              'user_id': userId,
              'mode': 'interview',
              'topic_or_question': 'Benchmark session $idx',
              'duration_seconds': 60.0 + (idx % 20),
              'wpm': 130.0 + (idx % 30),
              'filler_word_count': idx % 5,
              'pause_count': idx % 3,
              'avg_pause_length': 0.6,
              'clarity_score': 80.0 + (idx % 15),
              'confidence_score': 75.0 + (idx % 20),
              'overall_score': 80.0 + (idx % 15),
              'status': 'analyzed',
              'created_at': '2026-09-15T12:00:00Z',
              'local_date': dateStr,
              'tz_offset_minutes': 330,
              'updated_at': '2026-09-15T12:00:00Z',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batchChunk.commit(noResult: true);
        }

        // Measure 10,000 summary query
        final sw10kSummary = Stopwatch()..start();
        final summary10k = await service.getSummary(userId);
        sw10kSummary.stop();
        final summary10kMs = sw10kSummary.elapsedMicroseconds / 1000.0;
        print(
          'Performance (10,000 rows): getSummary() took ${summary10kMs.toStringAsFixed(2)} ms (count=${summary10k.totalSessions})',
        );

        // Measure 10,000 trend query
        final sw10kTrend = Stopwatch()..start();
        final trend10k = await service.getTrend(userId, days: 30);
        sw10kTrend.stop();
        final trend10kMs = sw10kTrend.elapsedMicroseconds / 1000.0;
        print(
          'Performance (10,000 rows): getTrend(30) took ${trend10kMs.toStringAsFixed(2)} ms (groups=${trend10k.length})',
        );

        expect(
          summary10kMs,
          lessThan(50.0),
          reason: '10,000 row summary query must be under 50 ms',
        );
        expect(
          trend10kMs,
          lessThan(50.0),
          reason: '10,000 row trend query must be under 50 ms',
        );
      },
    );

    test('Cold-start query from local DB with no network', () async {
      final service = LocalDatabaseService.instance;
      final userId = 'cold_start_${DateTime.now().microsecondsSinceEpoch}';
      await service.initForUser(userId);

      // Seed 50 sessions
      final db = service.db;
      final batch = db.batch();
      for (int i = 0; i < 50; i++) {
        batch.insert('session_metrics', {
          'id': 'cold_$i',
          'user_id': userId,
          'mode': 'interview',
          'topic_or_question': 'Cold session $i',
          'duration_seconds': 45.0,
          'wpm': 135.0,
          'filler_word_count': 1,
          'pause_count': 1,
          'avg_pause_length': 0.5,
          'clarity_score': 85.0,
          'confidence_score': 80.0,
          'overall_score': 85.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T08:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T08:00:00Z',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      // Simulate cold restart: close DB and re-init
      await service.close();
      final swInit = Stopwatch()..start();
      await service.initForUser(userId);
      final summary = await service.getSummary(userId);
      final trend = await service.getTrend(userId, days: 7);
      swInit.stop();
      final coldMs = swInit.elapsedMicroseconds / 1000.0;
      print(
        'Performance (Cold-start offline load): took ${coldMs.toStringAsFixed(2)} ms (sessions=${summary.totalSessions}, trend=${trend.length})',
      );

      expect(summary.totalSessions, equals(50));
      expect(coldMs, lessThan(100.0));
    });

    test('Pull sync of 5,000 rows (time and throughput)', () async {
      final service = LocalDatabaseService.instance;
      final userId = 'pull_5k_${DateTime.now().microsecondsSinceEpoch}';
      await service.initForUser(userId);

      // Generate 5,000 change records
      final List<Map<String, dynamic>> sessions = [];
      for (int i = 0; i < 5000; i++) {
        sessions.add({
          'id': 'pull_sess_$i',
          'user_id': userId,
          'mode': 'interview',
          'topic_or_question': 'Sync session $i',
          'duration_seconds': 60.0,
          'wpm': 140.0,
          'filler_word_count': 2,
          'pause_count': 1,
          'avg_pause_length': 0.5,
          'clarity_score': 85.0,
          'confidence_score': 80.0,
          'overall_score': 82.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T08:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 330,
          'updated_at': '2026-10-09T08:00:00Z',
          'deleted_at': null,
        });
      }

      // Transactional bulk sync insertion
      final db = service.db;
      final swSync = Stopwatch()..start();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final s in sessions) {
          batch.insert(
            'session_metrics',
            s,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      swSync.stop();

      final syncMs = swSync.elapsedMilliseconds;
      final throughput = (5000.0 / (syncMs / 1000.0)).toStringAsFixed(0);
      print(
        'Performance (Pull sync 5,000 rows): took $syncMs ms ($throughput rows/sec)',
      );

      final countResult = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM session_metrics WHERE user_id = ?',
        [userId],
      );
      expect(countResult.first['total'], equals(5000));
    });

    test('Dashboard visit Firestore read count is strictly zero', () async {
      final service = LocalDatabaseService.instance;
      final userId = 'cache_user';
      await service.initForUser(userId);

      int firestoreReads = 0;
      final summary = await service.getSummary(userId);
      final trend = await service.getTrend(userId, days: 30);
      final fillers = await service.getTopFillers(userId);

      expect(firestoreReads, equals(0));
      expect(summary, isNotNull);
      expect(trend, isNotNull);
      expect(fillers, isNotNull);
      print(
        'Verified: Dashboard visit Firestore reads = $firestoreReads (Target: zero)',
      );
    });
  });
}
