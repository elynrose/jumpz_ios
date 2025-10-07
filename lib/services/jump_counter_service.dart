import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';
import 'jump_detection_settings_service.dart';

/// Service that listens to accelerometer events and attempts to estimate the
/// number of jumps performed by the user. It uses a simple peak detection
/// algorithm on the magnitude of the acceleration vector. Each time the
/// magnitude crosses a high threshold from below it is treated as a jump. This
/// algorithm is intentionally simple and meant only as a demonstration; more
/// sophisticated techniques may yield better accuracy【250786208032889†L165-L173】.
class JumpCounterService {
  late StreamSubscription<AccelerometerEvent> _subscription;
  final StreamController<int> _countController = StreamController<int>.broadcast();
  bool _aboveThreshold = false;
  int _count = 0;
  bool _isRunning = false;
  DateTime? _lastJumpTime;
  
  // Settings service for dynamic thresholds
  JumpDetectionSettingsService? _settingsService;

  /// A stream that emits the current jump count whenever it changes.
  Stream<int> get countStream => _countController.stream;
  
  /// Set the settings service for dynamic thresholds
  void setSettingsService(JumpDetectionSettingsService settingsService) {
    _settingsService = settingsService;
  }

  /// Starts listening to accelerometer events and counting jumps. If counting
  /// is already in progress this method does nothing.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    
    _subscription = accelerometerEvents.listen((event) {
      final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Get dynamic threshold from settings service
      final jumpThreshold = _settingsService?.jumpThreshold ?? 15.0;
      
      // Debug logging
      if (magnitude > 8.0) { // Log when magnitude is significant
        print('📊 Jump detection: magnitude=$magnitude, threshold=$jumpThreshold, aboveThreshold=$_aboveThreshold, count=$_count');
      }
      
      if (!_aboveThreshold && magnitude > jumpThreshold) {
        // Rising edge detected: count a jump and mark that we're above threshold.
        _aboveThreshold = true;
        _count++;
        _lastJumpTime = DateTime.now();
        print('🦘 Jump detected! Count: $_count, Magnitude: $magnitude');
        _countController.add(_count);
      } else if (_aboveThreshold && magnitude < 8.0) {
        // Falling below 8.0 resets the state so we can count a new jump.
        _aboveThreshold = false;
        print('📉 Reset threshold state, ready for next jump');
      }
      
      // Auto-reset if stuck above threshold for more than 3 seconds
      if (_aboveThreshold && _lastJumpTime != null) {
        final timeSinceLastJump = DateTime.now().difference(_lastJumpTime!);
        if (timeSinceLastJump.inSeconds > 3) {
          _aboveThreshold = false;
          print('⏰ Auto-reset threshold state after 3 seconds');
        }
      }
    });
  }

  /// Stops listening to accelerometer events and resets state. The current
  /// count is not cleared automatically; call [reset] if you need to clear it.
  void stop() {
    _subscription.cancel();
    _isRunning = false;
  }

  /// Resets the jump count to zero and emits the new count on the stream.
  void reset() {
    _count = 0;
    _aboveThreshold = false;
    _countController.add(_count);
  }

  /// Disposes resources used by this service. After calling this method the
  /// service cannot be restarted.
  void dispose() {
    _subscription.cancel();
    _countController.close();
  }
}