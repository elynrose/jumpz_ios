import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sensors_plus/sensors_plus.dart';
import 'jump_detection_settings_service.dart';

/// Enhanced jump detection service that implements advanced sensor fusion
/// techniques to distinguish real jumps from phone shaking or manipulation.
class EnhancedJumpDetector {
  static const int _minFreefallMs = 50; // Minimum free-fall duration (reduced)
  static const int _maxFreefallMs = 400; // Maximum free-fall duration (increased)
  static const int _landingWindowMs = 300; // Time window to detect landing after free-fall (increased)
  static const int _bufferSize = 50; // Sensor data buffer size
  static const int _sampleRate = 100; // Hz

  late StreamSubscription<AccelerometerEvent> _accelSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroSubscription;
  final StreamController<int> _countController = StreamController<int>.broadcast();
  
  bool _isRunning = false;
  int _count = 0;
  DateTime? _lastJumpTime;
  
  // Settings service for dynamic thresholds
  JumpDetectionSettingsService? _settingsService;
  
  // Sensor data buffers
  final List<SensorData> _accelBuffer = [];
  final List<SensorData> _gyroBuffer = [];
  
  // Jump detection state
  bool _inJumpSequence = false;
  DateTime? _pushOffTime;
  DateTime? _freefallStart;
  
  // Fallback simple detection
  bool _useSimpleDetection = false;
  bool _aboveThreshold = false;
  double _lastMagnitude = 0.0;
  
  /// A stream that emits the current jump count whenever it changes.
  Stream<int> get countStream => _countController.stream;
  
  /// Set the settings service for dynamic thresholds
  void setSettingsService(JumpDetectionSettingsService settingsService) {
    _settingsService = settingsService;
  }

  /// Starts enhanced jump detection using multiple sensors
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _count = 0;
    
    print('🚀 Starting enhanced jump detection...');
    
    // Accelerometer for vertical movement detection
    _accelSubscription = accelerometerEvents.listen((event) {
      _processAccelerometerData(event);
    });
    
