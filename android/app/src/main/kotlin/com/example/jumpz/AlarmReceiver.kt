package com.jumpz.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private var mediaPlayer: MediaPlayer? = null
        private var vibrator: Vibrator? = null
        private var isAlarmActive = false
        private var ringtone: android.media.Ringtone? = null
        
        fun isAlarmActive(): Boolean {
            return isAlarmActive
        }
        
        fun stopAlarm() {
            // Set alarm as inactive
            isAlarmActive = false
            
            // Stop ringtone
            ringtone?.stop()
            ringtone = null
            
            // Stop media player
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
            
            // Stop vibration
            vibrator?.cancel()
            vibrator = null
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Jumpz Alarm"
        val message = intent.getStringExtra("message") ?: "Time to jump!"

        println("🚨 ALARM TRIGGERED: $title - $message")

        // Create notification channel for alarm
        createNotificationChannel(context)

        // Create full-screen intent for alarm
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create dismiss intent
        val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = "DISMISS_ALARM"
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context, 1, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Check if this is a dismiss action
        if (intent.action == "DISMISS_ALARM") {
            stopAlarm(context)
            return
        }

        // Set alarm as active
        isAlarmActive = true

        // Create notification with dismiss action
        val notification = NotificationCompat.Builder(context, "jumpz_alarm_channel")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            .setVibrate(longArrayOf(0L, 1000L, 500L, 1000L, 500L, 1000L, 500L, 1000L))
            .setLights(0xFFFF5722.toInt(), 1000, 500)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss",
                dismissPendingIntent
            )
            .build()

        // Show notification
        val notificationManager = NotificationManagerCompat.from(context)
        notificationManager.notify(1, notification)

        // Play alarm sound
        playAlarmSound(context)

        // Vibrate
        vibrate(context)
    }

    private fun stopAlarm(context: Context) {
        // Set alarm as inactive
        isAlarmActive = false
        
        // Stop ringtone
        ringtone?.stop()
        ringtone = null
        
        // Stop media player
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        
        // Stop vibration
        vibrator?.cancel()
        vibrator = null
        
        // Cancel notification
        val notificationManager = NotificationManagerCompat.from(context)
        notificationManager.cancel(1)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "jumpz_alarm_channel",
                "Jumpz Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Scheduled alarms for daily jump goals"
                enableVibration(true)
                enableLights(true)
                lightColor = 0xFFFF5722.toInt()
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun playAlarmSound(context: Context) {
        try {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ringtone = RingtoneManager.getRingtone(context, alarmUri)
            ringtone?.play()
            
            // Store reference for stopping
            mediaPlayer = MediaPlayer().apply {
                setDataSource(context, alarmUri)
                prepare()
                start()
                isLooping = true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun vibrate(context: Context) {
        vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val vibrationPattern = longArrayOf(0L, 1000L, 500L, 1000L, 500L, 1000L, 500L, 1000L)
            val vibrationEffect = VibrationEffect.createWaveform(vibrationPattern, 0)
            vibrator?.vibrate(vibrationEffect)
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0L, 1000L, 500L, 1000L, 500L, 1000L, 500L, 1000L), 0)
        }
    }
}
