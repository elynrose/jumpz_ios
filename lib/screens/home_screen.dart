import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/native_alarm_service.dart';
import '../services/jump_counter_service.dart';
import '../screens/jump_screen.dart';
import '../screens/leaderboard_tab.dart';
import '../screens/settings_screen.dart';

/// The main screen displayed after a user signs in. Users can schedule their
/// daily alarm and jump goal, view their progress on a graph, see a preview of
/// the leaderboard and sign out. When the scheduled alarm fires, tapping the
/// notification navigates to the [JumpScreen] where the user completes their
/// jumps.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TimeOfDay? _selectedTime;
  final TextEditingController _goalController = TextEditingController(text: '10');
  StreamSubscription<String?>? _notificationSubscription;
  int _currentDailyGoal = 10;
  bool _hasScheduledAlarm = false;
  Map<String, dynamic> _userSettings = {};

  @override
  void initState() {
    super.initState();
    _loadDailyGoal();
    _loadUserSettings();
    _loadSavedAlarmTime();
    _checkScheduledAlarm();
    // Listen for taps on scheduled notifications and navigate to the jump screen.
    _notificationSubscription = NotificationService().onNotificationClick.listen((payload) {
      // When the notification is tapped, push the JumpScreen and pass the goal
      // from the payload (if provided).
      final goal = int.tryParse(payload ?? '') ?? int.tryParse(_goalController.text) ?? 10;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JumpScreen(goal: goal),
        ),
      );
    });
  }
  
  Future<void> _checkScheduledAlarm() async {
    final notificationService = NotificationService();
    final pendingNotifications = await notificationService.getPendingNotifications();
    
    if (mounted) {
      setState(() {
        _hasScheduledAlarm = pendingNotifications.isNotEmpty;
      });
    }
  }

  Future<void> _loadDailyGoal() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final goal = await firestore.getDailyGoal();
    setState(() {
      _currentDailyGoal = goal;
      _goalController.text = goal.toString();
    });
  }
  
  Future<void> _loadUserSettings() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final settings = await firestore.getUserSettings();
    setState(() {
      _userSettings = settings;
    });
  }

  Future<void> _loadSavedAlarmTime() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final savedAlarmTime = await firestore.getAlarmTime();
    if (mounted) {
      setState(() {
        _selectedTime = savedAlarmTime;
      });
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final theme = Theme.of(context);
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
              IconButton(
                onPressed: () async {
                  await authService.signOut();
                },
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Welcome, ${authService.currentUser?.displayName ?? authService.currentUser?.email ?? 'user'}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                child: const Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildDailyProgressCard(context, firestoreService),
                const SizedBox(height: 24),
                _buildAlarmCard(context),
                const SizedBox(height: 24),
                _buildProgressSection(context, firestoreService),
                const SizedBox(height: 24),
                _buildLeaderboardSection(context, firestoreService),
              ]),
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
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading progress',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        final progress = snapshot.data!;
        final jumps = progress['jumps'] as int;
        final goal = progress['goal'] as int;
        final percentage = progress['percentage'] as double;
        final isCompleted = progress['isCompleted'] as bool;
        
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$jumps / $goal',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'jumps completed',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: percentage / 100,
                                strokeWidth: 6,
                                backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${percentage.toInt()}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JumpScreen(goal: goal),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: Text(isCompleted ? 'Jump More!' : 'Start Jumping!'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.onPrimary,
                        foregroundColor: isCompleted 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
        );
      },
    );
  }

  Widget _buildAlarmCard(BuildContext context) {
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
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final now = TimeOfDay.now();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? now,
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedTime = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _selectedTime != null
                            ? 'Alarm: ${_selectedTime!.format(context)}'
                            : 'Choose alarm time',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _goalController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Goal',
                        hintText: 'Jumps',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedTime == null
                      ? null
                      : () async {
                          final goal = int.tryParse(_goalController.text) ?? 10;
                          final firestore = Provider.of<FirestoreService>(context, listen: false);
                          
                          // Show loading indicator
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Saving goal and scheduling alarm...'),
                                  ],
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          
                          try {
                            // Save the daily goal to Firestore
                            await firestore.setDailyGoal(goal);
                            
                            // Save the alarm time to Firestore
                            await firestore.saveAlarmTime(_selectedTime!);
                            
                            // Cancel only our app's existing alarms (not user's personal alarms)
                            try {
                              await NativeAlarmService.cancelAppAlarms();
                              await NotificationService().cancel(0); // Cancel our notification alarm
                              print('🧹 Cancelled existing Jumpz alarms');
                            } catch (e) {
                              print('⚠️ Error cancelling existing Jumpz alarms: $e');
                            }
                            
                            // Schedule the alarm using NativeAlarmService for better reliability
                            try {
                              await NativeAlarmService.setAlarm(
                                hour: _selectedTime!.hour,
                                minute: _selectedTime!.minute,
                                title: '🏃‍♂️ Time to Jump!',
                                message: 'Wake up and complete $goal jumps to reach your daily goal!',
                              );
                              print('✅ Native alarm set for ${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}');
                              
                              // Show success message
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎯 Daily goal set to $goal jumps and alarm scheduled for ${_selectedTime!.format(context)}!'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (e) {
                              print('❌ Native alarm failed: $e');
                              
                              // Show error message
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Failed to set alarm: $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                            
                            setState(() {
                              _currentDailyGoal = goal;
                            });
                            
                            // Refresh alarm status and reload saved alarm time
                            await _checkScheduledAlarm();
                            await _loadSavedAlarmTime();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  icon: Icon(_hasScheduledAlarm ? Icons.alarm_on : Icons.schedule),
                  label: Text(_hasScheduledAlarm ? 'Alarm Scheduled' : 'Schedule Daily Alarm'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_hasScheduledAlarm) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final firestore = Provider.of<FirestoreService>(context, listen: false);
                      await NotificationService().cancel(0);
                      await firestore.disableAlarm();
                      await _checkScheduledAlarm();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alarm cancelled'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await NotificationService().testAlarmSound(
                        customSound: _userSettings['alarmSound'] as String?,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔊 Testing alarm sound...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Test Alarm Sound'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context, FirestoreService firestoreService) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up,
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(width: 8),
            Text(
              'Your Progress',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildJumpChart(firestoreService),
      ],
    );
  }

  Widget _buildLeaderboardSection(BuildContext context, FirestoreService firestoreService) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.leaderboard,
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(width: 8),
            Text(
              'Leaderboard',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLeaderboardPreview(firestoreService),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardTab()),
              );
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('View Full Leaderboard'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a line chart displaying the user's jump history. Uses the
  /// [FirestoreService.jumpHistoryStream] to retrieve session data and plots
  /// counts over time using the [fl_chart] library. If there is no data a
  /// placeholder is shown instead of the chart.
  Widget _buildJumpChart(FirestoreService firestore) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestore.jumpHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading chart',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No jump data yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete your first jump session to see your progress!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data!;
        // Sort by timestamp to ensure chronological order.
        data.sort((a, b) => (a['timestamp'] as DateTime)
            .compareTo(b['timestamp'] as DateTime));
        final spots = <FlSpot>[];
        for (var i = 0; i < data.length; i++) {
          final entry = data[i];
          final timestamp = entry['timestamp'] as DateTime;
          final count = entry['count'] as int;
          // Use the index as the X axis value to simplify; for a real app
          // consider converting the timestamp into a double representation like
          // days since epoch. The Y axis is the jump count.
          spots.add(FlSpot(i.toDouble(), count.toDouble()));
        }
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      final date = data[index]['timestamp'] as DateTime;
                      return Text(
                        DateFormat('MM/dd').format(date), 
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 4,
                  color: const Color(0xFFFFD700),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFFFFD700),
                        strokeWidth: 2,
                        strokeColor: theme.colorScheme.surface,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds a simple preview of the leaderboard showing the top 5 users. Uses a
  /// [StreamBuilder] to listen to realtime updates from Firestore. Each item
  /// displays the user's name and total jump count. When there is no data a
  /// placeholder message is shown.
  Widget _buildLeaderboardPreview(FirestoreService firestore) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestore.leaderboardStream(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading leaderboard',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        final users = snapshot.data!;
        if (users.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.leaderboard,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No leaderboard data yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete your first jump session!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
            itemBuilder: (context, index) {
              final user = users[index];
              final isTopThree = index < 3;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isTopThree 
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isTopThree 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user['displayName'] as String,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isTopThree ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${user['totalJumps']}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}