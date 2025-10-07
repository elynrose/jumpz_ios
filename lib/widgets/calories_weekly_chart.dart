import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/calories_service.dart';
import '../utils/calories_calculator.dart';

/// Widget that displays a weekly calories chart
class CaloriesWeeklyChart extends StatelessWidget {
  const CaloriesWeeklyChart({super.key});

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
                    Icons.trending_up,
                    color: const Color(0xFFFFD700),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Weekly Calories',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: caloriesService.getWeeklyCalories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFFD700)),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No data available',
                          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  final weeklyData = snapshot.data!;
                  final maxCalories = weeklyData.isNotEmpty 
                      ? weeklyData.map((day) => day['calories'] as double).reduce((a, b) => a > b ? a : b)
                      : 100.0;
                  final chartMaxY = (maxCalories * 1.2).ceil().toDouble();

                  return Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: chartMaxY > 50 ? chartMaxY / 5 : 10,
                              verticalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey[600]!,
                                  strokeWidth: 1,
                                );
                              },
                              getDrawingVerticalLine: (value) {
                                return FlLine(
                                  color: Colors.grey[600]!,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    const style = TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    );
                                    Widget text;
                                    switch (value.toInt()) {
                                      case 0:
                                        text = const Text('Mon', style: style);
                                        break;
                                      case 1:
                                        text = const Text('Tue', style: style);
                                        break;
                                      case 2:
                                        text = const Text('Wed', style: style);
                                        break;
                                      case 3:
                                        text = const Text('Thu', style: style);
                                        break;
                                      case 4:
                                        text = const Text('Fri', style: style);
                                        break;
                                      case 5:
                                        text = const Text('Sat', style: style);
                                        break;
                                      case 6:
                                        text = const Text('Sun', style: style);
                                        break;
                                      default:
                                        text = const Text('', style: style);
                                        break;
                                    }
                                    return text;
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: chartMaxY > 50 ? chartMaxY / 5 : 10,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Colors.grey[600]!, width: 1),
                            ),
                            minX: 0,
                            maxX: 6,
                            minY: 0,
                            maxY: chartMaxY,
                            lineBarsData: [
                              LineChartBarData(
                                spots: weeklyData.map((day) {
                                  final dayOfWeek = day['dayOfWeek'] as int;
                                  final calories = day['calories'] as double;
                                  return FlSpot(dayOfWeek.toDouble(), calories);
                                }).toList(),
                                isCurved: true,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFF673AB7),
                                  ],
                                ),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: const Color(0xFF9C27B0),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF9C27B0).withOpacity(0.3),
                                      const Color(0xFF9C27B0).withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Weekly summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildWeeklyStat(
                            context,
                            'Total',
                            weeklyData.fold<double>(0, (sum, day) => sum + (day['calories'] as double)),
                            Icons.local_fire_department,
                          ),
                          _buildWeeklyStat(
                            context,
                            'Average',
                            weeklyData.isNotEmpty 
                                ? weeklyData.fold<double>(0, (sum, day) => sum + (day['calories'] as double)) / 7
                                : 0.0,
                            Icons.trending_up,
                          ),
                          _buildWeeklyStat(
                            context,
                            'Best Day',
                            weeklyData.isNotEmpty 
                                ? weeklyData.map((day) => day['calories'] as double).reduce((a, b) => a > b ? a : b)
                                : 0.0,
                            Icons.emoji_events,
                          ),
                        ],
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

  Widget _buildWeeklyStat(
    BuildContext context,
    String label,
    double value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFFFD700).withOpacity(0.6),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          CaloriesCalculator.formatCalories(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFFFFD700).withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
