import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../services/camera_jump_detector.dart';
import '../screens/camera_jump_screen.dart';

class CameraJumpView extends StatefulWidget {
  final CameraJumpDetector jumpDetector;
  final VoidCallback? onJumpDetected;
  final int currentCount;
  final int existingJumps;
  final int newJumps;
  final int goal;
  final bool isCompleted;
  final bool isLoading;

  const CameraJumpView({
    super.key,
    required this.jumpDetector,
    this.onJumpDetected,
    required this.currentCount,
    required this.existingJumps,
    required this.newJumps,
    required this.goal,
    required this.isCompleted,
    required this.isLoading,
  });

  @override
  State<CameraJumpView> createState() => _CameraJumpViewState();
}

class _CameraJumpViewState extends State<CameraJumpView> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    widget.jumpDetector.addListener(_onDetectorUpdate);
    
    // Initialize camera if not already done
    if (!widget.jumpDetector.isInitialized) {
      widget.jumpDetector.initialize();
    }
  }

  @override
  void dispose() {
    widget.jumpDetector.removeListener(_onDetectorUpdate);
    super.dispose();
  }

  void _onDetectorUpdate() {
    if (mounted) {
      setState(() {});
      if (widget.onJumpDetected != null) {
        widget.onJumpDetected!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Container(
        color: Colors.black,
        child: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: _buildCameraPreview(),
          ),
          
          // Main content overlay (similar to jump screen)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // App bar with camera switch button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                      ),
                      _buildCameraSwitchButton(),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Progress Circle (same as jump screen)
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background circle
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 8,
                                  ),
                                ),
                              ),
                              // Progress arc
                              SizedBox(
                                width: 200,
                                height: 200,
                                child: CircularProgressIndicator(
                                  value: widget.goal > 0 ? widget.currentCount / widget.goal : 0.0,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                                ),
                              ),
                              // Count display
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${widget.currentCount}',
                                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        const Shadow(
                                          offset: Offset(2, 2),
                                          blurRadius: 4,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'jumps',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      shadows: [
                                        const Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 2,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Status message
                        Text(
                          widget.currentCount >= widget.goal
                              ? 'Goal Reached! 🎉'
                              : 'Keep jumping! ${widget.goal - widget.currentCount} to go',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              const Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        // Take photo button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: widget.jumpDetector.isProcessing || !widget.jumpDetector.isInitialized 
                                ? null 
                                : () async {
                                    await _takePhoto();
                                  },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        ],
      ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!widget.jumpDetector.isInitialized || widget.jumpDetector.cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.jumpDetector.isProcessing)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
              else
                const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 64,
                ),
              const SizedBox(height: 16),
              Text(
                widget.jumpDetector.isProcessing 
                    ? 'Switching camera...' 
                    : 'Initializing camera...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CameraPreview(widget.jumpDetector.cameraController!);
  }

  Widget _buildCameraSwitchButton() {
    if (widget.jumpDetector.cameras == null || widget.jumpDetector.cameras!.length <= 1) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: widget.jumpDetector.isProcessing ? null : () {
        widget.jumpDetector.switchCamera();
      },
      icon: widget.jumpDetector.isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.switch_camera, color: Colors.white),
    );
  }

  Future<void> _takePhoto() async {
    try {
      print('📸 Starting photo capture...');
      
      if (widget.jumpDetector.cameraController == null) {
        _showErrorSnackBar('Camera controller is null');
        return;
      }
      
      if (!widget.jumpDetector.cameraController!.value.isInitialized) {
        _showErrorSnackBar('Camera not initialized');
        return;
      }

      print('📸 Taking camera photo...');
      final XFile photo = await widget.jumpDetector.cameraController!.takePicture();
      print('📸 Camera photo taken: ${photo.path}');
      
      // Check if file exists
      final file = File(photo.path);
      if (!await file.exists()) {
        _showErrorSnackBar('Photo file not found');
        return;
      }
      
      // Save to gallery
      print('📸 Saving to gallery...');
      final result = await ImageGallerySaver.saveFile(
        photo.path,
        name: "Jumpz_${DateTime.now().millisecondsSinceEpoch}",
      );
      print('📸 Gallery save result: $result');

      if (result['isSuccess'] == true) {
        _showSuccessSnackBar('Photo saved to gallery!');
      } else {
        _showErrorSnackBar('Failed to save photo to gallery: ${result['errorMessage']}');
      }

    } catch (e) {
      print('📸 Photo capture error: $e');
      _showErrorSnackBar('Error taking photo: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildJumpDetectionOverlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Jumps Detected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${widget.jumpDetector.count}',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: widget.jumpDetector.isRunning ? null : () {
                  widget.jumpDetector.start();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: !widget.jumpDetector.isRunning ? null : () {
                  widget.jumpDetector.stop();
                },
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  widget.jumpDetector.resetCount();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Simulate jump detection button for testing
          ElevatedButton.icon(
            onPressed: () {
              widget.jumpDetector.simulateJumpDetection();
            },
            icon: const Icon(Icons.sports_gymnastics),
            label: const Text('Simulate Jump'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
