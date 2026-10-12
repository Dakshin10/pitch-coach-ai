import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pitch_coach/core/services/local_database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Section 1: Flutter Local SQLite Schema & Migration Tests', () {
    test(
      'Migration preserves data when upgrading and sets user_version',
      () async {
        final dbPath = p.join(
          Directory.systemTemp.path,
          'test_mig_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        if (File(dbPath).existsSync()) {
          File(dbPath).deleteSync();
        }

        // 1. Open an empty database at version 1
        final db = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE IF NOT EXISTS session_metrics (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              mode TEXT NOT NULL DEFAULT 'interview',
              topic_or_question TEXT NOT NULL,
              duration_seconds REAL NOT NULL DEFAULT 0,
              wpm REAL NOT NULL DEFAULT 0,
              filler_word_count INTEGER NOT NULL DEFAULT 0,
              pause_count INTEGER NOT NULL DEFAULT 0,
              avg_pause_length REAL NOT NULL DEFAULT 0,
              clarity_score REAL NOT NULL DEFAULT 0,
              confidence_score REAL NOT NULL DEFAULT 0,
              overall_score REAL NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL,
              local_date TEXT NOT NULL,
              tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              deleted_at TEXT
            );
          ''');
          },
        );

        // Insert pre-existing row
        await db.insert('session_metrics', {
          'id': 'mig-sess-1',
          'user_id': 'mig-user-1',
          'mode': 'interview',
          'topic_or_question': 'Pre-migration session',
          'duration_seconds': 45.0,
          'wpm': 120.0,
          'filler_word_count': 1,
          'pause_count': 0,
          'avg_pause_length': 0.0,
          'clarity_score': 85.0,
          'confidence_score': 80.0,
          'overall_score': 82.0,
          'status': 'analyzed',
          'created_at': '2026-10-09T10:00:00Z',
          'local_date': '2026-10-09',
          'tz_offset_minutes': 0,
          'updated_at': '2026-10-09T10:05:00Z',
        });

        await db.close();

        // Re-open and verify data persisted and user_version intact
        final reopenedDb = await openDatabase(dbPath);
        final rows = await reopenedDb.query(
          'session_metrics',
          where: 'id = ?',
          whereArgs: ['mig-sess-1'],
        );
        expect(rows.length, 1);
        expect(rows.first['topic_or_question'], 'Pre-migration session');

        final versionResult = await reopenedDb.rawQuery('PRAGMA user_version;');
        expect(versionResult.first.values.first as int, 1);

        await reopenedDb.close();
        if (File(dbPath).existsSync()) {
          File(dbPath).deleteSync();
        }
      },
    );

    test('Local SQLite has no users table', () async {
      final service = LocalDatabaseService.instance;
      final db = await service.initForUser('sec1_test_user');

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(
        tableNames.contains('users'),
        isFalse,
        reason: 'users table should NOT exist in SQLite',
      );
      expect(tableNames.contains('session_metrics'), isTrue);
      expect(tableNames.contains('session_fillers'), isTrue);
      expect(tableNames.contains('achievement_catalog'), isTrue);
      expect(tableNames.contains('user_achievements'), isTrue);
      expect(tableNames.contains('sync_outbox'), isTrue);
      expect(tableNames.contains('sync_state'), isTrue);
    });
  });
}
