import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

/// Settings screen for configuring goal reminder notifications.
/// Users can enable/disable reminders, set intervals, and configure smart reminders.
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  bool _goalRemindersEnabled = true;
  int _reminderIntervalHours = 4;
  bool _smartRemindersEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final settings = await firestore.getReminderSettings();
      
      setState(() {
        _goalRemindersEnabled = settings['goalRemindersEnabled'] ?? true;
        _reminderIntervalHours = settings['reminderIntervalHours'] ?? 4;
        _smartRemindersEnabled = settings['smartRemindersEnabled'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reminder settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final notificationService = NotificationService();
      
      // Save settings to Firestore
      await firestore.updateReminderSettings(
        goalRemindersEnabled: _goalRemindersEnabled,
        reminderIntervalHours: _reminderIntervalHours,
        smartRemindersEnabled: _smartRemindersEnabled,
      );

      // Update notification service
      if (_goalRemindersEnabled) {
        final dailyGoal = await firestore.getDailyGoal();
        await notificationService.scheduleGoalReminders(
          userId: firestore.getCurrentUserId()?.hashCode ?? 0,
          dailyGoal: dailyGoal,
          enabled: true,
        );
      } else {
        await notificationService.scheduleGoalReminders(
          userId: firestore.getCurrentUserId()?.hashCode ?? 0,
          dailyGoal: 10,
          enabled: false,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder settings saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving reminder settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _testReminder() async {
    try {
      final notificationService = NotificationService();
      await notificationService.testAlarmSound();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test reminder sent!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error testing reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Reminder Settings'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Reminder Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Reminders Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: Color(0xFFFFD700),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Goal Reminders',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Enable Goal Reminders',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Get reminded to complete your daily jump goal',
                        style: TextStyle(color: Colors.grey),
                      ),
                      value: _goalRemindersEnabled,
                      onChanged: (value) {
                        setState(() {
                          _goalRemindersEnabled = value;
                        });
                      },
                      activeColor: const Color(0xFFFFD700),
                    ),
                    if (_goalRemindersEnabled) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Reminder Interval',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _reminderIntervalHours.toDouble(),
                        min: 1,
                        max: 12,
                        divisions: 11,
                        label: '$_reminderIntervalHours hours',
                        activeColor: const Color(0xFFFFD700),
                        onChanged: (value) {
                          setState(() {
                            _reminderIntervalHours = value.round();
                          });
                        },
                      ),
                      Text(
                        'You\'ll be reminded every $_reminderIntervalHours hours if you haven\'t completed your goal',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Smart Reminders Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology,
                          color: Color(0xFFFFD700),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Smart Reminders',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Enable Smart Reminders',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'AI-powered reminders based on your activity patterns',
                        style: TextStyle(color: Colors.grey),
                      ),
                      value: _smartRemindersEnabled,
                      onChanged: _goalRemindersEnabled ? (value) {
                        setState(() {
                          _smartRemindersEnabled = value;
                        });
                      } : null,
                      activeColor: const Color(0xFFFFD700),
                    ),
                    if (_smartRemindersEnabled && _goalRemindersEnabled)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          'Smart reminders will learn your jumping patterns and send notifications at optimal times.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.science,
                          color: Color(0xFFFFD700),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Test Reminders',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Test your reminder settings to make sure notifications work properly.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _testReminder,
                        icon: const Icon(Icons.notifications),
                        label: const Text('Test Reminder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
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
            
            const SizedBox(height: 20),
            
            // Information Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFFFD700),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'How It Works',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '• Reminders are sent every 4 hours if you haven\'t completed your daily goal\n'
                      '• Once you complete your goal, all remaining reminders are cancelled\n'
                      '• Smart reminders learn your activity patterns for better timing\n'
                      '• You can test reminders anytime to ensure they work properly',
                      style: TextStyle(
                        color: Colors.grey,
                        height: 1.5,
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
}

