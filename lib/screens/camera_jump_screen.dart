import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/camera_jump_detector.dart';
import '../services/firestore_service.dart';
// import '../services/subscription_service.dart';
import '../services/mock_subscription_service.dart';
import '../services/calories_service.dart';
import '../utils/calories_calculator.dart';
import '../widgets/camera_jump_view.dart';
import 'subscription_gate_screen.dart';

class CameraJumpScreen extends StatefulWidget {
  final int goal;
  
  const CameraJumpScreen({super.key, required this.goal});

  @override
  State<CameraJumpScreen> createState() => _CameraJumpScreenState();
}

class _CameraJumpScreenState extends State<CameraJumpScreen> {
  late CameraJumpDetector _jumpDetector;
  int _currentCount = 0;
  int _existingJumps = 0;
  int _newJumps = 0;
  bool _isCompleted = false;
  bool _isLoading = true;
  
  // Calories tracking
  DateTime? _sessionStartTime;
  double? _userWeight;
  bool _hasPremiumAccess = false;

  @override
  void initState() {
    super.initState();
    _jumpDetector = CameraJumpDetector();
    _loadTodayProgress();
    _loadPremiumAccess();
    _loadUserWeight();
  }

  Future<void> _loadTodayProgress() async {
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final todayProgress = await firestore.getTodayProgress();
      final existingJumps = todayProgress['jumps'] as int? ?? 0;
      
      setState(() {
        _existingJumps = existingJumps;
        _currentCount = existingJumps;
        _isLoading = false;
      });
      
      _startJumpDetection();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _startJumpDetection();
    }
  }

  Future<void> _loadPremiumAccess() async {
    try {
      final subscriptionService = Provider.of<MockSubscriptionService>(context, listen: false);
      final hasAccess = await subscriptionService.hasPremiumAccess().first;
      setState(() {
        _hasPremiumAccess = hasAccess;
      });
    } catch (e) {
      print('Error loading premium access: $e');
    }
  }

  Future<void> _loadUserWeight() async {
    try {
      final caloriesService = Provider.of<CaloriesService>(context, listen: false);
      final weight = await caloriesService.getUserWeight();
      setState(() {
        _userWeight = weight;
      });
    } catch (e) {
      print('Error loading user weight: $e');
    }
  }

  void _startJumpDetection() {
    // Set up detection parameters
    final screenHeight = MediaQuery.of(context).size.height;
    _jumpDetector.setupDetection(
      imageHeight: screenHeight,
      kneeLineY: screenHeight * 0.6, // Adjust based on your setup
      floorY: screenHeight * 0.9, // Adjust based on your setup
    );
    
    // Start session timing for calories tracking
    _sessionStartTime = DateTime.now();
    
    _jumpDetector.addListener(_onJumpDetected);
    _jumpDetector.start(); // Start the camera detector
    print('📷 Camera jump detector started');
  }

  void _onJumpDetected() {
    setState(() {
      _newJumps = _jumpDetector.count;
      _currentCount = _existingJumps + _newJumps;
      
      if (_currentCount >= widget.goal && !_isCompleted) {
        _isCompleted = true;
        _jumpDetector.stop();
        _playGoalCompletionFeedback();
      }
    });
  }

  Future<void> _playGoalCompletionFeedback() async {
    try {
      // Vibrate for goal completion
      await HapticFeedback.heavyImpact();
      
      // Play system sound for completion
      if (Platform.isAndroid) {
        await SystemSound.play(SystemSoundType.click);
      } else if (Platform.isIOS) {
        await SystemSound.play(SystemSoundType.click);
      }
      
      // Additional vibration pattern for celebration
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      
      // Show completion dialog after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      _showSessionCompletionDialog();
      
    } catch (e) {
      print('Error playing goal completion feedback: $e');
    }
  }
  
  /// Shows a dialog when the session is completed
  void _showSessionCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Goal Reached!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Congratulations! You\'ve completed your goal of ${widget.goal} jumps.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Total jumps today: $_currentCount',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                await _completeSession();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Session Completed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeSession() async {
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      await firestore.recordDailyProgress(_newJumps);
      
      // Record calories if user has premium access
      if (_hasPremiumAccess && _sessionStartTime != null) {
        try {
          final caloriesService = Provider.of<CaloriesService>(context, listen: false);
          final sessionDuration = DateTime.now().difference(_sessionStartTime!).inMinutes.toDouble();
          
          await caloriesService.recordSessionCalories(
            jumpCount: _newJumps,
            durationMinutes: sessionDuration,
            weightKg: _userWeight,
          );
          
          print('✅ Calories recorded for camera session: $_newJumps jumps, ${sessionDuration.toStringAsFixed(1)} minutes');
        } catch (e) {
          print('❌ Error recording calories: $e');
        }
      }
      
      if (mounted) {
        Navigator.pop(context, _currentCount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving progress: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _jumpDetector.removeListener(_onJumpDetected);
    _jumpDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.goal > 0 ? _currentCount / widget.goal : 0.0;
    
    return SubscriptionGateScreen(
      feature: 'Camera Jump Detection',
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Camera Jump Detection',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              )
            : CameraJumpView(
                jumpDetector: _jumpDetector,
                onJumpDetected: _onJumpDetected,
                currentCount: _currentCount,
                existingJumps: _existingJumps,
                newJumps: _newJumps,
                goal: widget.goal,
                isCompleted: _isCompleted,
                isLoading: _isLoading,
              ),
      ),
    );
  }

}
