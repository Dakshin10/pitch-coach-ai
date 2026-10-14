import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_atmosphere.dart';
import '../../../core/widgets/gradient_button.dart';

class PracticeGoalsSheet extends StatefulWidget {
  const PracticeGoalsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PracticeGoalsSheet(),
    );
  }

  @override
  State<PracticeGoalsSheet> createState() => _PracticeGoalsSheetState();
}

class _PracticeGoalsSheetState extends State<PracticeGoalsSheet> {
  late TimeOfDay _time;
  late Set<int> _selectedDays;
  late int _weeklyGoal;
  DateTime? _targetDate;
  bool _quietHours = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _daysInfo = const [
    {'day': 1, 'label': 'M', 'name': 'Mon'},
    {'day': 2, 'label': 'T', 'name': 'Tue'},
    {'day': 3, 'label': 'W', 'name': 'Wed'},
    {'day': 4, 'label': 'T', 'name': 'Thu'},
    {'day': 5, 'label': 'F', 'name': 'Fri'},
    {'day': 6, 'label': 'S', 'name': 'Sat'},
    {'day': 7, 'label': 'S', 'name': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _time = settings.reminderTime;
    _selectedDays = Set<int>.from(settings.reminderDays);
    _weeklyGoal = settings.weeklyGoal.clamp(1, 14);
    _targetDate = settings.interviewTargetDate;
    _quietHours = settings.quietHoursEnabled;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);
    final settings = context.read<SettingsProvider>();

    try {
      final daysList = _selectedDays.toList()..sort();
      await settings.setReminderTime(_time);
      await settings.setReminderDays(daysList);
      await settings.setWeeklyGoal(_weeklyGoal);
      await settings.setInterviewTargetDate(_targetDate);
      await settings.setQuietHours(enabled: _quietHours);

      if (daysList.isNotEmpty) {
        await NotificationService.instance.schedulePracticeReminders(
          time: _time,
          days: daysList,
        );
      } else {
        await NotificationService.instance.cancelPracticeReminders();
      }

      if (_targetDate != null) {
        await NotificationService.instance.scheduleInterviewTargetReminders(
          targetDate: _targetDate!,
          quietHoursEnabled: _quietHours,
        );
      } else {
        await NotificationService.instance.cancelInterviewTargetReminders();
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, 'Practice goal and reminder updated');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to update reminder: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _disableReminders() async {
    setState(() => _isSaving = true);
    final settings = context.read<SettingsProvider>();
    try {
      await settings.setDailyReminder(false);
      await settings.setReminderDays([]);
      await NotificationService.instance.cancelPracticeReminders();
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.info(context, 'Practice reminders disabled');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error disabling reminder: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondaryOf(
                      context,
                    ).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Practice Goals & Reminders',
                    style: AppTextStyles.headingM.copyWith(
                      fontSize: 18,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: AppIcon(
                      AppIcons.logout, // rotated or close
                      color: AppColors.textSecondaryOf(context),
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reminder Time Card
              GlassSurface(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const AppIcon(
                          AppIcons.clock,
                          color: AppColors.primaryPurpleLight,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reminder Time',
                              style: AppTextStyles.bodyM.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            Text(
                              _time.format(context),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: _pickTime,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryPurpleLight,
                        side: const BorderSide(color: AppColors.primaryPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Change Time'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Practice Days Chips
              Text(
                'Practice Days',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _daysInfo.map((info) {
                  final day = info['day'] as int;
                  final label = info['label'] as String;
                  final isSelected = _selectedDays.contains(day);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDays.remove(day);
                        } else {
                          _selectedDays.add(day);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected
                            ? null
                            : (isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.borderOf(context),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Weekly Goal Stepper
              Text(
                'Weekly Session Target',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              GlassSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_weeklyGoal sessions / week',
                          style: AppTextStyles.bodyM.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        Text(
                          'Recommended: 5 sessions/wk',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _weeklyGoal > 1
                              ? () => setState(() => _weeklyGoal--)
                              : null,
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderOf(context),
                              ),
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: _weeklyGoal > 1
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textSecondaryOf(
                                      context,
                                    ).withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Text(
                          '$_weeklyGoal',
                          style: AppTextStyles.headingM.copyWith(
                            fontSize: 16,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        IconButton(
                          onPressed: _weeklyGoal < 14
                              ? () => setState(() => _weeklyGoal++)
                              : null,
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderOf(context),
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: _weeklyGoal < 14
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textSecondaryOf(
                                      context,
                                    ).withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interview Goal Date Card
              Text(
                'Interview Goal Date',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              GlassSurface(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          color: AppColors.primaryPurpleLight,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _targetDate != null
                                  ? '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}'
                                  : 'No target date set',
                              style: AppTextStyles.bodyM.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            Text(
                              _targetDate != null
                                  ? 'Countdown reminders active'
                                  : 'Optional countdown push alerts',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_targetDate != null)
                          IconButton(
                            onPressed: () => setState(() => _targetDate = null),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.textSecondaryOf(context),
                          ),
                        OutlinedButton(
                          onPressed: _pickTargetDate,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryPurpleLight,
                            side: const BorderSide(
                              color: AppColors.primaryPurple,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _targetDate == null ? 'Set Date' : 'Change',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quiet Hours Card
              GlassSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bedtime_outlined,
                          color: AppColors.accentTeal,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quiet Hours (10 PM - 8 AM)',
                              style: AppTextStyles.bodyM.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            Text(
                              'Silences reminders during rest hours',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _quietHours,
                      activeThumbColor: AppColors.accentTeal,
                      onChanged: (val) => setState(() => _quietHours = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions: Save & Disable
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _disableReminders,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.errorRed,
                        side: BorderSide(
                          color: AppColors.errorRed.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Disable Reminders'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      text: _isSaving ? 'Saving...' : 'Save Goals',
                      variant: GradientButtonVariant.primary,
                      height: 48,
                      onPressed: _isSaving ? null : _saveGoals,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
