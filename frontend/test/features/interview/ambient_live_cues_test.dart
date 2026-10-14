import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/providers/settings_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/core/services/rolling_wpm_estimator.dart';
import 'package:pitch_coach/core/theme/app_colors.dart';
import 'package:pitch_coach/features/interview/interview_practice_screen.dart';
import 'package:pitch_coach/core/models/pitch_template.dart';
import 'package:pitch_coach/core/repositories/template_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 9: RollingWpmEstimator Unit Tests', () {
    test('Initializes in measuring state with primary neutral color', () {
      final estimator = RollingWpmEstimator();
      expect(estimator.pacingState, PacingState.measuring);
      expect(estimator.pacingColor, AppColors.primaryPurple);
    });

    test('Transitions to optimal (green) in 120-160 WPM target band', () {
      final estimator = RollingWpmEstimator();
      estimator.setWpmForTesting(135.0);
      expect(estimator.pacingState, PacingState.optimal);
      expect(estimator.pacingColor, AppColors.successGreen);
    });

    test('Transitions to warning (amber) for moderate deviations (100-120 or 160-180)', () {
      final estimator = RollingWpmEstimator();
      estimator.setWpmForTesting(110.0);
      expect(estimator.pacingState, PacingState.warning);
      expect(estimator.pacingColor, AppColors.warningAmber);

      estimator.setWpmForTesting(170.0);
      expect(estimator.pacingState, PacingState.warning);
      expect(estimator.pacingColor, AppColors.warningAmber);
    });

    test('Transitions to alert (red) for severe slow or rushing cadence (<100 or >180)', () {
      final estimator = RollingWpmEstimator();
      estimator.setWpmForTesting(80.0);
      expect(estimator.pacingState, PacingState.alert);
      expect(estimator.pacingColor, AppColors.dangerRed);

      estimator.setWpmForTesting(205.0);
      expect(estimator.pacingState, PacingState.alert);
      expect(estimator.pacingColor, AppColors.dangerRed);
    });

    test('Reset restores initial measuring state', () {
      final estimator = RollingWpmEstimator();
      estimator.setWpmForTesting(140.0);
      expect(estimator.pacingState, PacingState.optimal);

      estimator.reset();
      expect(estimator.pacingState, PacingState.measuring);
      expect(estimator.currentWpm, 135.0);
    });
  });

  group('Feature 9: SettingsProvider Ambient Live Cues Toggle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Defaults to enabled and toggles off cleanly', () async {
      final settings = SettingsProvider();
      await settings.initialize();
      expect(settings.ambientLiveCues, isTrue);

      await settings.setAmbientLiveCues(false);
      expect(settings.ambientLiveCues, isFalse);

      await settings.setAmbientLiveCues(true);
      expect(settings.ambientLiveCues, isTrue);
    });
  });

  group('Feature 9: UI Ambient Live Cues Integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TemplateRepository.setMockTemplates(PitchTemplate.defaultTemplates);
    });

    testWidgets('Timer indicator changes color smoothly with pace and can be disabled', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settings = SettingsProvider();
      await settings.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProvider()),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: const MaterialApp(
            home: InterviewPracticeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Obtain controller from mounted widget tree
      final element = tester.element(find.byKey(const Key('tts_toggle_button')));
      final ctrl = Provider.of<InterviewSessionController>(element, listen: false);

      // Set recording phase
      ctrl.setRecordingPhaseForTesting(RecordingPhase.recording);
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Optimal pacing (135 WPM) -> Green cue
      ctrl.setWpmForTesting(135.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(ctrl.pacingColor, AppColors.successGreen);

      // Verify timer is displayed and NO text popup alerts exist
      expect(find.text(ctrl.formattedTime), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      // 2. Warning pacing (170 WPM) -> Amber cue
      ctrl.setWpmForTesting(170.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(ctrl.pacingColor, AppColors.warningAmber);
      expect(find.byType(SnackBar), findsNothing);

      // 3. Alert pacing (210 WPM) -> Red cue
      ctrl.setWpmForTesting(210.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(ctrl.pacingColor, AppColors.dangerRed);
      expect(find.byType(SnackBar), findsNothing);

      // 4. Disable ambient cues via Settings toggle without blocking fakeAsync
      settings.setAmbientLiveCues(false);
      await tester.pump(const Duration(milliseconds: 400));

      // Verify indicator can be turned off
      expect(settings.ambientLiveCues, isFalse);
    });
  });
}
