import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/animated_background.dart';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _selectedCameraIndex = 0;
  
  // User data
  String _userName = '';
  int _totalJumps = 0;
  int _goal = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeCamera();
  }

  Future<void> _loadUserData() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      
      final user = auth.currentUser;
      if (user != null) {
        _userName = user.displayName ?? 'User';
      }
      
      final todayProgress = await firestore.getTodayProgress();
      final settings = await firestore.getUserSettings();
      
      setState(() {
        _totalJumps = todayProgress['jumps'] ?? 0;
        _goal = settings['dailyGoal'] ?? 100;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      print('📸 Initializing camera for photo gallery...');
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        print('❌ No cameras found');
        return;
      }

      print('📸 Available cameras: ${_cameras!.length}');
      for (int i = 0; i < _cameras!.length; i++) {
        print('📸 Camera $i: ${_cameras![i].name} (${_cameras![i].lensDirection})');
      }

      // Try to initialize the first camera
      await _initializeCameraController(0);
    } catch (e) {
      print('❌ Error initializing camera: $e');
    }
  }

  Future<void> _initializeCameraController(int cameraIndex) async {
    if (_cameras == null || cameraIndex >= _cameras!.length) {
      print('❌ Invalid camera index: $cameraIndex');
      setState(() {
        _isProcessing = false;
        _isInitialized = false;
      });
      return;
    }

    try {
      print('📸 Initializing camera controller for camera $cameraIndex');
      
      final newController = CameraController(
        _cameras![cameraIndex],
        ResolutionPreset.high,
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
      
      if (mounted) {
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
        
        setState(() {
          _cameraController = newController;
          _selectedCameraIndex = cameraIndex;
          _isInitialized = true;
          _isProcessing = false;
        });
        print('✅ Camera controller initialized successfully');
        print('📸 Current camera: ${_cameras![cameraIndex].name} (${_cameras![cameraIndex].lensDirection})');
      } else {
        newController.dispose();
      }
    } catch (e) {
      print('❌ Error initializing camera controller: $e');
      setState(() {
        _isProcessing = false;
        _isInitialized = false;
      });
      
      // Try next camera if available
      if (cameraIndex + 1 < _cameras!.length) {
        print('📸 Trying next camera...');
        await _initializeCameraController(cameraIndex + 1);
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) {
      print('❌ No other cameras available');
      return;
    }

    // Prevent multiple simultaneous switches
    if (_isProcessing) {
      print('❌ Camera switch already in progress');
      return;
    }

    print('📸 Switching camera from index $_selectedCameraIndex');
    final nextIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    print('📸 Switching to camera index $nextIndex');
    
    // Show processing state and dispose old controller
    setState(() {
      _isProcessing = true;
      _isInitialized = false;
    });
    
    try {
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
          setState(() {
            _isProcessing = false;
            _isInitialized = false;
          });
          throw TimeoutException('Camera initialization timeout');
        },
      );
      
    } catch (e) {
      print('❌ Error switching camera: $e');
      setState(() {
        _isProcessing = false;
        _isInitialized = false;
      });
      
      // Try to fallback to the original camera
      try {
        print('📸 Attempting fallback to original camera...');
        await _initializeCameraController(_selectedCameraIndex);
      } catch (fallbackError) {
        print('❌ Fallback camera initialization failed: $fallbackError');
      }
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('❌ Camera not initialized');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile photo = await _cameraController!.takePicture();
      print('📸 Photo taken: ${photo.path}');
      
      // Here you can save the photo or do something with it
      // For now, let's just show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview as background (like jump screen)
          _buildCameraBackground(),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Photo Gallery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Camera Preview or Placeholder
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCameraContent(),
                    ),
                  ),
                ),
                
                // Controls
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Switch Camera Button
                      if (_cameras != null && _cameras!.length > 1)
                        FloatingActionButton(
                          heroTag: 'photo_gallery_switch_camera',
                          onPressed: _isProcessing ? null : _switchCamera,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: const Icon(Icons.switch_camera, color: Colors.white),
                        ),
                      
                      // Take Picture Button
                      FloatingActionButton(
                        heroTag: 'photo_gallery_take_picture',
                        onPressed: _isProcessing || !_isInitialized ? null : _takePicture,
                        backgroundColor: _isProcessing ? Colors.grey : Colors.white,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Icon(Icons.camera_alt, color: Colors.black),
                      ),
                      
                      // Placeholder for symmetry
                      if (_cameras == null || _cameras!.length <= 1)
                        const SizedBox(width: 56),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_cameras == null || _cameras!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.white70,
            ),
            SizedBox(height: 20),
            Text(
              'No Camera Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'No cameras found on this device',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'Initializing Camera...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return CameraPreview(_cameraController!);
  }

  Widget _buildCameraBackground() {
    // Return camera preview as full-screen background (like jump screen)
    if (_isInitialized && _cameraController != null && _cameraController!.value.isInitialized) {
      return Positioned.fill(
        child: CameraPreview(_cameraController!),
      );
    } else {
      // Fallback to animated background if camera not ready
      return AnimatedBackground(
        type: BackgroundType.gif,
        source: 'assets/images/jumpz_header.gif',
      );
    }
  }
}