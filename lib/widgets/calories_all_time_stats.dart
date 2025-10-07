import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/calories_service.dart';
import '../utils/calories_calculator.dart';

/// Widget that displays all-time calories statistics
class CaloriesAllTimeStats extends StatelessWidget {
  const CaloriesAllTimeStats({super.key});

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
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: const Color(0xFFFFD700).withOpacity(0.6),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'All-Time Statistics',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<Map<String, dynamic>>(
                future: caloriesService.getAllTimeCaloriesStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFFD700)),
                      ),
                    );
                  }

                  final stats = snapshot.data ?? {};
                  final totalCalories = (stats['totalCalories'] ?? 0.0) as double;
                  final weeklyCalories = (stats['weeklyCalories'] ?? 0.0) as double;
                  final averagePerDay = (stats['averagePerDay'] ?? 0.0) as double;
                  final bestDay = (stats['bestDay'] ?? 0.0) as double;
                  final caloriesStreak = (stats['caloriesStreak'] ?? 0) as int;

                  return Column(
                    children: [
                      // Main stats grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Total Calories',
                              CaloriesCalculator.formatCalories(totalCalories),
                              Icons.local_fire_department,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Current Streak',
                              '$caloriesStreak days',
                              Icons.local_fire_department,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Best Day',
                              CaloriesCalculator.formatCalories(bestDay),
                              Icons.emoji_events,
                              Colors.yellow,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Daily Average',
                              CaloriesCalculator.formatCalories(averagePerDay),
                              Icons.trending_up,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Weekly breakdown
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: const Color(0xFFFFD700).withOpacity(0.6),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'This Week',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFFFFD700).withOpacity(0.6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Calories burned:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  CaloriesCalculator.formatCalories(weeklyCalories),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Achievement badges
                      _buildAchievementBadges(context, stats),
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

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadges(BuildContext context, Map<String, dynamic> stats) {
    final theme = Theme.of(context);
    final totalCalories = (stats['totalCalories'] ?? 0.0) as double;
    final caloriesStreak = (stats['caloriesStreak'] ?? 0) as int;
    
    final achievements = <Map<String, dynamic>>[];
    
    // Define achievement thresholds
    if (totalCalories >= 1000) {
      achievements.add({
        'title': 'Calorie Master',
        'description': 'Burned 1,000+ calories',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'unlocked': true,
      });
    }
    
    if (caloriesStreak >= 7) {
      achievements.add({
        'title': 'Week Warrior',
        'description': '7-day calorie streak',
        'icon': Icons.calendar_today,
        'color': Colors.blue,
        'unlocked': true,
      });
    }
    
    if (totalCalories >= 5000) {
      achievements.add({
        'title': 'Calorie Legend',
        'description': 'Burned 5,000+ calories',
        'icon': Icons.emoji_events,
        'color': Colors.purple,
        'unlocked': true,
      });
    }
    
    if (caloriesStreak >= 30) {
      achievements.add({
        'title': 'Month Master',
        'description': '30-day calorie streak',
        'icon': Icons.star,
        'color': Colors.yellow,
        'unlocked': true,
      });
    }
    
    if (achievements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: const Color(0xFFFFD700).withOpacity(0.6),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Keep burning calories to unlock achievements!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFFFD700).withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: const Color(0xFFFFD700).withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Achievements',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFFFD700).withOpacity(0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achievements.map((achievement) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (achievement['color'] as Color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (achievement['color'] as Color).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      achievement['icon'] as IconData,
                      color: achievement['color'] as Color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      achievement['title'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: achievement['color'] as Color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