    // Gyroscope for rotation detection (anti-shake)
    _gyroSubscription = gyroscopeEvents.listen((event) {
      _processGyroscopeData(event);
    });
  }

  /// Stops jump detection
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    
    _accelSubscription.cancel();
    _gyroSubscription.cancel();
    
    print('🛑 Enhanced jump detection stopped');
  }

  /// Disposes resources
  void dispose() {
    stop();
    _countController.close();
  }

  /// Processes accelerometer data for jump detection
  void _processAccelerometerData(AccelerometerEvent event) {
    final timestamp = DateTime.now();
    final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Add to buffer
    _accelBuffer.add(SensorData(timestamp, event.x, event.y, event.z, magnitude));
    
    // Keep buffer size manageable
    if (_accelBuffer.length > _bufferSize) {
      _accelBuffer.removeAt(0);
    }
    
    // Use simple detection as fallback if enhanced detection is too strict
    if (_useSimpleDetection) {
      _simpleJumpDetection(magnitude);
      return;
    }
    
    // Enhanced detection
    // Detect push-off (jump initiation)
    final pushOffThreshold = _settingsService?.pushOffThreshold ?? 2.0;
    if (!_inJumpSequence && magnitude > pushOffThreshold) {
      _detectPushOff(timestamp, magnitude);
    }
    
    // Check for free-fall during jump sequence
    if (_inJumpSequence && _pushOffTime != null) {
      _checkFreefall(timestamp, magnitude);
    }
    
    // Check for landing
    if (_inJumpSequence && _freefallStart != null) {
      _checkLanding(timestamp, magnitude);
    }
    
    // Fallback to simple detection if no jumps detected for a while
    if (_accelBuffer.length > 20) {
      final recentMagnitudes = _accelBuffer.length > 20 
        ? _accelBuffer.sublist(_accelBuffer.length - 20).map((data) => data.magnitude).toList()
        : _accelBuffer.map((data) => data.magnitude).toList();
      final maxRecent = recentMagnitudes.reduce((a, b) => a > b ? a : b);
      if (maxRecent > 3.0 && _count == 0) {
        print('🔄 Switching to simple detection - enhanced detection too strict');
        _useSimpleDetection = true;
      }
    }
  }

  /// Processes gyroscope data for anti-shake detection
  void _processGyroscopeData(GyroscopeEvent event) {
    final timestamp = DateTime.now();
    final gyroMagnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    _gyroBuffer.add(SensorData(timestamp, event.x, event.y, event.z, gyroMagnitude));
    
    if (_gyroBuffer.length > _bufferSize) {
      _gyroBuffer.removeAt(0);
    }
  }

  /// Detects push-off phase of a jump
  void _detectPushOff(DateTime timestamp, double magnitude) {
    print('🚀 Push-off detected: magnitude=$magnitude');
    _inJumpSequence = true;
    _pushOffTime = timestamp;
    _freefallStart = null;
  }

  /// Checks for free-fall phase (airtime)
  void _checkFreefall(DateTime timestamp, double magnitude) {
    if (_pushOffTime == null) return;
    
    final timeSincePushOff = timestamp.difference(_pushOffTime!).inMilliseconds;
    
    // Look for free-fall after push-off
    if (timeSincePushOff > 10 && timeSincePushOff < _maxFreefallMs) {
      final freefallThreshold = _settingsService?.freefallThreshold ?? 0.5;
      if (magnitude < freefallThreshold) {
        if (_freefallStart == null) {
          _freefallStart = timestamp;
          print('🪂 Free-fall started: magnitude=$magnitude');
        }
      }
    }
  }

  /// Checks for landing phase
  void _checkLanding(DateTime timestamp, double magnitude) {
    if (_freefallStart == null || _pushOffTime == null) return;
    
    final freefallDuration = timestamp.difference(_freefallStart!).inMilliseconds;
    final totalDuration = timestamp.difference(_pushOffTime!).inMilliseconds;
    
    // Check if we have a valid free-fall duration
    if (freefallDuration >= _minFreefallMs && freefallDuration <= _maxFreefallMs) {
      // Look for landing spike
      final landingThreshold = _settingsService?.landingThreshold ?? 1.5;
      if (magnitude > landingThreshold && totalDuration < _landingWindowMs) {
        _validateJump(timestamp);
      }
    }
    
    // Reset if too much time has passed
    if (totalDuration > _landingWindowMs) {
      _resetJumpSequence();
    }
  }

  /// Validates that the detected sequence is a real jump (not shaking)
  void _validateJump(DateTime timestamp) {
    // Check gyroscope variance during the jump sequence
    final gyroVariance = _calculateGyroVariance();
    
    // Check frequency characteristics
    final isLowFrequency = _checkFrequencyCharacteristics();
    
    // Anti-shake validation
    final gyroVarianceThreshold = _settingsService?.gyroVarianceThreshold ?? 8.0;
    if (gyroVariance < gyroVarianceThreshold && isLowFrequency) {
      _count++;
      _lastJumpTime = timestamp;
      print('✅ Valid jump detected! Count: $_count');
      print('   Gyro variance: $gyroVariance (threshold: $gyroVarianceThreshold)');
      _countController.add(_count);
    } else {
      print('❌ Rejected as potential shake: gyroVariance=$gyroVariance, isLowFreq=$isLowFrequency');
    }
    
    _resetJumpSequence();
  }

  /// Calculates gyroscope variance during the jump sequence
  double _calculateGyroVariance() {
    if (_gyroBuffer.length < 10) return 0.0;
    
    final recentGyro = _gyroBuffer.length > 10 ? _gyroBuffer.sublist(_gyroBuffer.length - 10) : _gyroBuffer;
    final mean = recentGyro.map((data) => data.magnitude).reduce((a, b) => a + b) / recentGyro.length;
    final variance = recentGyro.map((data) => math.pow(data.magnitude - mean, 2)).reduce((a, b) => a + b) / recentGyro.length;
    
    return variance;
  }

  /// Checks if the movement has low-frequency characteristics (jump vs shake)
  bool _checkFrequencyCharacteristics() {
    if (_accelBuffer.length < 20) return true;
    
    // Simple frequency analysis - check for sustained high-frequency energy
    final recentAccel = _accelBuffer.length > 20 ? _accelBuffer.sublist(_accelBuffer.length - 20) : _accelBuffer;
    double highFreqEnergy = 0.0;
    double lowFreqEnergy = 0.0;
    
    for (int i = 1; i < recentAccel.length; i++) {
      final diff = (recentAccel[i].magnitude - recentAccel[i-1].magnitude).abs();
      if (diff > 2.0) {
        highFreqEnergy += diff;
      } else {
        lowFreqEnergy += diff;
      }
    }
    
    // Jumps should have more low-frequency energy
    return lowFreqEnergy > highFreqEnergy;
  }

  /// Resets the jump detection sequence
  void _resetJumpSequence() {
    _inJumpSequence = false;
    _pushOffTime = null;
    _freefallStart = null;
  }

  /// Simple jump detection as fallback (original method)
  void _simpleJumpDetection(double magnitude) {
    // Get dynamic threshold from settings service
    final simpleThreshold = _settingsService?.jumpThreshold ?? 12.0;
    
    if (!_aboveThreshold && magnitude > simpleThreshold) {
      _aboveThreshold = true;
      _count++;
      _lastJumpTime = DateTime.now();
      print('🦘 Simple jump detected! Count: $_count, Magnitude: $magnitude, Threshold: $simpleThreshold');
      _countController.add(_count);
    } else if (_aboveThreshold && magnitude < 8.0) {
      _aboveThreshold = false;
      print('📉 Reset threshold state, ready for next jump');
    }
  }
}

/// Data class for sensor readings
class SensorData {
  final DateTime timestamp;
  final double x;
  final double y;
  final double z;
  final double magnitude;

  SensorData(this.timestamp, this.x, this.y, this.z, this.magnitude);
}
