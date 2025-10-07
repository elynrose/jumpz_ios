import 'package:flutter/material.dart';
import 'settings_screen.dart';

/// A tab wrapper for the settings screen.
///
/// This widget provides a consistent interface for the settings screen
/// when used as a tab in the main navigation.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}

