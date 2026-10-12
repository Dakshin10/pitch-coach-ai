import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Singleton service for local notifications.
/// Handles: initialization, daily reminder scheduling, and instant notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1;
  static const String _channelId = 'pitch_coach_daily';
  static const String _channelName = 'Daily Practice Reminder';
  static const String _channelDesc =
      'Daily reminder to practice communication skills';

  bool _initialized = false;

  // ── Initialization ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    // Local notifications are not supported on Flutter web.
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz.initializeTimeZones();
    // Use UTC as fallback — avoids requiring flutter_timezone package
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      // If timezone not found, use UTC
    }

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      // Request POST_NOTIFICATIONS permission (Android 13+)
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigation can be handled via GlobalKey<NavigatorState> if needed.
    // For now, the app opens naturally when user taps the notification.
  }

  // ── Daily Reminder ──────────────────────────────────────────────────────

  /// Schedule a daily notification at [time].
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (kIsWeb) return;
    await initialize();

    // Cancel any existing reminder first
    await cancelDailyReminder();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Pitch Coach',
      'Time to practice! Spend 5 minutes improving your communication skills.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  /// Request notification permission explicitly on Android 13+ and iOS.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return false;
  }

  /// Schedule practice notifications at [time] on specified [days] (1 = Mon ... 7 = Sun).
  Future<void> schedulePracticeReminders({
    required TimeOfDay time,
    required List<int> days,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await cancelPracticeReminders();

    if (days.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    // If all 7 days selected, schedule as daily repeating reminder
    if (days.length == 7) {
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      await _scheduleZonedWithFallback(
        id: _dailyReminderId,
        title: 'Pitch Coach',
        body:
            'Time to practice! Spend 5 minutes improving your communication skills.',
        scheduledDate: scheduledDate,
        details: details,
        matchComponents: DateTimeComponents.time,
      );
      return;
    }

    // Schedule for each selected day of week
    for (final day in days) {
      // Find the next occurrence of this weekday (1 = Mon ... 7 = Sun)
      var targetDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      while (targetDate.weekday != day || targetDate.isBefore(now)) {
        targetDate = targetDate.add(const Duration(days: 1));
      }

      final reminderId = 100 + day;
      await _scheduleZonedWithFallback(
        id: reminderId,
        title: 'Pitch Coach',
        body:
            'Time to practice! Spend 5 minutes improving your communication skills.',
        scheduledDate: targetDate,
        details: details,
        matchComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _scheduleZonedWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required DateTimeComponents matchComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      debugPrint('Exact alarm scheduling failed, falling back to inexact: $e');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
        );
      } catch (fallbackError) {
        debugPrint('Fallback notification scheduling failed: $fallbackError');
      }
    }
  }

  /// Cancel any previously scheduled daily reminder.
  Future<void> cancelDailyReminder() async {
    await cancelPracticeReminders();
  }

  /// Cancel all practice reminders (daily and per-day).
  Future<void> cancelPracticeReminders() async {
    if (kIsWeb) return;
    await _plugin.cancel(_dailyReminderId);
    for (int day = 1; day <= 7; day++) {
      await _plugin.cancel(100 + day);
    }
  }

  /// Show a one-shot instant notification (e.g., slide processing completion or setup).
  Future<void> showInstantNotification(
    String title,
    String body, {
    int? id,
  }) async {
    if (kIsWeb) return;
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final notificationId =
        id ?? (DateTime.now().millisecondsSinceEpoch % 100000);
    await _plugin.show(notificationId, title, body, details);
  }
}
