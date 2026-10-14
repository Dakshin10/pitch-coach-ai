import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/services/notification_service.dart';
import 'package:pitch_coach/features/profile/widgets/practice_goals_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Feature 12: NotificationService Quiet Hours Tests', () {
    final notifService = NotificationService.instance;

    test('isQuietHours correctly detects night hours in default window (22 - 8)', () {
      expect(
        notifService.isQuietHours(const TimeOfDay(hour: 22, minute: 0)),
        isTrue,
      );
      expect(
        notifService.isQuietHours(const TimeOfDay(hour: 23, minute: 30)),
        isTrue,
      );
      expect(
        notifService.isQuietHours(const TimeOfDay(hour: 3, minute: 15)),
        isTrue,
      );
      expect(
        notifService.isQuietHours(const TimeOfDay(hour: 7, minute: 59)),
        isTrue,
      );
      expect(
        notifService.isQuietHours(const TimeOfDay(hour: 8, minute: 0)),
        isFalse,
      );
      expect(
        notifService.isQuietHours(const TimeOfDay(hour: 12, minute: 0)),
        isFalse,
      );
      expect(
        notifService.isQuietHours(const TimeOfDay(hour: 21, minute: 59)),
        isFalse,
      );
    });

    test('adjustForQuietHours clamps time to end hour if inside quiet hours', () {
      final nightTime = const TimeOfDay(hour: 23, minute: 0);
      final clamped = notifService.adjustForQuietHours(nightTime);
      expect(clamped.hour, equals(8));
      expect(clamped.minute, equals(0));

      final daytime = const TimeOfDay(hour: 14, minute: 30);
      final unclamped = notifService.adjustForQuietHours(daytime);
      expect(unclamped.hour, equals(14));
      expect(unclamped.minute, equals(30));
    });
  });

  group('Feature 12: SettingsProvider Interview Goal & Quiet Hours Persistence', () {
    test('Round-trips interviewTargetDate and quietHours in toMap and importFromMap', () async {
      final settings = SettingsProvider();
      await settings.initialize();

      final targetDate = DateTime(2026, 11, 20, 10, 0);
      await settings.setInterviewTargetDate(targetDate);
      await settings.setQuietHours(
        enabled: true,
        startHour: 23,
        endHour: 7,
      );

      expect(settings.interviewTargetDate, equals(targetDate));
      expect(settings.quietHoursEnabled, isTrue);
      expect(settings.quietHoursStart, equals(23));
      expect(settings.quietHoursEnd, equals(7));

      final map = settings.toMap();
      expect(map['interview_target_date'], equals(targetDate.toIso8601String()));
      expect(map['quiet_hours_enabled'], isTrue);
      expect(map['quiet_hours_start'], equals(23));
      expect(map['quiet_hours_end'], equals(7));

      final importedSettings = SettingsProvider();
      await importedSettings.initialize();
      await importedSettings.importFromMap(map);

      expect(importedSettings.interviewTargetDate, equals(targetDate));
      expect(importedSettings.quietHoursEnabled, isTrue);
      expect(importedSettings.quietHoursStart, equals(23));
      expect(importedSettings.quietHoursEnd, equals(7));
    });
  });

  group('Feature 12: PracticeGoalsSheet Widget Tests', () {
    testWidgets('Renders interview goal date and quiet hours switch', (
      tester,
    ) async {
      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SettingsProvider>.value(
              value: settings,
              child: const PracticeGoalsSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Practice Goals & Reminders'), findsOneWidget);
      expect(find.text('Interview Goal Date'), findsOneWidget);
      expect(find.text('No target date set'), findsOneWidget);
      expect(find.text('Quiet Hours (10 PM - 8 AM)'), findsOneWidget);

      // Verify switch is present and toggles
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pump();
    });
  });
}
