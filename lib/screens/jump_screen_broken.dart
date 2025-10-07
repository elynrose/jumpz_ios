import 'dart:async';
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
/// completed, the result is recorded in Firestore and a completion message is
/// shown with a button to return to the previous screen.
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

  @override
  void dispose() {
    _subscription?.cancel();
    _jumpDetector.dispose();
    super.dispose();
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
      
    } catch (e) {
      print('Error playing goal completion feedback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final theme = Theme.of(context);
    final progress = _currentCount / widget.goal;
    
    return Scaffold(
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
                                ),
                              ),
                              // Progress circle
                              SizedBox(
                                width: 200,
                                height: 200,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
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
                                      fontSize: 48,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(1, 1),
                                          blurRadius: 3,
                                          color: Colors.black.withValues(alpha: 0.8),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'of ${widget.goal}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(1, 1),
                                          blurRadius: 3,
                                          color: Colors.black.withValues(alpha: 0.8),
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
                              Shadow(
                                offset: const Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black.withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Jump breakdown
                        if (_existingJumps > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
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
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withValues(alpha: 0.8),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                                              Shadow(
                                                offset: const Offset(1, 1),
                                                blurRadius: 3,
                                                color: Colors.black.withValues(alpha: 0.8),
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
                                  // Normal breakdown when goal not reached
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
                                                Shadow(
                                                  offset: const Offset(1, 1),
                                                  blurRadius: 3,
                                                  color: Colors.black.withValues(alpha: 0.8),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            'Previous',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_newJumps > 0) ...[
                                        Text(
                                          '+',
                                          style: theme.textTheme.headlineMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              '$_newJumps',
                                              style: theme.textTheme.headlineMedium?.copyWith(
                                                color: Colors.green[300],
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    offset: const Offset(1, 1),
                                                    blurRadius: 3,
                                                    color: Colors.black.withValues(alpha: 0.8),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              'New',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.white.withValues(alpha: 0.8),
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
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withValues(alpha: 0.8),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
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
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print('❌ Error saving jump session: $e');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('❌ Error saving session: $e'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.red,
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
                            const SizedBox(width: 12),
                            // Pause Session button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.pause),
                                label: const Text('Pause'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(color: Colors.white, width: 2),
                                  foregroundColor: Colors.white,
                                ),
                              ),
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