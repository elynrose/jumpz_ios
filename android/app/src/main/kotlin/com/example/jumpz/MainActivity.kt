package com.jumpz.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "jumpz.alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 0
                    val minute = call.argument<Int>("minute") ?: 0
                    val title = call.argument<String>("title") ?: "Jumpz Alarm"
                    val message = call.argument<String>("message") ?: "Time to jump!"
                    
                    setAlarm(hour, minute, title, message)
                    result.success("Alarm set for $hour:$minute")
                }
                "cancelAlarm" -> {
                    cancelAlarm()
                    dismissAlarm()
                    result.success("Alarm cancelled")
                }
                "isAlarmActive" -> {
                    val isActive = isAlarmActive()
                    result.success(isActive)
                }
                "dismissAlarm" -> {
                    dismissAlarm()
                    result.success("Alarm dismissed")
                }
                "checkAlarmStatus" -> {
                    val status = checkAlarmStatus()
                    result.success(status)
                }
                "testAlarm1Minute" -> {
                    val now = java.util.Calendar.getInstance()
                    val testTime = java.util.Calendar.getInstance().apply {
                        add(java.util.Calendar.MINUTE, 1)
                    }
                    setAlarm(testTime.get(java.util.Calendar.HOUR_OF_DAY), testTime.get(java.util.Calendar.MINUTE), "🚨 JUMPZ 1-MIN TEST 🚨", "This is a 1-minute test alarm!")
                    result.success("Test alarm set for 1 minute from now")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setAlarm(hour: Int, minute: Int, title: String, message: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Check for exact alarm permissions on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                // Permission not granted - this will cause the alarm to fail silently
                println("❌ SCHEDULE_EXACT_ALARM permission not granted!")
                return
            }
        }
        
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("message", message)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            
            // If the time has already passed today, set for tomorrow
            if (timeInMillis <= System.currentTimeMillis()) {
                add(java.util.Calendar.DAY_OF_MONTH, 1)
                println("⏰ Time has passed today, setting alarm for tomorrow at ${hour}:${minute}")
            } else {
                println("⏰ Setting alarm for today at ${hour}:${minute}")
            }
        }

        // Set up ALARM with proper Android version handling
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    // For Android 6.0+, use setExactAndAllowWhileIdle for reliable alarms
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                    println("✅ Exact alarm set for ${hour}:${minute} (Android 6.0+)")
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    // For Android 4.4+, use setExact
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                    println("✅ Exact alarm set for ${hour}:${minute} (Android 4.4+)")
                }
                else -> {
                    // For older Android versions, use set
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                    println("✅ Alarm set for ${hour}:${minute} (Android < 4.4)")
                }
            }
        } catch (e: Exception) {
            println("❌ Failed to set alarm: ${e.message}")
        }
    }

    private fun cancelAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun dismissAlarm() {
        // Stop the alarm directly
        AlarmReceiver.stopAlarm()
        
        // Also send broadcast for notification dismissal
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "DISMISS_ALARM"
        }
        sendBroadcast(intent)
    }

    private fun isAlarmActive(): Boolean {
        // Check if the alarm is currently active by checking the AlarmReceiver
        return AlarmReceiver.isAlarmActive()
    }
    
    private fun checkAlarmStatus(): String {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent, 
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        
        val hasAlarm = pendingIntent != null
        val isActive = AlarmReceiver.isAlarmActive()
        
        
        return "Alarm set: $hasAlarm, Currently active: $isActive"
    }

    // Method to reschedule alarm for next day (called from AlarmReceiver)
    fun rescheduleAlarmForNextDay() {
        // This will be called by AlarmReceiver after alarm triggers
        // For now, we'll just log it - in a full implementation,
        // you'd get the saved alarm time from database and reschedule
        println("🔄 Alarm triggered - should reschedule for next day")
    }
}