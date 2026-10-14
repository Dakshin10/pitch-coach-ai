import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/models/session_result.dart';
import 'package:pitch_coach/core/providers/session_results_provider.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/core/services/report_service.dart';
import 'package:pitch_coach/features/results/results_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockResult = SessionResult(
    id: 'test-report-sess-1',
    mode: 'presentation',
    topicOrQuestion: 'Pitch Coach Investor Pitch',
    durationSeconds: 125.0,
    wpm: 138.0,
    fillerWordCount: 1,
    fillerWordBreakdown: const {'um': 1},
    pauseCount: 3,
    avgPauseLength: 1.2,
    clarityScore: 92.0,
    confidenceScore: 84.0,
    overallScore: 88.0,
    aiFeedback: const [],
    createdAt: DateTime.now(),
    isAnalyzed: true,
  );

  group('Feature 10: ReportService Unit Tests', () {
    test('ReportService instance is accessible and handles offline/missing endpoints gracefully', () async {
      final service = ReportService.instance;
      expect(service, isNotNull);

      // Testing offline or invalid id returns null/false without uncaught exceptions
      final file = await service.downloadSessionReport('non-existent-id');
      expect(file, isNull);

      final weeklyFile = await service.downloadWeeklyReport();
      expect(weeklyFile, isNull);

      final shared = await service.openOrShareSessionReport('non-existent-id');
      expect(shared, isFalse);
    });
  });

  group('Feature 10: ResultsScreen Export PDF Report UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Renders Export PDF Report button and top bar share icon when result is available', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => SessionResultsProvider()),
          ],
          child: MaterialApp(
            home: ResultsScreen(
              initialResult: mockResult,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Top bar export / share button is visible
      final topShareButtonFinder = find.byKey(const Key('top_bar_share_report_button'));
      expect(topShareButtonFinder, findsOneWidget);

      // 2. Primary actions Export PDF Report button is present in the scrollable view
      final exportButtonFinder = find.byKey(const Key('export_pdf_report_button'));
      await tester.ensureVisible(exportButtonFinder);
      await tester.pump(const Duration(milliseconds: 300));
      expect(exportButtonFinder, findsOneWidget);
      expect(find.text('Export PDF Report'), findsOneWidget);

      // 3. Tapping the export button initiates action and shows progress state
      await tester.tap(exportButtonFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Button enters loading / generating state
      expect(find.text('Generating PDF Report...'), findsOneWidget);
      expect(find.byKey(const Key('export_pdf_report_button')), findsOneWidget);
    });
  });
}
