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

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Request POST_NOTIFICATIONS permission (Android 13+)
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
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
      icon: '@mipmap/ic_launcher',
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
      'Pitch Coach 🎙',
      'Time to practice! Spend 5 minutes improving your communication skills.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  /// Cancel any previously scheduled daily reminder.
  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_dailyReminderId);
  }

  /// Show a one-shot instant notification (e.g., confirmation after setup).
  Future<void> showInstantNotification(String title, String body) async {
    if (kIsWeb) return;
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(0, title, body, details);
  }
}
