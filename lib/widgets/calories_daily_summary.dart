import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/calories_service.dart';
import '../utils/calories_calculator.dart';
import '../screens/weight_settings_screen.dart';

/// Widget that displays today's calories burned with goal progress
class CaloriesDailySummary extends StatelessWidget {
  const CaloriesDailySummary({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caloriesService = Provider.of<CaloriesService>(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[900],
          border: Border.all(color: const Color(0xFFFFD700), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: const Color(0xFFFFD700),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Today\'s Calories',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Weight display
                  FutureBuilder<Map<String, dynamic>>(
                    future: caloriesService.getUserWeightWithUnit(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!['displayWeight'] != null) {
                        final weightData = snapshot.data!;
                        final displayWeight = weightData['displayWeight'] as double;
                        final unit = weightData['unit'] as String;
                        
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                              ),
                              child: Text(
                                'Weight: ${displayWeight.toStringAsFixed(1)} $unit',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFFFD700).withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const WeightSettingsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.settings,
                                  color: const Color(0xFFFFD700).withOpacity(0.6),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                              ),
                              child: Text(
                                'Weight not set',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFFFD700).withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const WeightSettingsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: const Color(0xFFFFD700).withOpacity(0.6),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              StreamBuilder<Map<String, dynamic>>(
                stream: caloriesService.getTodayCaloriesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFFD700)),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final calories = (data['calories'] ?? 0.0) as double;
                  final goal = (data['goal'] ?? 0.0) as double;
                  final percentage = (data['percentage'] ?? 0.0) as double;
                  final isCompleted = data['isCompleted'] as bool? ?? false;

                  return Column(
                    children: [
                      // Main calories display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                CaloriesCalculator.formatCalories(calories),
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
                                'calories burned',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFFFFD700).withOpacity(0.8),
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
                          if (goal > 0) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Goal: ${CaloriesCalculator.formatCalories(goal)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFFFFD700).withOpacity(0.8),
                                    shadows: [
                                      const Shadow(
                                        offset: Offset(1, 1),
                                        blurRadius: 2,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${percentage.round()}%',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? Colors.green.withOpacity(0.6) : const Color(0xFFFFD700).withOpacity(0.6),
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
                      const SizedBox(height: 16),
                      // Progress bar
                      if (goal > 0) ...[
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (percentage / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted ? Colors.green : const Color(0xFFFFD700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Goal completion status
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.withOpacity(0.6),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Goal Achieved!',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.green.withOpacity(0.6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (goal > 0)
                          Text(
                            '${CaloriesCalculator.formatCalories(goal - calories)} calories to go',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFFFD700).withOpacity(0.8),
                            ),
                          ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: const Color(0xFFFFD700).withOpacity(0.6),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Set a daily goal to track progress',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFFFD700).withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
