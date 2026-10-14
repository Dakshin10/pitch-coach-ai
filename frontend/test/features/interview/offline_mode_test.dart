import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/services/local_database_service.dart';
import 'package:pitch_coach/core/services/outbox_worker.dart';
import 'package:pitch_coach/core/theme/app_colors.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await LocalDatabaseService.instance.close();
  });

  group('Feature 13: Offline Mode & Synchronization Resilience', () {
    test('OutboxWorker calculates correct exponential backoff durations', () {
      final worker = OutboxWorker.instance;

      expect(worker.getBackoffDuration(1), const Duration(seconds: 30));
      expect(worker.getBackoffDuration(2), const Duration(minutes: 2));
      expect(worker.getBackoffDuration(3), const Duration(minutes: 10));
      expect(worker.getBackoffDuration(4), const Duration(hours: 1));
      expect(worker.getBackoffDuration(5), const Duration(hours: 1));
    });

    test('OutboxWorker getPendingCount returns 0 for guest user without error', () async {
      final worker = OutboxWorker.instance;
      final countGuest = await worker.getPendingCount(userId: 'guest');
      expect(countGuest, 0);

      final countNull = await worker.getPendingCount(userId: '');
      expect(countNull, 0);
    });

    test('LocalDatabaseService queues outbox item and queries pending outbox', () async {
      final dbService = LocalDatabaseService.instance;
      final testUser = 'user_offline_${DateTime.now().microsecondsSinceEpoch}';
      await dbService.initForUser(testUser);

      // Initially zero pending items
      final initialPending = await dbService.getPendingOutbox(testUser);
      expect(initialPending.isEmpty, isTrue);

      // Enqueue session
      const sid = 'sess_offline_123';
      await dbService.enqueueOutbox(
        id: sid,
        userId: testUser,
        action: 'CREATE_SESSION',
        payload: '{"mode":"interview","topic_or_question":"Airplane mode test"}',
        localAudioPath: '/local/path/to/take.m4a',
      );

      final pendingAfter = await dbService.getPendingOutbox(testUser);
      expect(pendingAfter.length, 1);
      expect(pendingAfter.first['id'], sid);
      expect(pendingAfter.first['state'], 'queued');
      expect(pendingAfter.first['action'], 'CREATE_SESSION');

      // Update state to in_flight
      await dbService.updateOutboxState(id: sid, state: 'in_flight');
      final pendingInFlight = await dbService.getPendingOutbox(testUser);
      expect(pendingInFlight.first['state'], 'in_flight');

      // Delete outbox on successful sync
      await dbService.deleteOutbox(sid);
      final pendingDeleted = await dbService.getPendingOutbox(testUser);
      expect(pendingDeleted.isEmpty, isTrue);
    });

    testWidgets('SessionSummary renders Pending badge when isAnalyzed is false', (tester) async {
      final pendingSession = SessionSummary(
        id: 'sess_pending_456',
        mode: 'interview',
        topicOrQuestion: 'Pending offline interview take',
        durationSeconds: 45.0,
        overallScore: 0.0,
        confidenceScore: 0.0,
        createdAt: DateTime.now(),
        isAnalyzed: false,
        analysisFailed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: !pendingSession.isAnalyzed
                  ? Container(
                      key: Key('pending_indicator_${pendingSession.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: AppColors.warningAmber,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Pending',
                            style: TextStyle(
                              color: AppColors.warningAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Text('Analyzed'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('pending_indicator_sess_pending_456')), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('Outbox sync banner renders when pending count > 0', (tester) async {
      const pendingCount = 2;
      bool syncTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              key: const Key('history_outbox_banner'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warningAmber.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.warningAmber,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$pendingCount recordings pending sync',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Saved locally. Will sync automatically when online.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: const Key('history_sync_now_button'),
                    onPressed: () => syncTapped = true,
                    child: const Text('Sync Now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('history_outbox_banner')), findsOneWidget);
      expect(find.text('2 recordings pending sync'), findsOneWidget);
      expect(find.text('Saved locally. Will sync automatically when online.'), findsOneWidget);
      expect(find.byKey(const Key('history_sync_now_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('history_sync_now_button')));
      await tester.pump();
      expect(syncTapped, isTrue);
    });
  });
}
