# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }

# Keep alarm receiver
-keep class com.jumpz.app.AlarmReceiver { *; }
-keep class com.jumpz.app.MainActivity { *; }

# Keep native alarm service methods
-keepclassmembers class com.jumpz.app.MainActivity {
    public void setAlarm(...);
    public void cancelAlarm(...);
    public void dismissAlarm(...);
}

# Keep notification classes
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }

# Keep media player classes
-keep class android.media.MediaPlayer { *; }
-keep class android.media.RingtoneManager { *; }

# Keep vibration classes
-keep class android.os.Vibrator { *; }
-keep class android.os.VibrationEffect { *; }

# Keep camera classes
-keep class androidx.camera.** { *; }

# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }

# Keep Google Sign-In classes
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep sensor classes
-keep class android.hardware.SensorManager { *; }
-keep class android.hardware.Sensor { *; }
-keep class android.hardware.SensorEvent { *; }

# General Android optimizations
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# Keep generic signatures
-keepattributes Signature

# Keep annotations
-keepattributes *Annotation*


