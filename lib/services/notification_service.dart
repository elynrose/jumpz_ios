import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'firestore_service.dart';

/// A helper class for scheduling and handling local notifications. The
/// [flutter_local_notifications] package supports scheduling notifications on
/// Android, iOS, and desktop platforms. Key features include scheduling
/// notifications to appear at a specific time and handling user taps on
/// notifications【745656195084809†L141-L149】.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String?> _notificationStreamController =
      StreamController<String?>.broadcast();
  
  bool _isInitialized = false;
  final Map<int, DateTime> _scheduledAlarms = {};

  /// A stream of payload strings emitted when the user taps on a notification.
  Stream<String?> get onNotificationClick => _notificationStreamController.stream;
  
  /// Check if a notification with the given ID is scheduled
  bool isAlarmScheduled(int id) => _scheduledAlarms.containsKey(id);
  
  /// Get the scheduled time for an alarm
  DateTime? getScheduledTime(int id) => _scheduledAlarms[id];

  /// Initialises the local notifications plugin. This must be called before
  /// scheduling or displaying any notifications. On iOS, the user will be
  /// prompted to grant notification permissions.
  Future<void> init() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Request notification permissions
    await _requestPermissions();
    
    // Create notification channel for Android
    await _createNotificationChannel();
    
    // Create goal reminder channel
    await _createGoalReminderChannel();
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _plugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (response) {
      // Broadcast the payload when the notification is tapped so the UI can
      // respond appropriately.
      _notificationStreamController.add(response.payload);
    });
    
    _isInitialized = true;
  }
  
  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // Request basic notification permission
      final notificationPermission = await androidPlugin.requestNotificationsPermission();
      print('Notification permission granted: $notificationPermission');
      
      // Request exact alarm permission for Android 12+
      final exactAlarmPermission = await androidPlugin.requestExactAlarmsPermission();
      print('Exact alarm permission granted: $exactAlarmPermission');
      
      // Check if we can schedule exact alarms
      final canScheduleExact = await androidPlugin.canScheduleExactNotifications();
      print('Can schedule exact alarms: $canScheduleExact');
    }
  }
  
  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'jumpz_alarm_channel',
      'Jumpz Alarms',
      description: 'Scheduled alarms for daily jump goals',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      // Use default system alarm sound
      enableLights: true,
      ledColor: Color(0xFFFF5722),
    );
    
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }

  /// Schedules a one‑off notification at the next occurrence of [time]. For
  /// example, if [time] is 7:00 AM and the current time is later than 7:00 AM,
  /// the notification will be scheduled for 7:00 AM the following day. The
  /// [id] should be a unique integer to identify this notification. The
  /// [title] and [body] define the contents displayed in the notification.
  Future<bool> scheduleDailyAlarm({
    required int id,
    required TimeOfDay time,
    String title = 'Time to jump!',
    String body = 'Wake up and complete your jump goal.',
    String? payload,
    String? customSound,
    bool vibrationEnabled = true,
    bool ledEnabled = true,
    int vibrationIntensity = 3,
  }) async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await init();
      }
      
      // Cancel existing alarm with same ID
      await cancel(id);
      
      final now = DateTime.now();
      final todaySchedule = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      
      // If the scheduled time has already passed today, schedule for tomorrow.
      final scheduledDate = todaySchedule.isAfter(now)
          ? todaySchedule
          : todaySchedule.add(const Duration(days: 1));
      
      // Store the scheduled time
      _scheduledAlarms[id] = scheduledDate;
      
      final androidDetails = AndroidNotificationDetails(
        'jumpz_alarm_channel',
        'Jumpz Alarms',
        channelDescription: 'Scheduled alarms for daily jump goals',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: vibrationEnabled,
        enableLights: ledEnabled,
        ledColor: const Color(0xFFFF5722),
        ledOnMs: 1000,
        ledOffMs: 500,
        vibrationPattern: vibrationEnabled 
            ? Int64List.fromList(_getVibrationPattern(vibrationIntensity))
            : null,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        autoCancel: false,
        ongoing: true,
        showWhen: true,
        when: scheduledDate.millisecondsSinceEpoch,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // Don't specify sound - use system default
        interruptionLevel: InterruptionLevel.critical,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Check if exact alarms are allowed
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      bool useExactAlarms = false;
      if (androidPlugin != null) {
        final canScheduleExactAlarms = await androidPlugin.canScheduleExactNotifications();
        print('Can schedule exact alarms: $canScheduleExactAlarms');
        
        if (canScheduleExactAlarms == false) {
          print('Exact alarms not permitted. Requesting permission...');
          await androidPlugin.requestExactAlarmsPermission();
          // Try again after requesting permission
          final canScheduleAfterRequest = await androidPlugin.canScheduleExactNotifications();
          print('Can schedule exact alarms after request: $canScheduleAfterRequest');
          useExactAlarms = canScheduleAfterRequest ?? false;
        } else {
          useExactAlarms = canScheduleExactAlarms ?? false;
        }
      }
      
      print('Using exact alarms: $useExactAlarms');
      
      // Schedule the alarm
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails,
          androidScheduleMode: useExactAlarms 
              ? AndroidScheduleMode.exactAllowWhileIdle 
              : AndroidScheduleMode.inexact,
          payload: payload,
        );
        print('Alarm scheduled successfully for: $scheduledDate');
      } catch (e) {
        print('Error scheduling alarm: $e');
        // Try with inexact scheduling as fallback
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            tz.TZDateTime.from(scheduledDate, tz.local),
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexact,
            payload: payload,
          );
          print('Alarm scheduled with inexact mode');
        } catch (fallbackError) {
          print('Failed to schedule alarm even with inexact mode: $fallbackError');
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('Error scheduling alarm: $e');
      return false;
    }
  }

  /// Cancels the notification with the given [id]. Useful for removing
  /// previously scheduled alarms.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    _scheduledAlarms.remove(id);
  }
  
  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _scheduledAlarms.clear();
  }
  
  /// Get all pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }
  
  /// Test alarm sound immediately
  Future<void> testAlarmSound({String? customSound}) async {
    if (!_isInitialized) {
      await init();
    }
    
    print('Testing alarm sound...');
    
    // Create a simple notification without sound specification
    final androidDetails = AndroidNotificationDetails(
      'jumpz_alarm_channel',
      'Jumpz Alarms',
      channelDescription: 'Scheduled alarms for daily jump goals',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFFFF5722),
      ledOnMs: 1000,
      ledOffMs: 500,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _plugin.show(
      999, // Test notification ID
      '🚨 ALARM TEST 🚨',
      'This is a test alarm - it should ring continuously!',
      notificationDetails,
    );
  }

  /// Get vibration pattern based on intensity (1-5)
  List<int> _getVibrationPattern(int intensity) {
    final basePattern = [0, 1000, 500, 1000, 500, 1000, 500, 1000];
    final multiplier = intensity / 3.0; // Scale based on intensity
    
    return basePattern.map((duration) => (duration * multiplier).round()).toList();
  }

  /// Schedules recurring goal reminder notifications at configurable intervals
  /// if the user hasn't completed their daily goal
  Future<void> scheduleGoalReminders({
    required int userId,
    required int dailyGoal,
    bool enabled = true,
    int reminderIntervalHours = 4,
  }) async {
    if (!enabled) {
      // Cancel all existing goal reminders
      await _cancelGoalReminders(userId);
      return;
    }

    try {
      // Cancel existing reminders first
      await _cancelGoalReminders(userId);
      
      // Schedule reminders at configurable intervals starting from now
      final now = DateTime.now();
      final reminderTimes = [
        now.add(Duration(hours: reminderIntervalHours)),
        now.add(Duration(hours: reminderIntervalHours * 2)),
        now.add(Duration(hours: reminderIntervalHours * 3)),
        now.add(Duration(hours: reminderIntervalHours * 4)),
        now.add(Duration(hours: reminderIntervalHours * 5)),
      ];

      for (int i = 0; i < reminderTimes.length; i++) {
        final reminderTime = reminderTimes[i];
        final reminderId = 1000 + userId + i; // Unique ID for each reminder
        
        await _scheduleGoalReminder(
          id: reminderId,
          scheduledTime: reminderTime,
          dailyGoal: dailyGoal,
          reminderNumber: i + 1,
        );
      }
      
      print('✅ Goal reminders scheduled for user $userId');
    } catch (e) {
      print('❌ Error scheduling goal reminders: $e');
    }
  }

  /// Schedules a single goal reminder notification
  Future<void> _scheduleGoalReminder({
    required int id,
    required DateTime scheduledTime,
    required int dailyGoal,
    required int reminderNumber,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'jumpz_goal_reminders',
        'Goal Reminders',
        channelDescription: 'Reminders to complete your daily jump goal',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFFFD700),
        ledOnMs: 1000,
        ledOffMs: 500,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        showWhen: true,
        when: scheduledTime.millisecondsSinceEpoch,
        actions: [
          const AndroidNotificationAction(
            'open_app',
            'Open App',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            cancelNotification: true,
          ),
        ],
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Create reminder messages based on reminder number
      final message = _getReminderMessage(reminderNumber, dailyGoal);
      final title = message['title'] as String;
      final body = message['body'] as String;
      
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'goal_reminder_$id',
      );
      
      print('✅ Goal reminder $id scheduled for $scheduledTime');
    } catch (e) {
      print('❌ Error scheduling goal reminder $id: $e');
    }
  }

  /// Gets appropriate reminder message based on reminder number
  Map<String, String> _getReminderMessage(int reminderNumber, int dailyGoal) {
    switch (reminderNumber) {
      case 1:
        return {
          'title': '🏃‍♂️ Time to Jump!',
          'body': 'You haven\'t started your daily goal of $dailyGoal jumps yet. Let\'s get moving!'
        };
      case 2:
        return {
          'title': '⏰ Goal Check-in',
          'body': 'How are you doing with your $dailyGoal jumps today? Keep up the momentum!'
        };
      case 3:
        return {
          'title': '💪 Halfway There?',
          'body': 'You\'re halfway through the day! Don\'t forget your $dailyGoal jump goal.'
        };
      case 4:
        return {
          'title': '🌅 Evening Reminder',
          'body': 'The day is winding down. Complete your $dailyGoal jumps before bedtime!'
        };
      case 5:
        return {
          'title': '🌙 Last Chance!',
          'body': 'Final reminder: complete your $dailyGoal jumps today to maintain your streak!'
        };
      default:
        return {
          'title': '🏃‍♂️ Jump Reminder',
          'body': 'Don\'t forget your daily goal of $dailyGoal jumps!'
        };
    }
  }

  /// Cancels all goal reminder notifications for a user
  Future<void> _cancelGoalReminders(int userId) async {
    try {
      // Cancel reminders with IDs 1000 + userId + (0-4)
      for (int i = 0; i < 5; i++) {
        final reminderId = 1000 + userId + i;
        await cancel(reminderId);
      }
      print('✅ Goal reminders cancelled for user $userId');
    } catch (e) {
      print('❌ Error cancelling goal reminders: $e');
    }
  }

  /// Checks if user has completed their daily goal and cancels remaining reminders
  Future<void> checkAndUpdateGoalReminders({
    required int userId,
    required int currentJumps,
    required int dailyGoal,
  }) async {
    try {
      if (currentJumps >= dailyGoal) {
        // Goal completed - cancel all remaining reminders
        await _cancelGoalReminders(userId);
        print('✅ Goal completed! Cancelled remaining reminders for user $userId');
      }
    } catch (e) {
      print('❌ Error checking goal reminders: $e');
    }
  }

  /// Schedules a smart reminder based on user's typical activity patterns
  Future<void> scheduleSmartReminder({
    required int userId,
    required int dailyGoal,
    required List<DateTime> recentActivityTimes,
  }) async {
    try {
      // Analyze user's activity patterns
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      // If user has recent activity, schedule next reminder in 4 hours
      if (recentActivityTimes.isNotEmpty) {
        final lastActivity = recentActivityTimes.last;
        if (lastActivity.isAfter(todayStart)) {
          final nextReminder = now.add(const Duration(hours: 4));
          await _scheduleGoalReminder(
            id: 2000 + userId,
            scheduledTime: nextReminder,
            dailyGoal: dailyGoal,
            reminderNumber: 1,
          );
        }
      } else {
        // No recent activity - schedule immediate reminder
        await _scheduleGoalReminder(
          id: 2000 + userId,
          scheduledTime: now.add(const Duration(minutes: 30)),
          dailyGoal: dailyGoal,
          reminderNumber: 1,
        );
      }
    } catch (e) {
      print('❌ Error scheduling smart reminder: $e');
    }
  }

  /// Creates a notification channel for goal reminders
  Future<void> _createGoalReminderChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'jumpz_goal_reminders',
      'Goal Reminders',
      description: 'Reminders to complete your daily jump goal',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFFD700),
    );
    
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }

  /// Restores alarms from Firestore on app startup
  Future<void> restoreAlarms(FirestoreService firestore) async {
    try {
      final alarmTime = await firestore.getAlarmTime();
      
      if (alarmTime != null) {
        print('🔄 Restoring alarm for time: ${alarmTime.hour}:${alarmTime.minute.toString().padLeft(2, '0')}');
        
        // Get user settings
        final settings = await firestore.getUserSettings();
        final dailyGoal = await firestore.getDailyGoal();
        
        // Schedule the restored alarm
        await scheduleDailyAlarm(
          id: 0,
          time: alarmTime,
          title: 'Time to jump! 🏃‍♂️',
          body: 'Wake up and complete $dailyGoal jumps to reach your daily goal!',
          payload: '$dailyGoal',
          customSound: settings['alarmSound'] as String?,
          vibrationEnabled: settings['vibrationEnabled'] as bool? ?? true,
          ledEnabled: settings['ledEnabled'] as bool? ?? true,
          vibrationIntensity: settings['vibrationIntensity'] as int? ?? 3,
        );
        
        print('✅ Alarm restored successfully');
      } else {
        print('ℹ️ No saved alarm time found');
      }
    } catch (e) {
      print('❌ Error restoring alarms: $e');
    }
  }

  /// Disposes internal resources. Should be called when the service is no
  /// longer needed. This closes the notification stream controller.
  void dispose() {
    _notificationStreamController.close();
  }
}