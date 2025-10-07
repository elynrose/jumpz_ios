import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/calories_calculator.dart';

/// Service for managing calories data in Firestore
class CaloriesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Records calories burned for a jump session
  /// 
  /// [jumpCount] - Number of jumps performed
  /// [durationMinutes] - Duration of the session in minutes
  /// [weightKg] - User's weight in kilograms (optional)
  /// [sessionId] - Optional session ID to link with jump session
  Future<void> recordSessionCalories({
    required int jumpCount,
    required double durationMinutes,
    double? weightKg,
    String? sessionId,
  }) async {
    final uid = getCurrentUserId();
    if (uid == null) return;

    try {
      // Calculate calories for this session
      final sessionData = CaloriesCalculator.calculateSessionCalories(
        jumpCount: jumpCount,
        durationMinutes: durationMinutes,
        weightKg: weightKg,
      );

      final calories = sessionData['calories'] as double;
      final intensity = sessionData['intensity'] as JumpIntensity;
      final jumpsPerMinute = sessionData['jumpsPerMinute'] as double;
      final metValue = sessionData['metValue'] as double;

      // Record in Firestore
      await _firestore.runTransaction((transaction) async {
        final userDoc = _firestore.collection('users').doc(uid);
        final today = DateTime.now();
        final todayKey = today.toIso8601String().split('T')[0];
        
        // Update daily calories
        final dailyCaloriesDoc = _firestore
            .collection('users')
            .doc(uid)
            .collection('dailyCalories')
            .doc(todayKey);
        
        // Read ALL documents first (before any writes)
        final dailySnapshot = await transaction.get(dailyCaloriesDoc);
        final userSnapshot = await transaction.get(userDoc);
        
        // Get current values
        final currentDailyCalories = (dailySnapshot.data()?['calories'] ?? 0.0) as double;
        final currentTotalCalories = (userSnapshot.data()?['totalCalories'] ?? 0.0) as double;
        
        // Now do all writes
        // Update daily calories
        transaction.set(dailyCaloriesDoc, {
          'calories': currentDailyCalories + calories,
          'date': today,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        // Record session details
        final sessionRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('calorieSessions')
            .doc();
        
        transaction.set(sessionRef, {
          'calories': calories,
          'jumpCount': jumpCount,
          'durationMinutes': durationMinutes,
          'intensity': intensity.name,
          'jumpsPerMinute': jumpsPerMinute,
          'metValue': metValue,
          'weightKg': weightKg ?? 70.0,
          'timestamp': FieldValue.serverTimestamp(),
          'sessionId': sessionId,
        });
        
        // Update user's total calories
        transaction.update(userDoc, {
          'totalCalories': currentTotalCalories + calories,
          'lastCaloriesUpdate': FieldValue.serverTimestamp(),
        });
      });
      
      print('✅ Calories recorded: $calories calories for $jumpCount jumps');
    } catch (e) {
      print('❌ Error recording calories: $e');
      rethrow;
    }
  }

  /// Gets today's calories burned
  Future<Map<String, dynamic>> getTodayCalories() async {
    final uid = getCurrentUserId();
    if (uid == null) return {'calories': 0.0, 'goal': 0.0, 'percentage': 0.0};

    try {
      final today = DateTime.now();
      final todayKey = today.toIso8601String().split('T')[0];
      
      final dailyCaloriesDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyCalories')
          .doc(todayKey)
          .get();
      
      final calories = (dailyCaloriesDoc.data()?['calories'] ?? 0.0) as double;
      
      // Get user's daily calories goal
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final dailyGoal = (userDoc.data()?['dailyCaloriesGoal'] ?? 0.0) as double;
      
      final percentage = dailyGoal > 0 ? (calories / dailyGoal * 100).clamp(0.0, 100.0) : 0.0;
      
      return {
        'calories': calories,
        'goal': dailyGoal,
        'percentage': percentage,
        'isCompleted': calories >= dailyGoal,
      };
    } catch (e) {
      print('❌ Error getting today\'s calories: $e');
      return {'calories': 0.0, 'goal': 0.0, 'percentage': 0.0};
    }
  }

  /// Stream of today's calories that updates in real-time
  Stream<Map<String, dynamic>> getTodayCaloriesStream() {
    final uid = getCurrentUserId();
    if (uid == null) return Stream.value({'calories': 0.0, 'goal': 0.0, 'percentage': 0.0});

    final today = DateTime.now();
    final todayKey = today.toIso8601String().split('T')[0];
    
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyCalories')
        .doc(todayKey)
        .snapshots()
        .asyncMap((dailyCaloriesSnapshot) async {
          final calories = (dailyCaloriesSnapshot.data()?['calories'] ?? 0.0) as double;
          
          // Get user's daily calories goal
          final userDoc = await _firestore.collection('users').doc(uid).get();
          final dailyGoal = (userDoc.data()?['dailyCaloriesGoal'] ?? 0.0) as double;
          
          final percentage = dailyGoal > 0 ? (calories / dailyGoal * 100).clamp(0.0, 100.0) : 0.0;
          
          return {
            'calories': calories,
            'goal': dailyGoal,
            'percentage': percentage,
            'isCompleted': calories >= dailyGoal,
          };
        });
  }

  /// Gets weekly calories data for the last 7 days
  Future<List<Map<String, dynamic>>> getWeeklyCalories() async {
    final uid = getCurrentUserId();
    if (uid == null) return [];

    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 6));
      
      final List<Map<String, dynamic>> weeklyData = [];
      
      for (int i = 0; i < 7; i++) {
        final date = weekAgo.add(Duration(days: i));
        final dateStart = DateTime(date.year, date.month, date.day);
        final dateKey = dateStart.toIso8601String().split('T')[0];
        
        try {
          final caloriesDoc = await _firestore
              .collection('users')
              .doc(uid)
              .collection('dailyCalories')
              .doc(dateKey)
              .get();
          
          final calories = (caloriesDoc.data()?['calories'] ?? 0.0) as double;
          weeklyData.add({
            'date': dateStart,
            'calories': calories,
            'dayOfWeek': date.weekday - 1, // Convert to 0-6 (Mon-Sun)
          });
        } catch (e) {
          weeklyData.add({
            'date': dateStart,
            'calories': 0.0,
            'dayOfWeek': date.weekday - 1,
          });
        }
      }
      
      return weeklyData;
    } catch (e) {
      print('❌ Error getting weekly calories: $e');
      return [];
    }
  }

  /// Gets all-time calories statistics
  Future<Map<String, dynamic>> getAllTimeCaloriesStats() async {
    final uid = getCurrentUserId();
    if (uid == null) return {};

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      
      final totalCalories = (userData['totalCalories'] ?? 0.0) as double;
      
      // Get weekly data to calculate averages
      final weeklyData = await getWeeklyCalories();
      final weeklyCalories = weeklyData.fold<double>(0, (sum, day) => sum + (day['calories'] as double));
      final averagePerDay = weeklyCalories / 7;
      final bestDay = weeklyData.isNotEmpty 
          ? weeklyData.map((day) => day['calories'] as double).reduce((a, b) => a > b ? a : b)
          : 0.0;
      
      // Get calories streak (consecutive days with calories burned)
      final caloriesStreak = await _calculateCaloriesStreak();
      
      return {
        'totalCalories': totalCalories,
        'weeklyCalories': weeklyCalories,
        'averagePerDay': averagePerDay.roundToDouble(),
        'bestDay': bestDay,
        'caloriesStreak': caloriesStreak,
      };
    } catch (e) {
      print('❌ Error getting all-time calories stats: $e');
      return {
        'totalCalories': 0.0,
        'weeklyCalories': 0.0,
        'averagePerDay': 0.0,
        'bestDay': 0.0,
        'caloriesStreak': 0,
      };
    }
  }

  /// Calculates calories streak (consecutive days with calories burned)
  Future<int> _calculateCaloriesStreak() async {
    final uid = getCurrentUserId();
    if (uid == null) return 0;

    try {
      int streak = 0;
      DateTime currentDate = DateTime.now();
      
      // Check backwards from today
      for (int i = 0; i < 365; i++) { // Check up to a year back
        final dateKey = currentDate.toIso8601String().split('T')[0];
        
        final caloriesDoc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('dailyCalories')
            .doc(dateKey)
            .get();
        
        final calories = (caloriesDoc.data()?['calories'] ?? 0.0) as double;
        
        if (calories > 0) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      
      return streak;
    } catch (e) {
      print('❌ Error calculating calories streak: $e');
      return 0;
    }
  }

  /// Sets user's daily calories goal
  Future<void> setDailyCaloriesGoal(double goal) async {
    final uid = getCurrentUserId();
    if (uid == null) return;
    
    try {
      await _firestore.collection('users').doc(uid).update({
        'dailyCaloriesGoal': goal,
        'caloriesGoalUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error setting daily calories goal: $e');
      rethrow;
    }
  }

  /// Gets user's daily calories goal
  Future<double> getDailyCaloriesGoal() async {
    final uid = getCurrentUserId();
    if (uid == null) return 0.0;
    
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return (userDoc.data()?['dailyCaloriesGoal'] ?? 0.0) as double;
    } catch (e) {
      print('❌ Error getting daily calories goal: $e');
      return 0.0;
    }
  }

  /// Sets user's weight for accurate calorie calculations
  Future<void> setUserWeight(double weightKg, {String weightUnit = 'kg'}) async {
    final uid = getCurrentUserId();
    if (uid == null) return;
    
    try {
      print('🔄 Setting user weight: $weightKg kg (unit: $weightUnit)');
      
      await _firestore.collection('users').doc(uid).update({
        'weightKg': weightKg,
        'weightUnit': weightUnit,
        'weightUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ User weight saved successfully: $weightKg kg');
    } catch (e) {
      print('❌ Error setting user weight: $e');
      rethrow;
    }
  }

  /// Gets user's weight in kilograms
  Future<double?> getUserWeight() async {
    final uid = getCurrentUserId();
    if (uid == null) return null;
    
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final weightKg = (userDoc.data()?['weightKg'] as double?);
      print('🔄 Retrieved user weight: $weightKg kg');
      return weightKg;
    } catch (e) {
      print('❌ Error getting user weight: $e');
      return null;
    }
  }

  /// Gets user's weight with unit preference for display
  Future<Map<String, dynamic>> getUserWeightWithUnit() async {
    final uid = getCurrentUserId();
    if (uid == null) return {'weight': null, 'unit': 'kg', 'displayWeight': null};
    
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      
      final weightKg = (data?['weightKg'] as double?);
      final weightUnit = (data?['weightUnit'] as String?) ?? 'kg';
      
      if (weightKg == null) {
        return {'weight': null, 'unit': weightUnit, 'displayWeight': null};
      }
      
      // Convert to display unit if needed
      double displayWeight = weightKg;
      if (weightUnit == 'lbs') {
        displayWeight = weightKg * 2.20462; // Convert kg to lbs
      }
      
      print('🔄 Retrieved user weight with unit: $displayWeight $weightUnit (${weightKg}kg)');
      
      return {
        'weight': weightKg,
        'unit': weightUnit,
        'displayWeight': displayWeight,
      };
    } catch (e) {
      print('❌ Error getting user weight with unit: $e');
      return {'weight': null, 'unit': 'kg', 'displayWeight': null};
    }
  }

  /// Gets recent calorie sessions (last 30 days)
  Future<List<Map<String, dynamic>>> getRecentCalorieSessions({int limit = 30}) async {
    final uid = getCurrentUserId();
    if (uid == null) return [];

    try {
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('calorieSessions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return sessionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'calories': data['calories'] ?? 0.0,
          'jumpCount': data['jumpCount'] ?? 0,
          'durationMinutes': data['durationMinutes'] ?? 0.0,
          'intensity': data['intensity'] ?? 'light',
          'jumpsPerMinute': data['jumpsPerMinute'] ?? 0.0,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting recent calorie sessions: $e');
      return [];
    }
  }

  /// Deletes all calories data for the current user (for testing/reset)
  Future<void> deleteAllCaloriesData() async {
    final uid = getCurrentUserId();
    if (uid == null) return;

    try {
      // Delete daily calories collection
      final dailyCaloriesSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyCalories')
          .get();
      
      for (final doc in dailyCaloriesSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete calorie sessions collection
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('calorieSessions')
          .get();
      
      for (final doc in sessionsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Reset user's total calories
      await _firestore.collection('users').doc(uid).update({
        'totalCalories': 0.0,
        'lastCaloriesUpdate': FieldValue.serverTimestamp(),
      });
      
      print('✅ All calories data deleted');
    } catch (e) {
      print('❌ Error deleting calories data: $e');
      rethrow;
    }
  }
}
