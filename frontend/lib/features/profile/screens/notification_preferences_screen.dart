import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_atmosphere.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/settings_section.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _permissionDenied = false;

  Future<void> _handleToggle({
    required bool currentValue,
    required Future<void> Function(bool newValue) updatePref,
  }) async {
    final newValue = !currentValue;
    if (newValue) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        setState(() => _permissionDenied = true);
        if (mounted) {
          AppToast.error(
            context,
            'Notifications are disabled in system settings.',
          );
        }
        return;
      }
    }

    setState(() => _permissionDenied = false);
    await updatePref(newValue);
    if (mounted) {
      AppToast.success(
        context,
        newValue ? 'Notification enabled' : 'Notification disabled',
      );
    }
  }

  Future<void> _openSystemSettings() async {
    // Attempt opening app settings
    final uri = Uri.parse('app-settings:');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                      icon: RotatedBox(
                        quarterTurns: 2,
                        child: AppIcon(
                          AppIcons.chevronRight,
                          size: 20,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notification Preferences',
                        style: AppTextStyles.headingM.copyWith(
                          fontSize: 18,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    const ThemeToggleButton(size: 38, compact: true),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      if (_permissionDenied)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.errorRed.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const AppIcon(
                                AppIcons.info,
                                color: AppColors.errorRed,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'System notifications are blocked. Please enable them in device settings to receive alerts.',
                                  style: AppTextStyles.bodyM.copyWith(
                                    fontSize: 13,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _openSystemSettings,
                                child: Text(
                                  'Settings',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.primaryPurpleLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SettingsSection(
                        title: 'Practice & Feedback Alerts',
                        children: [
                          SettingsTile(
                            leadingIcon: AppIcons.clock,
                            title: 'Daily Practice Reminder',
                            subtitle:
                                'Scheduled reminder to complete your daily pitch rehearsal',
                            trailingType: SettingsTileTrailing.toggle,
                            toggleValue: settings.dailyReminder,
                            onToggle: (val) => _handleToggle(
                              currentValue: settings.dailyReminder,
                              updatePref: settings.setDailyReminder,
                            ),
                          ),
                          SettingsTile(
                            leadingIcon: AppIcons.slides,
                            title: 'Slide Deck Ready Alerts',
                            subtitle:
                                'Notify me when background presentation slide analysis finishes',
                            trailingType: SettingsTileTrailing.toggle,
                            toggleValue: settings.slideDeckReadyAlerts,
                            onToggle: (val) => _handleToggle(
                              currentValue: settings.slideDeckReadyAlerts,
                              updatePref: settings.setSlideDeckReadyAlerts,
                            ),
                          ),
                          SettingsTile(
                            leadingIcon: AppIcons.chart,
                            title: 'Weekly Progress Summary',
                            subtitle:
                                'Weekly scorecard summary of your pacing, clarity, and filler words',
                            trailingType: SettingsTileTrailing.toggle,
                            toggleValue: settings.weeklyProgressSummary,
                            onToggle: (val) => _handleToggle(
                              currentValue: settings.weeklyProgressSummary,
                              updatePref: settings.setWeeklyProgressSummary,
                            ),
                          ),
                          SettingsTile(
                            leadingIcon: AppIcons.book,
                            title: 'Tips & Lesson Recommendations',
                            subtitle:
                                'Curated speech drills and micro-lessons based on your weak spots',
                            trailingType: SettingsTileTrailing.toggle,
                            toggleValue: settings.tipsAndLessons,
                            onToggle: (val) => _handleToggle(
                              currentValue: settings.tipsAndLessons,
                              updatePref: settings.setTipsAndLessons,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
