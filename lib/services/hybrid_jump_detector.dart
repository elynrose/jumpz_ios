import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Hybrid jump detector that starts with simple detection and can enhance
/// with anti-cheat features when needed
class HybridJumpDetector {
  static const double _simpleThreshold = 12.0; // Simple threshold
  static const double _enhancedThreshold = 2.0; // Enhanced threshold
  static const double _freefallThreshold = 0.5;
  static const int _minFreefallMs = 50;
  static const int _maxFreefallMs = 400;
  static const double _landingThreshold = 1.5;
  static const int _landingWindowMs = 300;
  static const double _gyroVarianceThreshold = 8.0;

  late StreamSubscription<AccelerometerEvent> _accelSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroSubscription;
  final StreamController<int> _countController = StreamController<int>.broadcast();
  
  bool _isRunning = false;
  int _count = 0;
  DateTime? _lastJumpTime;
  
  // Detection mode
  bool _useEnhancedDetection = false;
  bool _aboveThreshold = false;
  
  // Enhanced detection state
  bool _inJumpSequence = false;
  DateTime? _pushOffTime;
  DateTime? _freefallStart;
  
  // Sensor buffers
  final List<SensorData> _accelBuffer = [];
  final List<SensorData> _gyroBuffer = [];
  
  /// A stream that emits the current jump count whenever it changes.
  Stream<int> get countStream => _countController.stream;

  /// Starts hybrid jump detection
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _count = 0;
    
    print('🚀 Starting hybrid jump detection...');
    
    // Start with simple detection
    _accelSubscription = accelerometerEvents.listen((event) {
      _processAccelerometerData(event);
    });
    
    // Gyroscope for enhanced detection
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
    
    print('🛑 Hybrid jump detection stopped');
  }

  /// Disposes resources
  void dispose() {
    stop();
    _countController.close();
  }

  /// Processes accelerometer data
  void _processAccelerometerData(AccelerometerEvent event) {
    final timestamp = DateTime.now();
    final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    // Add to buffer
    _accelBuffer.add(SensorData(timestamp, event.x, event.y, event.z, magnitude));
    if (_accelBuffer.length > 50) {
      _accelBuffer.removeAt(0);
    }
    
    if (_useEnhancedDetection) {
      _enhancedDetection(timestamp, magnitude);
    } else {
      _simpleDetection(magnitude);
      
      // Switch to enhanced detection if we detect potential cheating
      if (_shouldUseEnhancedDetection()) {
        print('🔄 Switching to enhanced detection for anti-cheat');
        _useEnhancedDetection = true;
      }
    }
  }

  /// Processes gyroscope data
  void _processGyroscopeData(GyroscopeEvent event) {
    final timestamp = DateTime.now();
    final gyroMagnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    _gyroBuffer.add(SensorData(timestamp, event.x, event.y, event.z, gyroMagnitude));
    if (_gyroBuffer.length > 50) {
      _gyroBuffer.removeAt(0);
    }
  }

  /// Simple jump detection (original method)
  void _simpleDetection(double magnitude) {
    if (!_aboveThreshold && magnitude > _simpleThreshold) {
      _aboveThreshold = true;
      _count++;
      _lastJumpTime = DateTime.now();
      print('🦘 Simple jump detected! Count: $_count, Magnitude: $magnitude');
      _countController.add(_count);
    } else if (_aboveThreshold && magnitude < 8.0) {
      _aboveThreshold = false;
      print('📉 Reset threshold state, ready for next jump');
    }
  }

  /// Enhanced jump detection with anti-cheat
  void _enhancedDetection(DateTime timestamp, double magnitude) {
    // Detect push-off
    if (!_inJumpSequence && magnitude > _enhancedThreshold) {
      _detectPushOff(timestamp, magnitude);
    }
    
    // Check for free-fall
    if (_inJumpSequence && _pushOffTime != null) {
      _checkFreefall(timestamp, magnitude);
    }
    
    // Check for landing
    if (_inJumpSequence && _freefallStart != null) {
      _checkLanding(timestamp, magnitude);
    }
  }

  /// Detects push-off phase
  void _detectPushOff(DateTime timestamp, double magnitude) {
    print('🚀 Push-off detected: magnitude=$magnitude');
    _inJumpSequence = true;
    _pushOffTime = timestamp;
    _freefallStart = null;
  }

  /// Checks for free-fall phase
  void _checkFreefall(DateTime timestamp, double magnitude) {
    if (_pushOffTime == null) return;
    
    final timeSincePushOff = timestamp.difference(_pushOffTime!).inMilliseconds;
    
    if (timeSincePushOff > 10 && timeSincePushOff < _maxFreefallMs) {
      if (magnitude < _freefallThreshold) {
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
    
    if (freefallDuration >= _minFreefallMs && freefallDuration <= _maxFreefallMs) {
      if (magnitude > _landingThreshold && totalDuration < _landingWindowMs) {
        _validateJump(timestamp);
      }
    }
    
    if (totalDuration > _landingWindowMs) {
      _resetJumpSequence();
    }
  }

  /// Validates jump with anti-cheat measures
  void _validateJump(DateTime timestamp) {
    final gyroVariance = _calculateGyroVariance();
    final isLowFrequency = _checkFrequencyCharacteristics();
    
    if (gyroVariance < _gyroVarianceThreshold && isLowFrequency) {
      _count++;
      _lastJumpTime = timestamp;
      print('✅ Valid jump detected! Count: $_count');
      _countController.add(_count);
    } else {
      print('❌ Rejected as potential shake: gyroVariance=$gyroVariance, isLowFreq=$isLowFrequency');
    }
    
    _resetJumpSequence();
  }

  /// Calculates gyroscope variance
  double _calculateGyroVariance() {
    if (_gyroBuffer.length < 10) return 0.0;
    
    final recentGyro = _gyroBuffer.length > 10 
      ? _gyroBuffer.sublist(_gyroBuffer.length - 10) 
      : _gyroBuffer;
    final mean = recentGyro.map((data) => data.magnitude).reduce((a, b) => a + b) / recentGyro.length;
    final variance = recentGyro.map((data) => math.pow(data.magnitude - mean, 2)).reduce((a, b) => a + b) / recentGyro.length;
    
    return variance;
  }

  /// Checks frequency characteristics
  bool _checkFrequencyCharacteristics() {
    if (_accelBuffer.length < 20) return true;
    
    final recentAccel = _accelBuffer.length > 20 
      ? _accelBuffer.sublist(_accelBuffer.length - 20) 
      : _accelBuffer;
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
    
    return lowFreqEnergy > highFreqEnergy;
  }

  /// Determines if enhanced detection should be used
  bool _shouldUseEnhancedDetection() {
    if (_accelBuffer.length < 20) return false;
    
    final recentMagnitudes = _accelBuffer.length > 20 
      ? _accelBuffer.sublist(_accelBuffer.length - 20).map((data) => data.magnitude).toList()
      : _accelBuffer.map((data) => data.magnitude).toList();
    
    // Check for suspicious patterns (rapid high-magnitude events)
    int rapidEvents = 0;
    for (int i = 1; i < recentMagnitudes.length; i++) {
      if (recentMagnitudes[i] > 8.0 && recentMagnitudes[i-1] < 5.0) {
        rapidEvents++;
      }
    }
    
    return rapidEvents > 3; // Too many rapid events suggests shaking
  }

  /// Resets jump sequence
  void _resetJumpSequence() {
    _inJumpSequence = false;
    _pushOffTime = null;
    _freefallStart = null;
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


