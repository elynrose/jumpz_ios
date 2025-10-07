import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

/// Service to manage jump detection settings and provide calculated thresholds
/// based on user preferences
class JumpDetectionSettingsService extends ChangeNotifier {
  final FirestoreService _firestoreService;
  
  // User settings
  int _jumpSensitivity = 3; // 1-5 scale (1=very sensitive, 5=less sensitive)
  String _jumpDetectionMode = 'enhanced'; // 'simple', 'enhanced', 'hybrid'
  
  // Calculated thresholds based on sensitivity
  double _jumpThreshold = 15.0;
  double _pushOffThreshold = 2.0;
  double _freefallThreshold = 0.5;
  double _landingThreshold = 1.5;
  double _gyroVarianceThreshold = 8.0;
  
  JumpDetectionSettingsService(this._firestoreService);
  
  // Getters for current settings
  int get jumpSensitivity => _jumpSensitivity;
  String get jumpDetectionMode => _jumpDetectionMode;
  
  // Getters for calculated thresholds
  double get jumpThreshold => _jumpThreshold;
  double get pushOffThreshold => _pushOffThreshold;
  double get freefallThreshold => _freefallThreshold;
  double get landingThreshold => _landingThreshold;
  double get gyroVarianceThreshold => _gyroVarianceThreshold;
  
  /// Load settings from Firestore and calculate thresholds
  Future<void> loadSettings() async {
    try {
      final settings = await _firestoreService.getUserSettings();
      _jumpSensitivity = settings['jumpSensitivity'] ?? 3;
      _jumpDetectionMode = settings['jumpDetectionMode'] ?? 'enhanced';
      _calculateThresholds();
      notifyListeners();
    } catch (e) {
      print('Error loading jump detection settings: $e');
      // Use default values
      _jumpSensitivity = 3;
      _jumpDetectionMode = 'enhanced';
      _calculateThresholds();
    }
  }
  
  /// Update settings and save to Firestore
  Future<void> updateSettings({
    int? jumpSensitivity,
    String? jumpDetectionMode,
  }) async {
    if (jumpSensitivity != null) _jumpSensitivity = jumpSensitivity;
    if (jumpDetectionMode != null) _jumpDetectionMode = jumpDetectionMode;
    
    _calculateThresholds();
    
    // Save to Firestore
    await _firestoreService.updateUserSettings({
      'jumpSensitivity': _jumpSensitivity,
      'jumpDetectionMode': _jumpDetectionMode,
    });
    
    notifyListeners();
  }
  
  /// Calculate thresholds based on sensitivity setting
  void _calculateThresholds() {
    // Sensitivity multiplier: 1=very sensitive (lower thresholds), 5=less sensitive (higher thresholds)
    final sensitivityMultiplier = _jumpSensitivity / 3.0; // Normalize to 1.0 at sensitivity 3
    
    // Base thresholds (at sensitivity 3)
    const baseJumpThreshold = 15.0;
    const basePushOffThreshold = 2.0;
    const baseFreefallThreshold = 0.5;
    const baseLandingThreshold = 1.5;
    const baseGyroVarianceThreshold = 8.0;
    
    // Calculate thresholds with sensitivity adjustment
    _jumpThreshold = (baseJumpThreshold * sensitivityMultiplier).clamp(8.0, 25.0);
    _pushOffThreshold = (basePushOffThreshold * sensitivityMultiplier).clamp(1.0, 4.0);
    _freefallThreshold = (baseFreefallThreshold * sensitivityMultiplier).clamp(0.2, 1.0);
    _landingThreshold = (baseLandingThreshold * sensitivityMultiplier).clamp(0.8, 3.0);
    _gyroVarianceThreshold = (baseGyroVarianceThreshold * sensitivityMultiplier).clamp(4.0, 15.0);
    
    print('🎯 Jump detection thresholds updated:');
    print('   Sensitivity: $_jumpSensitivity/5');
    print('   Mode: $_jumpDetectionMode');
    print('   Jump threshold: $_jumpThreshold');
    print('   Push-off threshold: $_pushOffThreshold');
    print('   Freefall threshold: $_freefallThreshold');
    print('   Landing threshold: $_landingThreshold');
    print('   Gyro variance threshold: $_gyroVarianceThreshold');
  }
  
  /// Get sensitivity label for display
  String getSensitivityLabel() {
    const labels = ['Very Sensitive', 'Sensitive', 'Normal', 'Less Sensitive', 'Least Sensitive'];
    return labels[_jumpSensitivity - 1];
  }
  
  /// Get detection mode label for display
  String getDetectionModeLabel() {
    switch (_jumpDetectionMode) {
      case 'simple':
        return 'Simple';
      case 'enhanced':
        return 'Enhanced';
      case 'hybrid':
        return 'Hybrid';
      default:
        return 'Enhanced';
    }
  }
}
