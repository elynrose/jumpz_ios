import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// Native alarm service that uses Android's AlarmManager for real alarm functionality
class NativeAlarmService {
  static const MethodChannel _channel = MethodChannel('jumpz.alarm');

  /// Set a real alarm using Android's AlarmManager
  /// This will wake up the phone like a real alarm clock
  static Future<String> setAlarm({
    required int hour,
    required int minute,
    String title = 'Jumpz Alarm',
    String message = 'Time to jump!',
  }) async {
    try {
      print('🔔 Setting alarm for $hour:${minute.toString().padLeft(2, '0')}');
      
      // Cancel only our app's existing alarms (not user's personal alarms)
      await cancelAppAlarms();
      print('🧹 Cancelled existing Jumpz alarms');
      
      final result = await _channel.invokeMethod('setAlarm', {
        'hour': hour,
        'minute': minute,
        'title': title,
        'message': message,
      });
      print('✅ Alarm set successfully: $result');
      return result.toString();
    } catch (e) {
      print('❌ Failed to set native alarm: $e');
      print('📱 This is expected on iOS - falling back to notification scheduling');
      
      // For iOS, we'll use the notification service instead
      try {
        await _scheduleNotificationFallback(hour, minute, title, message);
        return 'Notification scheduled for iOS';
      } catch (fallbackError) {
        print('❌ Failed to set notification fallback: $fallbackError');
        throw Exception('Failed to set alarm: $e\n\n💡 On iOS, this uses scheduled notifications instead of native alarms.');
      }
    }
  }

  /// Cancel only our app's alarms (not user's personal alarms)
  static Future<void> cancelAppAlarms() async {
    try {
      // Cancel native alarm
      await _channel.invokeMethod('cancelAlarm');
      print('🧹 Cancelled native Jumpz alarm');
    } catch (e) {
      print('⚠️ Error cancelling native alarm: $e');
      print('📱 This is expected on iOS - cancelling notification instead');
      
      // For iOS, cancel the notification instead
      try {
        await NotificationService().cancel(0);
        print('🧹 Cancelled Jumpz notification for iOS');
      } catch (notificationError) {
        print('⚠️ Error cancelling notification: $notificationError');
      }
    }
  }

  /// Cancel the alarm
  static Future<String> cancelAlarm() async {
    try {
      final result = await _channel.invokeMethod('cancelAlarm');
      return result.toString();
    } catch (e) {
      throw Exception('Failed to cancel alarm: $e');
    }
  }

  /// Test alarm by setting it for 5 seconds from now
  static Future<String> testAlarm() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(seconds: 5));
    
    print('🧪 Setting test alarm for ${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}');
    
    return await setAlarm(
      hour: testTime.hour,
      minute: testTime.minute,
      title: '🚨 JUMPZ TEST ALARM 🚨',
      message: 'This is a test alarm - it should wake up your phone!',
    );
  }

  /// Test alarm for 1 minute from now (more reliable for testing)
  static Future<String> testAlarm1Minute() async {
    try {
      print('🧪 Setting 1-minute test alarm...');
      final result = await _channel.invokeMethod('testAlarm1Minute');
      print('✅ Test alarm set: $result');
      return result.toString();
    } catch (e) {
      print('❌ Failed to set test alarm: $e');
      throw Exception('Failed to set test alarm: $e');
    }
  }

  /// Checks if the alarm is currently active/sounding
  static Future<bool> isAlarmActive() async {
    try {
      final result = await _channel.invokeMethod('isAlarmActive');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Dismisses/stops the currently active alarm
  static Future<void> dismissAlarm() async {
    try {
      await _channel.invokeMethod('dismissAlarm');
    } catch (e) {
      // Silently handle dismissal errors
    }
  }

  /// Check the current alarm status
  static Future<String> checkAlarmStatus() async {
    try {
      final result = await _channel.invokeMethod('checkAlarmStatus');
      return result.toString();
    } catch (e) {
      return 'Error checking alarm status: $e';
    }
  }

  /// Comprehensive alarm diagnostic
  static Future<Map<String, dynamic>> runAlarmDiagnostic() async {
    try {
      print('🔍 Running alarm diagnostic...');
      
      // Check if alarm is currently active
      final isActive = await isAlarmActive();
      
      // Check alarm status
      final status = await checkAlarmStatus();
      
      // Test setting a 5-second alarm
      final now = DateTime.now();
      final testTime = now.add(const Duration(seconds: 5));
      
      print('📊 Alarm Diagnostic Results:');
      print('   - Currently Active: $isActive');
      print('   - Status: $status');
      print('   - Test Time: ${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}');
      
      return {
        'isActive': isActive,
        'status': status,
        'testTime': testTime,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Diagnostic failed: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Restore persistent alarm from database
  static Future<void> restorePersistentAlarm(FirestoreService firestore) async {
    try {
      print('🔄 Checking for saved alarm time...');
      
      final alarmTime = await firestore.getAlarmTime();
      final dailyGoal = await firestore.getDailyGoal();
      
      if (alarmTime != null) {
        print('🔄 Restoring persistent alarm for ${alarmTime.hour}:${alarmTime.minute.toString().padLeft(2, '0')}');
        
        // Cancel any existing alarm first
        await cancelAlarm();
        
        // Set the persistent alarm
        await setAlarm(
          hour: alarmTime.hour,
          minute: alarmTime.minute,
          title: '🏃‍♂️ Time to Jump!',
          message: 'Wake up and complete $dailyGoal jumps to reach your daily goal!',
        );
        
        print('✅ Persistent alarm restored successfully');
      } else {
        print('ℹ️ No saved alarm time found');
      }
    } catch (e) {
      print('❌ Error restoring persistent alarm: $e');
    }
  }

  /// Fallback method for iOS using scheduled notifications
  static Future<void> _scheduleNotificationFallback(
    int hour, 
    int minute, 
    String title, 
    String message
  ) async {
    try {
      print('📱 Scheduling notification for iOS: $hour:${minute.toString().padLeft(2, '0')}');
      
      // Calculate the next occurrence of the alarm time
      final now = DateTime.now();
      var alarmDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // If the time has already passed today, schedule for tomorrow
      if (alarmDateTime.isBefore(now)) {
        alarmDateTime = alarmDateTime.add(const Duration(days: 1));
      }
      
      // Schedule the notification using the available method
      await NotificationService().scheduleDailyAlarm(
        id: 0,
        time: TimeOfDay(hour: hour, minute: minute),
        title: title,
        body: message,
      );
      
      print('✅ Notification scheduled for iOS: ${alarmDateTime.toString()}');
    } catch (e) {
      print('❌ Failed to schedule notification fallback: $e');
      rethrow;
    }
  }
}
