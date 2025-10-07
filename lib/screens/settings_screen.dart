import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/jump_detection_settings_service.dart';
// import '../services/subscription_service.dart';
import '../services/mock_subscription_service.dart';
import 'reminder_settings_screen.dart';
import 'subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vibrationEnabled = true;
  int _vibrationIntensity = 3; // 1-5 scale

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load saved settings from Firestore
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    try {
      final settings = await firestore.getUserSettings();
      if (settings != null) {
        setState(() {
          _vibrationEnabled = settings['vibrationEnabled'] ?? true;
          _vibrationIntensity = settings['vibrationIntensity'] ?? 3;
        });
      }
    } catch (e) {
      // Use default values if loading fails
      setState(() {
        _vibrationEnabled = true;
        _vibrationIntensity = 3;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Save settings to Firestore
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      await firestore.updateUserSettings({
        'vibrationEnabled': _vibrationEnabled,
        'vibrationIntensity': _vibrationIntensity,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        await auth.signOut();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFFFD700)),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color(0xFF1a1a1a),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alarm Settings Section
                    _buildSectionCard(
                      context,
                      title: 'Alarm Settings',
                      icon: Icons.alarm,
                      children: [
                        _buildSwitchTile(
                          title: 'Vibration',
                          subtitle: 'Enable vibration for alarms',
                          value: _vibrationEnabled,
                          onChanged: (value) => setState(() => _vibrationEnabled = value),
                          icon: Icons.vibration,
                        ),
                        if (_vibrationEnabled) ...[
                          const SizedBox(height: 16),
                          _buildVibrationIntensitySlider(),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Jump Detection Settings Section
                    _buildSectionCard(
                      context,
                      title: 'Jump Detection',
                      icon: Icons.sports_gymnastics,
                      children: [
                        _buildJumpSensitivitySlider(),
                        const SizedBox(height: 16),
                        _buildJumpDetectionModeSelector(),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Reminder Settings Section
                    _buildSectionCard(
                      context,
                      title: 'Goal Reminders',
                      icon: Icons.notifications_active,
                      children: [
                        _buildInfoTile(
                          title: 'Reminder Settings',
                          subtitle: 'Configure goal reminder notifications',
                          icon: Icons.settings,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ReminderSettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // App Information Section
                    _buildSectionCard(
                      context,
                      title: 'App Information',
                      icon: Icons.info,
                      children: [
                        _buildInfoTile(
                          title: 'Version',
                          subtitle: '1.0.0',
                          icon: Icons.tag,
                        ),
                        const Divider(color: Colors.grey),
                        _buildInfoTile(
                          title: 'Developer',
                          subtitle: 'Jumpz Team',
                          icon: Icons.person,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Subscription Section
                    _buildSubscriptionSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Account Section
                    _buildSectionCard(
                      context,
                      title: 'Account',
                      icon: Icons.account_circle,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFD700), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFFFD700),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }


  Widget _buildVibrationIntensitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Vibration Intensity',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            Text(
              '$_vibrationIntensity/5',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _vibrationIntensity.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: const Color(0xFFFFD700),
          inactiveColor: Colors.grey[600],
          onChanged: (value) {
            setState(() => _vibrationIntensity = value.round());
          },
        ),
      ],
    );
  }

  Widget _buildJumpSensitivitySlider() {
    return Consumer<JumpDetectionSettingsService>(
      builder: (context, settingsService, child) {
        final sensitivityLabels = ['Very Sensitive', 'Sensitive', 'Normal', 'Less Sensitive', 'Least Sensitive'];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jump Sensitivity',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${settingsService.jumpSensitivity}/5',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sensitivityLabels[settingsService.jumpSensitivity - 1],
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: settingsService.jumpSensitivity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: const Color(0xFFFFD700),
              inactiveColor: Colors.grey[600],
              onChanged: (value) {
                settingsService.updateSettings(jumpSensitivity: value.round());
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildJumpDetectionModeSelector() {
    return Consumer<JumpDetectionSettingsService>(
      builder: (context, settingsService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detection Mode',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton('Simple', 'simple', Icons.speed, settingsService),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton('Enhanced', 'enhanced', Icons.analytics, settingsService),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton('Hybrid', 'hybrid', Icons.auto_awesome, settingsService),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeButton(String label, String value, IconData icon, JumpDetectionSettingsService settingsService) {
    final isSelected = settingsService.jumpDetectionMode == value;
    
    return GestureDetector(
      onTap: () => settingsService.updateSettings(jumpDetectionMode: value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700).withOpacity(0.2) : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFFD700) : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFFFD700) : Colors.grey[400],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: const Color(0xFFFFD700),
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFFFD700),
        activeTrackColor: const Color(0xFFFFD700).withOpacity(0.3),
        inactiveThumbColor: Colors.grey[400],
        inactiveTrackColor: Colors.grey[600],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: const Color(0xFFFFD700),
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
      trailing: onTap != null
          ? const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            )
          : null,
      onTap: onTap,
    );
  }
  
  Widget _buildSubscriptionSection() {
    return Consumer<MockSubscriptionService>(
      builder: (context, subscriptionService, child) {
        return _buildSectionCard(
          context,
          title: 'Subscription',
          icon: Icons.star,
          children: [
            _buildInfoTile(
              title: 'Premium Status',
              subtitle: subscriptionService.getSubscriptionStatusText(),
              icon: subscriptionService.isSubscribed 
                  ? Icons.check_circle 
                  : subscriptionService.isTrialActive 
                      ? Icons.schedule 
                      : Icons.lock,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
            ),
            if (subscriptionService.isTrialActive) ...[
              const Divider(color: Colors.grey),
              _buildInfoTile(
                title: 'Trial Days Remaining',
                subtitle: '${subscriptionService.getTrialDaysRemaining()} days left',
                icon: Icons.timer,
              ),
            ],
            const Divider(color: Colors.grey),
            _buildInfoTile(
              title: 'Manage Subscription',
              subtitle: subscriptionService.isSubscribed 
                  ? 'View subscription details' 
                  : 'Upgrade to Premium',
              icon: Icons.settings,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}