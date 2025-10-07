import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraJumpDetector extends ChangeNotifier {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _count = 0;
  bool _isRunning = false;
  
  // Detection parameters
  double _imageHeight = 0;
  double _kneeLineY = 0;
  double _floorY = 0;
  
  // Stream controllers
  final StreamController<int> _countController = StreamController<int>.broadcast();
  
  // Getters
  int get count => _count;
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  bool get isRunning => _isRunning;
  CameraController? get cameraController => _cameraController;
  List<CameraDescription>? get cameras => _cameras;
  int get selectedCameraIndex => _selectedCameraIndex;
  
  Stream<int> get countStream => _countController.stream;

  /// Sets up detection parameters
  void setupDetection({
    required double imageHeight,
    required double kneeLineY,
    required double floorY,
  }) {
    _imageHeight = imageHeight;
    _kneeLineY = kneeLineY;
    _floorY = floorY;
    print('📷 Camera jump detector setup: height=$imageHeight, knee=$kneeLineY, floor=$floorY');
  }

  /// Initializes the camera
  Future<void> initialize() async {
    try {
      print('📷 Initializing camera jump detector...');
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        print('❌ No cameras available');
        return;
      }

      print('📷 Available cameras: ${_cameras!.length}');
      for (int i = 0; i < _cameras!.length; i++) {
        print('📷 Camera $i: ${_cameras![i].name} (${_cameras![i].lensDirection})');
      }

      await _initializeCameraController(0);
    } catch (e) {
      print('❌ Error initializing camera: $e');
    }
  }

  /// Initializes camera controller for specific camera
  Future<void> _initializeCameraController(int cameraIndex) async {
    if (_cameras == null || cameraIndex >= _cameras!.length) {
      print('❌ Invalid camera index: $cameraIndex');
      _isProcessing = false;
      notifyListeners();
      return;
    }

    try {
      print('📷 Initializing camera controller for camera $cameraIndex');
      
      final newController = CameraController(
        _cameras![cameraIndex],
        ResolutionPreset.medium, // Use medium for better performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Better compatibility
      );

      // Initialize with timeout
      await newController.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('❌ Camera initialization timeout');
          throw TimeoutException('Camera initialization timeout');
        },
      );
      
      // Dispose old controller if exists
      if (_cameraController != null) {
        try {
          await _cameraController!.dispose().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              print('⚠️ Old camera dispose timeout, continuing...');
            },
          );
        } catch (e) {
          print('⚠️ Error disposing old camera: $e');
        }
      }
      
      _cameraController = newController;
      _selectedCameraIndex = cameraIndex;
      _isInitialized = true;
      _isProcessing = false;
      
      print('✅ Camera controller initialized successfully');
      print('📷 Current camera: ${_cameras![cameraIndex].name} (${_cameras![cameraIndex].lensDirection})');
      
      notifyListeners();
    } catch (e) {
      print('❌ Error initializing camera controller: $e');
      _isProcessing = false;
      _isInitialized = false;
      notifyListeners();
      
      // Try next camera if available
      if (cameraIndex + 1 < _cameras!.length) {
        print('📷 Trying next camera...');
        await _initializeCameraController(cameraIndex + 1);
      }
    }
  }

  /// Switches to the next available camera
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) {
      print('❌ No other cameras available');
      return;
    }

    // Prevent multiple simultaneous switches
    if (_isProcessing) {
      print('❌ Camera switch already in progress');
      return;
    }

    print('📷 Switching camera from index $_selectedCameraIndex');
    final nextIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    print('📷 Switching to camera index $nextIndex');
    
    // Set processing state
    _isProcessing = true;
    _isInitialized = false;
    notifyListeners();
    
    try {
      // Stop any running detection
      final wasRunning = _isRunning;
      if (_isRunning) {
        stop();
      }
      
      // Dispose old controller with timeout to prevent hanging
      final disposeFuture = _cameraController?.dispose();
      if (disposeFuture != null) {
        await disposeFuture.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('⚠️ Camera dispose timeout, continuing...');
          },
        );
      }
      _cameraController = null;
      
      // Add delay to ensure proper cleanup
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Initialize new camera with timeout
      await _initializeCameraController(nextIndex).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('❌ Camera initialization timeout');
          _isProcessing = false;
          _isInitialized = false;
          notifyListeners();
          throw TimeoutException('Camera initialization timeout');
        },
      );
      
      // Restart detection if it was running
      if (wasRunning) {
        start();
      }
      
    } catch (e) {
      print('❌ Error switching camera: $e');
      _isProcessing = false;
      _isInitialized = false;
      notifyListeners();
      
      // Try to fallback to the original camera
      try {
        print('📷 Attempting fallback to original camera...');
        await _initializeCameraController(_selectedCameraIndex);
      } catch (fallbackError) {
        print('❌ Fallback camera initialization failed: $fallbackError');
      }
    }
  }

  /// Starts jump detection
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _count = 0;
    print('📷 Camera jump detection started');
    notifyListeners();
  }

  /// Stops jump detection
  void stop() {
    if (!_isRunning) return;
    
    _isRunning = false;
    print('📷 Camera jump detection stopped');
    notifyListeners();
  }

  /// Resets the jump count
  void resetCount() {
    _count = 0;
    _countController.add(_count);
    notifyListeners();
  }

  /// Simulates jump detection (placeholder for actual computer vision)
  void simulateJumpDetection() {
    if (!_isRunning) return;
    
    // This is a placeholder - in a real implementation, you would use
    // computer vision to detect jumps from the camera feed
    _count++;
    _countController.add(_count);
    print('🦘 Jump detected! Count: $_count');
    notifyListeners();
  }

  /// Disposes resources
  @override
  void dispose() {
    stop();
    _cameraController?.dispose();
    _countController.close();
    super.dispose();
  }
}
