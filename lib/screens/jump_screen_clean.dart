import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/jump_counter_service.dart';
import '../services/enhanced_jump_detector.dart';
import 'camera_jump_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/animated_background.dart';

/// Screen that counts jumps using the device's accelerometer. The user must
/// complete a specified [goal] number of jumps to finish the session. Once
/// the goal is reached, the session is automatically completed.
class JumpScreen extends StatefulWidget {
  final int goal;

  const JumpScreen({super.key, required this.goal});

  @override
  State<JumpScreen> createState() => _JumpScreenState();
}

class _JumpScreenState extends State<JumpScreen> {
  late EnhancedJumpDetector _jumpDetector;
  StreamSubscription<int>? _subscription;
  int _currentCount = 0;
  int _existingJumps = 0; // Jumps already done today
  int _newJumps = 0; // New jumps in this session
  bool _isCompleted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayProgress();
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
      
      _startJumpCounter();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _startJumpCounter();
    }
  }

  void _startJumpCounter() {
    _jumpDetector = EnhancedJumpDetector();
    _jumpDetector.start();
    _subscription = _jumpDetector.countStream.listen((newJumps) {
      setState(() {
        _newJumps = newJumps;
        _currentCount = _existingJumps + newJumps;
        if (_currentCount >= widget.goal) {
          _isCompleted = true;
          _jumpDetector.stop();
          _playGoalCompletionFeedback();
        }
      });
    });
  }

  /// Plays vibration and sound feedback when goal is completed
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
  
  /// Completes the session and saves progress
  Future<void> _completeSession() async {
    try {
      print('🔄 Starting to save jump session: $_newJumps new jumps (total: $_currentCount)');
      
      // Only record the new jumps from this session
      if (_newJumps > 0) {
        final firestore = Provider.of<FirestoreService>(context, listen: false);
        await firestore.recordJumpSession(_newJumps);
        print('✅ Jump session recorded: $_newJumps jumps');
        
        await firestore.recordDailyProgress(_newJumps);
        print('✅ Daily progress updated: +$_newJumps jumps');
        
        await firestore.updateGoalStreak();
        print('✅ Goal streak updated');
      }
      
      if (mounted) {
        Navigator.pop(context, _currentCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session completed! $_newJumps jumps saved.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving session: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _jumpDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.goal > 0 ? _currentCount / widget.goal : 0.0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background
          AnimatedBackground(
            type: BackgroundType.gif,
            source: _isCompleted 
              ? 'assets/images/Claps.gif' // Celebration GIF when goal reached
              : 'assets/images/jumpz.gif', // Regular jumping GIF
            overlayColor: null, // No overlay
            overlayOpacity: 0.0,
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: _isLoading 
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Progress Circle
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
                                      value: progress.clamp(0.0, 1.0),
                                      strokeWidth: 8,
                                      backgroundColor: Colors.transparent,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _isCompleted ? Colors.green : const Color(0xFFFFD700),
                                      ),
                                    ),
                                  ),
                                  // Count display
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$_currentCount',
                                        style: theme.textTheme.displayLarge?.copyWith(
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
                                        style: theme.textTheme.titleMedium?.copyWith(
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
                              _isCompleted 
                                  ? '🎉 Congratulations! Goal reached!' 
                                  : 'Keep jumping to reach your goal!',
                              style: theme.textTheme.headlineSmall?.copyWith(
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
                            // Progress details
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _isCompleted ? '🎉 Goal Achieved!' : 'Today\'s Progress',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: _isCompleted ? Colors.green[300] : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        const Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_isCompleted)
                                    // Single expanded box when goal is reached
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '$_currentCount',
                                            style: theme.textTheme.displayLarge?.copyWith(
                                              color: Colors.green[300],
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                const Shadow(
                                                  offset: Offset(1, 1),
                                                  blurRadius: 3,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'Total Jumps Completed',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              color: Colors.green[200],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    // Side by side when goal not reached
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Column(
                                          children: [
                                            Text(
                                              '$_existingJumps',
                                              style: theme.textTheme.headlineMedium?.copyWith(
                                                color: Colors.blue[300],
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  const Shadow(
                                                    offset: Offset(1, 1),
                                                    blurRadius: 3,
                                                    color: Colors.black,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              'Existing',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: Colors.blue[200],
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
                                        if (_newJumps > 0) ...[
                                          Column(
                                            children: [
                                              Text(
                                                '$_newJumps',
                                                style: theme.textTheme.headlineMedium?.copyWith(
                                                  color: Colors.green[300],
                                                  fontWeight: FontWeight.bold,
                                                  shadows: [
                                                    const Shadow(
                                                      offset: Offset(1, 1),
                                                      blurRadius: 3,
                                                      color: Colors.black,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                'New',
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: Colors.green[200],
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
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Jump animation indicator
                            if (!_isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.fitness_center,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Jump to count!',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
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
                              ),
                            const SizedBox(height: 40),
                            // Action buttons
                            Column(
                              children: [
                                // Detection method buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CameraJumpScreen(goal: widget.goal),
                                            ),
                                          ).then((result) {
                                            if (result != null) {
                                              Navigator.pop(context, result);
                                            }
                                          });
                                        },
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text('Camera Detection'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Sensor detection is already active'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.sensors),
                                        label: const Text('Sensor Detection'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFFD700),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Complete Session button (always available)
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () async {
                                          try {
                                            print('🔄 Starting to save jump session: $_newJumps new jumps (total: $_currentCount)');
                                            
                                            // Only record the new jumps from this session
                                            if (_newJumps > 0) {
                                              final firestore = Provider.of<FirestoreService>(context, listen: false);
                                              await firestore.recordJumpSession(_newJumps);
                                              print('✅ Jump session recorded: $_newJumps jumps');
                                              
                                              await firestore.recordDailyProgress(_newJumps);
                                              print('✅ Daily progress updated: +$_newJumps jumps');
                                              
                                              await firestore.updateGoalStreak();
                                              print('✅ Goal streak updated');
                                            }
                                            
                                            if (context.mounted) {
                                              Navigator.of(context).pop(true); // Return true to indicate session was completed
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(_isCompleted 
                                                    ? 'Jump session completed! Goal reached! 🎉' 
                                                    : _newJumps > 0 
                                                      ? 'Jump session saved! +$_newJumps jumps (Total: $_currentCount)'
                                                      : 'No new jumps to save'),
                                                  behavior: SnackBarBehavior.floating,
                                                  backgroundColor: _isCompleted ? Colors.green : Colors.blue,
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            print('❌ Error saving jump session: $e');
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error saving session: $e'),
                                                  backgroundColor: Colors.red,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.check),
                                        label: const Text('Complete Session'),
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
                              ],
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
    );
  }
}


