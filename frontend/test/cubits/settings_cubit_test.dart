import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/cubits/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state has default values', () {
      final cubit = SettingsCubit();
      expect(cubit.state.themeMode, equals(ThemeMode.system));
      expect(cubit.state.locale, equals('en'));
      expect(cubit.state.dailyReminder, isTrue);
      expect(cubit.state.weeklyGoal, equals(5));
      cubit.close();
    });

    blocTest<SettingsCubit, SettingsState>(
      'initialize loads stored preferences',
      setUp: () {
        SharedPreferences.setMockInitialValues({
          SettingsCubit.keyThemeMode: 'dark',
          SettingsCubit.keyLocale: 'fr',
          SettingsCubit.keyDailyReminder: false,
          SettingsCubit.keyWeeklyGoal: 7,
        });
      },
      build: () => SettingsCubit(),
      act: (cubit) => cubit.initialize(),
      expect: () => [
        isA<SettingsState>().having((s) => s.isLoading, 'isLoading', isTrue),
        isA<SettingsState>()
            .having((s) => s.themeMode, 'themeMode', equals(ThemeMode.dark))
            .having((s) => s.locale, 'locale', equals('fr'))
            .having((s) => s.dailyReminder, 'dailyReminder', isFalse)
            .having((s) => s.weeklyGoal, 'weeklyGoal', equals(7))
            .having((s) => s.isLoading, 'isLoading', isFalse),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setThemeMode updates themeMode in state',
      build: () => SettingsCubit(),
      act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.themeMode,
          'themeMode',
          equals(ThemeMode.dark),
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setLocale updates locale in state',
      build: () => SettingsCubit(),
      act: (cubit) => cubit.setLocale('de'),
      expect: () => [
        isA<SettingsState>().having((s) => s.locale, 'locale', equals('de')),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setDailyReminder updates dailyReminder toggle',
      build: () => SettingsCubit(),
      act: (cubit) => cubit.setDailyReminder(false),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.dailyReminder,
          'dailyReminder',
          isFalse,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setPracticeGoals updates reminder time, days, and weekly target',
      build: () => SettingsCubit(),
      act: (cubit) => cubit.setPracticeGoals(
        time: const TimeOfDay(hour: 18, minute: 30),
        days: [1, 3, 5],
        weeklyGoal: 4,
      ),
      expect: () => [
        isA<SettingsState>()
            .having((s) => s.reminderTime.hour, 'hour', equals(18))
            .having((s) => s.reminderTime.minute, 'minute', equals(30))
            .having((s) => s.reminderDays, 'days', equals([1, 3, 5]))
            .having((s) => s.weeklyGoal, 'weeklyGoal', equals(4)),
      ],
    );

    test('isSlideDeckReadyAlertEnabled reads from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        SettingsCubit.keySlideDeckReady: false,
      });
      final enabled = await SettingsCubit.isSlideDeckReadyAlertEnabled();
      expect(enabled, isFalse);
    });
  });
}
