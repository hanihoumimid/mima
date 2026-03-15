import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'database_helper.dart';

// ---------------------------------------------------------------------------
// Top-level callback — must be a static / top-level function annotated with
// @pragma('vm:entry-point') so that tree-shaking keeps it and
// android_alarm_manager_plus can call it from a background isolate.
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void alarmCallback(int id) async {
  // Re-initialise the Flutter engine bindings inside the background isolate.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await AlarmService.init();
  await AlarmService.fireAlarm(id);
}

/// Manages scheduling, firing and cancelling alarms for medication reminders.
class AlarmService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _channelId = 'mamie_meds_channel';
  static const _channelName = 'Rappels de médicaments';
  static const _channelDescription =
      'Notifications plein écran pour les rappels de médicaments.';

  /// Initialise local notifications (safe to call multiple times).
  static Future<void> init() async {
    if (!_isAndroid) return;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    try {
      await _notifications.initialize(
        const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationResponse,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
    } catch (e, stackTrace) {
      debugPrint('AlarmService.init error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ---------------------------------------------------------------------------
  // Core alarm logic
  // ---------------------------------------------------------------------------

  /// Called from [alarmCallback] in the background isolate.
  /// Shows a full-screen intent notification and immediately reschedules
  /// the same alarm for the next day so it is always self-healing.
  static Future<void> fireAlarm(int medicationId) async {
    final meds = await DatabaseHelper.instance.getMedications();
    final med = meds.firstWhere(
      (m) => m.id == medicationId,
      orElse: () =>
          Medication(id: medicationId, name: 'Médicament', hour: 8, minute: 0),
    );

    // Show the full-screen intent notification.
    await _notifications.show(
      medicationId,
      '⏰  Heure des médicaments !',
      'Prenez : ${med.name}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          actions: const [
            AndroidNotificationAction(
              'ok_action',
              '✅  OK — Pris !',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
    );

    // Reschedule immediately so the alarm is always self-healing, regardless
    // of whether the user taps OK.  The OK action also calls scheduleAlarm
    // for redundancy.
    if (med.isActive) {
      await scheduleAlarm(med);
    }
  }

  // ---------------------------------------------------------------------------
  // Notification response handlers
  // ---------------------------------------------------------------------------

  /// Handles tapping the notification or the OK action (foreground).
  static void _onNotificationResponse(NotificationResponse response) async {
    await _handleResponse(response);
  }

  /// Handles the OK action when the app is in the background.
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(
      NotificationResponse response) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await _handleResponse(response);
  }

  static Future<void> _handleResponse(NotificationResponse response) async {
    if (response.actionId == 'ok_action' ||
        response.notificationResponseType ==
            NotificationResponseType.selectedNotification) {
      final id = response.id;
      if (id == null) return;
      await _notifications.cancel(id);

      final meds = await DatabaseHelper.instance.getMedications();
      final matches = meds.where((m) => m.id == id);
      if (matches.isNotEmpty && matches.first.isActive) {
        await scheduleAlarm(matches.first);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Scheduling helpers
  // ---------------------------------------------------------------------------

  /// Returns the next future occurrence of [hour]:[minute].
  /// Always uses absolute time — never adds 24 h to "now".
  static DateTime calculateNextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    // Use !isAfter so that a time equal to now is also moved to tomorrow,
    // avoiding scheduling an alarm that has already passed.
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Schedules (or re-schedules) a one-shot exact alarm for [med].
  static Future<void> scheduleAlarm(Medication med) async {
    if (!_isAndroid || med.id == null || !med.isActive) return;
    final next = calculateNextOccurrence(med.hour, med.minute);
    await AndroidAlarmManager.oneShotAt(
      next,
      med.id!,
      alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      alarmClock: true,
    );
  }

  /// Cancels both the pending alarm and any visible notification for [id].
  static Future<void> cancelAlarm(int id) async {
    if (!_isAndroid) return;
    await AndroidAlarmManager.cancel(id);
    await _notifications.cancel(id);
  }

  /// Reschedules all active medications — called after BOOT_COMPLETED.
  static Future<void> rescheduleAll() async {
    final meds = await DatabaseHelper.instance.getMedications();
    for (final med in meds) {
      if (med.isActive && med.id != null) {
        await scheduleAlarm(med);
      }
    }
  }
}
