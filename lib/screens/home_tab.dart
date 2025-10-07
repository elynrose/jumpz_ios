import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/native_alarm_service.dart';
import '../services/notification_service.dart';
import 'jump_screen.dart';
import 'dart:async';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic> _userSettings = {};
  bool _hasScheduledAlarm = false;
  bool _isAlarmActive = false;
  Timer? _alarmCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _checkScheduledAlarm();
    _startAlarmDetection();
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    super.dispose();
  }

  void _startAlarmDetection() {
    // Check for active alarm every 2 seconds
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkForActiveAlarm();
    });
  }

  Future<void> _checkForActiveAlarm() async {
    try {
      // This would check if the alarm is currently sounding
      // For now, we'll simulate this - in a real implementation,
      // you'd check the native alarm status
      final isActive = await NativeAlarmService.isAlarmActive();
      if (mounted && isActive != _isAlarmActive) {
        setState(() {
          _isAlarmActive = isActive;
        });
      }
    } catch (e) {
      print('Error checking alarm status: $e');
    }
  }

  Future<void> _stopAlarm() async {
    try {
      await NativeAlarmService.dismissAlarm();
      setState(() {
        _isAlarmActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔕 Alarm stopped'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error stopping alarm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping alarm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUserSettings() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final settings = await firestoreService.getUserSettings();
    setState(() {
      _userSettings = settings;
    });
  }

  Future<void> _checkScheduledAlarm() async {
    // For now, we'll assume alarm is scheduled if user has a daily goal
    // In a real implementation, you'd check the actual alarm status
    setState(() {
      _hasScheduledAlarm = _userSettings?['dailyGoal'] != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadUserSettings();
              await _checkScheduledAlarm();
            },
            child: CustomScrollView(
              slivers: [
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome, ${authService.currentUser?.displayName ?? authService.currentUser?.email ?? 'user'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    shadows: [
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black,
                      Color(0xFF1a1a1a),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background image
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Image.asset(
                            'assets/images/jumpz_header.png',
                            fit: BoxFit.contain,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if image not found
                              return Container(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.black,
                                      Color(0xFF1a1a1a),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.fitness_center,
                                    size: 80,
                                    color: Colors.white70,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // Dark overlay for text readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildDailyProgressCard(context, firestoreService),
                const SizedBox(height: 16),
                _buildAlarmCard(context, firestoreService),
                const SizedBox(height: 16),
                _buildQuickActionsCard(context),
              ]),
            ),
          ),
        ],
      ),
            ),
          // Alarm Stop Modal
        if (_isAlarmActive)
          Container(
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFFFD700), width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.alarm,
                        size: 64,
                        color: Color(0xFFFFD700),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '🔔 Jumpz Alarm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Time to complete your daily goal!',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _stopAlarm,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Alarm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressCard(BuildContext context, FirestoreService firestoreService) {
    final theme = Theme.of(context);
    
    return StreamBuilder<Map<String, dynamic>>(
      stream: firestoreService.getTodayProgressStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey[900]!, Colors.grey[800]!],
                ),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey[900]!, Colors.grey[800]!],
                ),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'Error loading progress',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        }

        final progress = snapshot.data ?? {};
        final currentJumps = progress['jumps'] as int? ?? 0; // Fixed: was 'currentJumps'
        final goal = progress['goal'] as int? ?? 10;
        final isCompleted = progress['isCompleted'] as bool? ?? false;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCompleted 
                    ? [const Color(0xFFFFD700), const Color(0xFFB8860B)]
                    : [Colors.grey[900]!, Colors.grey[800]!],
              ),
              border: Border.all(color: const Color(0xFFFFD700), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.emoji_events : Icons.today,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Today\'s Goal',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'COMPLETED!',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Today's progress display
                  if (isCompleted)
                    // Show only completed box when goal is reached
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Goal Reached',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$currentJumps jumps completed',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    // Show side by side when goal not reached
                    Row(
                      children: [
                        // Jumps done today
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Completed',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$currentJumps',
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Jumps left to reach goal
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Remaining',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.orange[100],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(goal - currentJumps).clamp(0, goal)}',
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[100],
                                    fontSize: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Progress bar
                  LinearProgressIndicator(
                    value: goal > 0 ? (currentJumps / goal).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.black : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${((currentJumps / goal) * 100).clamp(0, 100).toInt()}% complete',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlarmCard(BuildContext context, FirestoreService firestoreService) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.grey[800]!,
            ],
          ),
          border: Border.all(color: const Color(0xFFFFD700), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.alarm,
                    color: const Color(0xFFFFD700),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Daily Jump Goal',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_hasScheduledAlarm) ...[
                Text(
                  'Set your daily goal and schedule an alarm to stay motivated!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await _showGoalDialog(context, firestoreService);
                      if (result == true) {
                        await _checkScheduledAlarm();
                      }
                    },
                    icon: const Icon(Icons.add_alarm),
                    label: const Text('Set Daily Goal'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Alarm scheduled! You\'ll be reminded to complete your daily goal.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await NativeAlarmService.cancelAlarm();
                        await _checkScheduledAlarm();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔕 Alarm cancelled'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Error cancelling alarm: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Alarm'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await NativeAlarmService.testAlarm1Minute();
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🔊 1-minute test alarm set!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Error: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.volume_up),
                        label: const Text('1-Min Test'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final diagnostic = await NativeAlarmService.runAlarmDiagnostic();
                            
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[900],
                                  title: const Text(
                                    '🔍 Alarm Diagnostic',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Status: ${diagnostic['status'] ?? 'Unknown'}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Active: ${diagnostic['isActive'] ?? 'Unknown'}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Time: ${DateTime.now().toString()}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      if (diagnostic['error'] != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Error: ${diagnostic['error']}',
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Diagnostic failed: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Diagnostic'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.grey[800]!,
            ],
          ),
          border: Border.all(color: const Color(0xFFFFD700), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.play_arrow,
                    color: const Color(0xFFFFD700),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<Map<String, dynamic>>(
                stream: Provider.of<FirestoreService>(context, listen: false).getTodayProgressStream(),
                builder: (context, snapshot) {
                  final progress = snapshot.data ?? {};
                  final currentJumps = progress['jumps'] as int? ?? 0;
                  final goal = progress['goal'] as int? ?? 10;
                  final isCompleted = progress['isCompleted'] as bool? ?? false;
                  
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Check if user has already met their goal
                        if (isCompleted) {
                          // Show dialog to set new goal
                          final shouldSetNewGoal = await _showIncreaseGoalDialog(context, Provider.of<FirestoreService>(context, listen: false), goal);
                          if (shouldSetNewGoal == true) {
                            // Goal was updated, refresh data
                            await _loadUserSettings();
                            await _checkScheduledAlarm();
                          }
                          return;
                        }
                        
                        // Get the current goal from user settings
                        final firestore = Provider.of<FirestoreService>(context, listen: false);
                        final currentGoal = await firestore.getDailyGoal();
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JumpScreen(goal: currentGoal),
                          ),
                        );
                        // Refresh data if session was completed
                        if (result == true) {
                          await _loadUserSettings();
                          await _checkScheduledAlarm();
                        }
                      },
                      icon: Icon(isCompleted ? Icons.trending_up : Icons.fitness_center),
                      label: Text(isCompleted ? 'Set Goal' : 'Start Jumping'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: isCompleted ? Colors.orange : null,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showIncreaseGoalDialog(BuildContext context, FirestoreService firestoreService, int currentGoal) async {
    // Load saved alarm time from database
    final savedAlarmTime = await firestoreService.getAlarmTime();
    final defaultTime = savedAlarmTime ?? const TimeOfDay(hour: 8, minute: 0);
    
    final goalController = TextEditingController(text: currentGoal.toString());
    final timeController = TextEditingController(text: defaultTime.format(context));
    TimeOfDay selectedTime = defaultTime;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Increase Daily Goal',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve already completed your goal of $currentGoal jumps! 🎉\n\nSet your new daily goal:',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Daily Goal (jumps)',
                labelStyle: const TextStyle(color: Colors.white),
                hintText: 'Must be in increments of 10 (e.g., 10, 20, 30...)',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                helperText: 'Current goal: $currentGoal jumps',
                helperStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text(
                'Alarm Time',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                selectedTime.format(context),
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: const Icon(Icons.access_time, color: Color(0xFFFFD700)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (time != null) {
                  setState(() {
                    selectedTime = time;
                    timeController.text = time.format(context);
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final goal = int.tryParse(goalController.text) ?? 0;
              
              // Validate goal
              if (goal <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('❌ Goal must be greater than 0'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              
              if (goal % 10 != 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Goal must be in increments of 10 (e.g., 10, 20, 30...)'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              
              await firestoreService.setDailyGoal(goal);
              
              // Schedule native alarm
              try {
                await NativeAlarmService.setAlarm(
                  hour: selectedTime.hour,
                  minute: selectedTime.minute,
                  title: '🏃‍♂️ Time to Jump!',
                  message: 'Complete your daily goal of $goal jumps!',
                );
                
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎯 Daily goal set to $goal jumps and alarm scheduled!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Failed to schedule alarm: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Set Goal'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showGoalDialog(BuildContext context, FirestoreService firestoreService) async {
    // Get current goal
    final currentGoal = await firestoreService.getDailyGoal();
    
    // Load saved alarm time from database
    final savedAlarmTime = await firestoreService.getAlarmTime();
    final defaultTime = savedAlarmTime ?? const TimeOfDay(hour: 8, minute: 0);
    
    final goalController = TextEditingController(text: currentGoal.toString());
    final timeController = TextEditingController(text: defaultTime.format(context));
    TimeOfDay selectedTime = defaultTime;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Set Daily Goal',
            style: TextStyle(color: Colors.white),
          ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Daily Goal (jumps)',
                labelStyle: const TextStyle(color: Colors.white),
                hintText: 'Must be in increments of 10 (e.g., 10, 20, 30...)',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                helperText: 'Current goal: $currentGoal jumps',
                helperStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text(
                'Alarm Time',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                selectedTime.format(context),
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: const Icon(Icons.access_time, color: Color(0xFFFFD700)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (time != null) {
                  setState(() {
                    selectedTime = time;
                    timeController.text = time.format(context);
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final goal = int.tryParse(goalController.text) ?? 0;
              
              // Validate goal
              if (goal <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('❌ Goal must be greater than 0'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              
              if (goal % 10 != 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Goal must be in increments of 10 (e.g., 10, 20, 30...)'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              
              await firestoreService.setDailyGoal(goal);
              
              // Save the alarm time to Firestore
              await firestoreService.saveAlarmTime(selectedTime);
              
              // Cancel only our app's existing alarms (not user's personal alarms)
              try {
                await NativeAlarmService.cancelAppAlarms();
                await NotificationService().cancel(0); // Cancel our notification alarm
                print('🧹 Cancelled existing Jumpz alarms');
              } catch (e) {
                print('⚠️ Error cancelling existing Jumpz alarms: $e');
              }
              
              // Schedule native alarm
              try {
                await NativeAlarmService.setAlarm(
                  hour: selectedTime.hour,
                  minute: selectedTime.minute,
                  title: '🏃‍♂️ Time to Jump!',
                  message: 'Complete your daily goal of $goal jumps!',
                );
                
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎯 Daily goal set to $goal jumps and alarm scheduled!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Failed to schedule alarm: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Set Goal'),
          ),
        ],
      ),
    ),
    );
  }
}
