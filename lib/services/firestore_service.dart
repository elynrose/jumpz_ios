import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/wall_post.dart';
import 'notification_service.dart';

/// A service encapsulating Cloud Firestore reads and writes used by the
/// application. Each user has a document under the `users` collection keyed
/// by their UID. The document contains an aggregate `totalJumps` count and
/// personal metadata. Individual jump sessions are stored as subcollections
/// under the user document for detailed history.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Ensures that the current user's document exists in Firestore. Should be
  /// called once after sign in or sign up. If a document already exists this
  /// method does nothing. When creating a new document the `totalJumps` field
  /// is initialised to zero.
  Future<void> initUserIfNew() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'email': _auth.currentUser?.email,
        'displayName': _auth.currentUser?.displayName,
        'totalJumps': 0,
        'dailyGoal': 10,
        'goalStreak': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Records a completed jump session for the current user. The [count] is the
  /// number of jumps detected by the accelerometer. This method increments the
  /// user's `totalJumps` field and writes a document to the `jumpSessions`
  /// subcollection containing the count and timestamp for graphing.
  Future<void> recordJumpSession(int count) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final userDoc = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final currentTotal = (snapshot.get('totalJumps') ?? 0) as int;
      transaction.update(userDoc, {'totalJumps': currentTotal + count});
      final sessionRef = userDoc.collection('jumpSessions').doc();
      transaction.set(sessionRef, {
        'count': count,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Provides a stream of top users ordered by `totalJumps` descending. Each
  /// emitted list contains maps with `displayName` (or email if null) and
  /// `totalJumps`. This stream updates in realtime thanks to Firestore's
  /// realtime listeners【833088903653266†L1417-L1433】.
  Stream<List<Map<String, dynamic>>> leaderboardStream({int limit = 10}) {
    print('🔄 FirestoreService: Starting leaderboard stream...');
    print('🔄 FirestoreService: Collection path: users');
    print('🔄 FirestoreService: Limit: $limit');
    
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      print('📊 FirestoreService: Snapshot received: ${snapshot.docs.length} documents');
      print('📊 FirestoreService: Snapshot metadata: ${snapshot.metadata}');
      
      if (snapshot.docs.isEmpty) {
        print('⚠️ FirestoreService: No documents in snapshot');
        return <Map<String, dynamic>>[];
      }
      
      final users = <Map<String, dynamic>>[];
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        print('👤 FirestoreService: Document $i - ID: ${doc.id}');
        print('👤 FirestoreService: Data: ${data.toString()}');
        
        final user = {
          'displayName': data['displayName'] ?? data['email'] ?? 'Anonymous',
          'totalJumps': data['totalJumps'] ?? 0,
        };
        users.add(user);
        print('👤 FirestoreService: Processed user: ${user['displayName']} - ${user['totalJumps']} jumps');
      }
      
      // Sort by totalJumps descending and limit results
      users.sort((a, b) => (b['totalJumps'] as int).compareTo(a['totalJumps'] as int));
      final result = users.take(limit).toList();
      print('🏆 FirestoreService: Final leaderboard: ${result.length} users');
      return result;
    }).handleError((error, stackTrace) {
      print('❌ FirestoreService: Leaderboard stream error: $error');
      print('❌ FirestoreService: Stack trace: $stackTrace');
      // Return empty list on error
      return <Map<String, dynamic>>[];
    });
  }

  /// Provides a stream of jump session history for the current user. Each
  /// element in the stream is a list of maps containing `timestamp` and `count`.
  /// The results are ordered by timestamp ascending. This is used to plot the
  /// progress graph.
  Stream<List<Map<String, dynamic>>> jumpHistoryStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Return an empty stream if there is no signed‑in user.
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('jumpSessions')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
                'count': data['count'] ?? 0,
              };
            }).toList());
  }

  /// Sets the daily jump goal for the current user.
  Future<void> setDailyGoal(int goal) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Ensure user document exists first
    await initUserIfNew();
    
    await _firestore.collection('users').doc(uid).update({
      'dailyGoal': goal,
      'goalUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Saves alarm time to Firestore
  Future<void> saveAlarmTime(TimeOfDay alarmTime) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Ensure user document exists first
    await initUserIfNew();
    
    await _firestore.collection('users').doc(uid).update({
      'alarmHour': alarmTime.hour,
      'alarmMinute': alarmTime.minute,
      'alarmEnabled': true,
      'alarmUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gets saved alarm time from Firestore
  Future<TimeOfDay?> getAlarmTime() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    // Ensure user document exists first
    await initUserIfNew();
    
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data();
    
    if (data != null && data['alarmEnabled'] == true) {
      final hour = data['alarmHour'] as int?;
      final minute = data['alarmMinute'] as int?;
      
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    
    return null;
  }

  /// Disables alarm in Firestore
  Future<void> disableAlarm() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _firestore.collection('users').doc(uid).update({
      'alarmEnabled': false,
      'alarmUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gets the current daily goal for the user.
  Future<int> getDailyGoal() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 10; // Default goal
    
    // Ensure user document exists first
    await initUserIfNew();
    
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['dailyGoal'] ?? 10) as int;
  }

  /// Records progress towards the daily goal.
  Future<void> recordDailyProgress(int jumps) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Ensure user document exists first
    await initUserIfNew();
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    int newProgress = 0;
    await _firestore.runTransaction((transaction) async {
      final userDoc = _firestore.collection('users').doc(uid);
      final dailyProgressDoc = _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyProgress')
          .doc(todayStart.toIso8601String().split('T')[0]);
      
      // Read all documents first
      final progressSnapshot = await transaction.get(dailyProgressDoc);
      final userSnapshot = await transaction.get(userDoc);
      
      // Get current values
      final currentProgress = (progressSnapshot.data()?['jumps'] ?? 0) as int;
      final currentTotal = (userSnapshot.data()?['totalJumps'] ?? 0) as int;
      final dailyGoal = (userSnapshot.data()?['dailyGoal'] ?? 10) as int;
      
      // Calculate new progress
      newProgress = currentProgress + jumps;
      
      // Now perform all writes
      transaction.set(dailyProgressDoc, {
        'jumps': newProgress,
        'date': todayStart,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      transaction.update(userDoc, {
        'totalJumps': currentTotal + jumps,
        'lastActivity': FieldValue.serverTimestamp(),
      });
    });
    
    // Check if goal is completed and update reminders
    await _checkAndUpdateGoalReminders(uid, newProgress);
  }

  /// Gets today's progress towards the daily goal.
  Future<Map<String, dynamic>> getTodayProgress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'jumps': 0, 'goal': 10, 'percentage': 0.0};
    
    // Ensure user document exists first
    await initUserIfNew();
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayKey = todayStart.toIso8601String().split('T')[0];
    
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final dailyProgressDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyProgress')
        .doc(todayKey)
        .get();
    
    final goal = (userDoc.data()?['dailyGoal'] ?? 10) as int;
    final jumps = (dailyProgressDoc.data()?['jumps'] ?? 0) as int;
    final percentage = goal > 0 ? (jumps / goal * 100).clamp(0.0, 100.0) : 0.0;
    
    return {
      'jumps': jumps,
      'goal': goal,
      'percentage': percentage,
      'isCompleted': jumps >= goal,
    };
  }

  /// Stream of today's progress that updates in real-time.
  Stream<Map<String, dynamic>> getTodayProgressStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value({'jumps': 0, 'goal': 10, 'percentage': 0.0});
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayKey = todayStart.toIso8601String().split('T')[0];
    
    // Listen to the daily progress document directly since that's what changes
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyProgress')
        .doc(todayKey)
        .snapshots()
        .asyncMap((dailyProgressSnapshot) async {
          // Get user document for goal
          final userDoc = await _firestore.collection('users').doc(uid).get();
          
          // Ensure user document exists if it doesn't
          if (!userDoc.exists) {
            await initUserIfNew();
          }
          
          final goal = (userDoc.data()?['dailyGoal'] ?? 10) as int;
          final jumps = (dailyProgressSnapshot.data()?['jumps'] ?? 0) as int;
          final percentage = goal > 0 ? (jumps / goal * 100).clamp(0.0, 100.0) : 0.0;
          
          return {
            'jumps': jumps,
            'goal': goal,
            'percentage': percentage,
            'isCompleted': jumps >= goal,
          };
        });
  }

  /// Gets the user's goal completion streak.
  Future<int> getGoalStreak() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    
    // Ensure user document exists first
    await initUserIfNew();
    
    final userDoc = await _firestore.collection('users').doc(uid).get();
    return (userDoc.data()?['goalStreak'] ?? 0) as int;
  }

  /// Updates the goal completion streak.
  Future<void> updateGoalStreak() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Ensure user document exists first
    await initUserIfNew();
    
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day).toIso8601String().split('T')[0];
    
    await _firestore.runTransaction((transaction) async {
      final userDoc = _firestore.collection('users').doc(uid);
      final todayProgressDoc = _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyProgress')
          .doc(todayKey);
      
      // Read all documents first
      final userSnapshot = await transaction.get(userDoc);
      final todayProgressSnapshot = await transaction.get(todayProgressDoc);
      
      // Get current values
      final currentStreak = (userSnapshot.data()?['goalStreak'] ?? 0) as int;
      final todayJumps = (todayProgressSnapshot.data()?['jumps'] ?? 0) as int;
      final goal = (userSnapshot.data()?['dailyGoal'] ?? 10) as int;
      
      // Check if today's goal is completed
      if (todayJumps >= goal) {
        // Check if this is the first time completing today's goal
        final lastStreakUpdate = userSnapshot.data()?['lastStreakUpdate'] as Timestamp?;
        final todayStart = DateTime(today.year, today.month, today.day);
        
        if (lastStreakUpdate == null || 
            lastStreakUpdate.toDate().isBefore(todayStart)) {
          // First time completing today's goal - increment streak
          transaction.update(userDoc, {
            'goalStreak': currentStreak + 1,
            'lastStreakUpdate': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }
  
  /// Updates user settings (alarm sound, vibration, etc.)
  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Ensure user document exists first
    await initUserIfNew();
    
    await _firestore.collection('users').doc(uid).update({
      ...settings,
      'settingsUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Gets user settings
  Future<Map<String, dynamic>> getUserSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};
    
    // Ensure user document exists first
    await initUserIfNew();
    
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data() ?? {};
    
    return {
      'alarmSound': data['alarmSound'] ?? 'alarm',
      'vibrationEnabled': data['vibrationEnabled'] ?? true,
      'ledEnabled': data['ledEnabled'] ?? true,
      'fullScreenEnabled': data['fullScreenEnabled'] ?? true,
      'vibrationIntensity': data['vibrationIntensity'] ?? 3,
      'jumpSensitivity': data['jumpSensitivity'] ?? 3, // 1-5 scale (1=very sensitive, 5=less sensitive)
      'jumpDetectionMode': data['jumpDetectionMode'] ?? 'enhanced', // 'simple', 'enhanced', 'hybrid'
    };
  }

  /// Gets weekly progress data for the last 7 days
  Future<List<Map<String, dynamic>>> getWeeklyProgress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 6));
      
      // Generate date keys for the week
      final dateKeys = <String>[];
      for (int i = 0; i < 7; i++) {
        final date = weekAgo.add(Duration(days: i));
        final dateStart = DateTime(date.year, date.month, date.day);
        final dateKey = dateStart.toIso8601String().split('T')[0];
        dateKeys.add(dateKey);
      }
      
      // Use whereIn to get all documents in a single query
      final progressSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyProgress')
          .where(FieldPath.documentId, whereIn: dateKeys)
          .get();
      
      // Create a map of dateKey -> jumps for quick lookup
      final progressMap = <String, int>{};
      for (final doc in progressSnapshot.docs) {
        final jumps = (doc.data()['jumps'] ?? 0) as int;
        progressMap[doc.id] = jumps;
      }
      
      // Build weekly data with all 7 days
      final List<Map<String, dynamic>> weeklyData = [];
      for (int i = 0; i < 7; i++) {
        final date = weekAgo.add(Duration(days: i));
        final dateStart = DateTime(date.year, date.month, date.day);
        final dateKey = dateStart.toIso8601String().split('T')[0];
        
        weeklyData.add({
          'date': dateStart,
          'jumps': progressMap[dateKey] ?? 0,
          'dayOfWeek': date.weekday - 1, // Convert to 0-6 (Mon-Sun)
        });
      }
      
      return weeklyData;
    } catch (e) {
      print('❌ Error getting weekly progress: $e');
      return [];
    }
  }

  /// Gets user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      
      final totalJumps = (userData['totalJumps'] ?? 0) as int;
      final goalStreak = (userData['goalStreak'] ?? 0) as int;
      
      // Get weekly data to calculate averages
      final weeklyData = await getWeeklyProgress();
      final weeklyJumps = weeklyData.fold<int>(0, (sum, day) => sum + (day['jumps'] as int));
      
      // Calculate average per day - only count days with data
      final daysWithData = weeklyData.where((day) => (day['jumps'] as int) > 0).length;
      final averagePerDay = daysWithData > 0 ? weeklyJumps / daysWithData : 0.0;
      
      // Get best day from all-time data, not just weekly
      final bestDay = await _getAllTimeBestDay();
      
      return {
        'totalJumps': totalJumps,
        'goalStreak': goalStreak,
        'weeklyJumps': weeklyJumps,
        'averagePerDay': averagePerDay.round(),
        'bestDay': bestDay,
      };
    } catch (e) {
      print('❌ Error getting user stats: $e');
      return {
        'totalJumps': 0,
        'goalStreak': 0,
        'weeklyJumps': 0,
        'averagePerDay': 0,
        'bestDay': 0,
      };
    }
  }

  /// Gets all-time best day from jump sessions
  Future<int> _getAllTimeBestDay() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    try {
      // Get all jump sessions ordered by count descending
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('jumpSessions')
          .orderBy('count', descending: true)
          .limit(1)
          .get();
      
      if (sessionsSnapshot.docs.isNotEmpty) {
        return (sessionsSnapshot.docs.first.data()['count'] ?? 0) as int;
      }
      
      return 0;
    } catch (e) {
      print('❌ Error getting all-time best day: $e');
      return 0;
    }
  }

  /// Gets leaderboard data as a one-time fetch (fallback for stream issues)
  Future<List<Map<String, dynamic>>> getLeaderboardData({int limit = 50}) async {
    try {
      print('🔄 FirestoreService: Starting leaderboard fetch...');
      print('🔄 FirestoreService: Collection path: users');
      
      final usersSnapshot = await _firestore.collection('users').get();
      print('📊 FirestoreService: Retrieved ${usersSnapshot.docs.length} documents');
      
      if (usersSnapshot.docs.isEmpty) {
        print('⚠️ FirestoreService: No documents found in users collection');
        print('🔄 FirestoreService: This might mean no users have signed up yet');
        return [];
      }
      
      final users = <Map<String, dynamic>>[];
      for (int i = 0; i < usersSnapshot.docs.length; i++) {
        final doc = usersSnapshot.docs[i];
        final data = doc.data();
        print('👤 FirestoreService: Document $i - ID: ${doc.id}');
        print('👤 FirestoreService: Data keys: ${data.keys.toList()}');
        print('👤 FirestoreService: Full data: ${data.toString()}');
        print('👤 FirestoreService: displayName: ${data['displayName']}');
        print('👤 FirestoreService: email: ${data['email']}');
        print('👤 FirestoreService: totalJumps: ${data['totalJumps']}');
        
        final user = {
          'displayName': data['displayName'] ?? data['email'] ?? 'Anonymous',
          'totalJumps': data['totalJumps'] ?? 0,
        };
        users.add(user);
        print('👤 FirestoreService: Processed user: ${user['displayName']} - ${user['totalJumps']} jumps');
      }
      
      // Sort by totalJumps descending
      users.sort((a, b) => (b['totalJumps'] as int).compareTo(a['totalJumps'] as int));
      
      final result = users.take(limit).toList();
      print('🏆 FirestoreService: Final leaderboard: ${result.length} users');
      
      return result;
    } catch (e, stackTrace) {
      print('❌ FirestoreService: Error fetching leaderboard: $e');
      print('❌ FirestoreService: Stack trace: $stackTrace');
      return [];
    }
  }

  /// Gets today's leaderboard stream (daily jumps)
  Stream<List<Map<String, dynamic>>> getTodayLeaderboardStream({int limit = 50}) {
    print('🔄 FirestoreService: Starting today\'s leaderboard stream...');
    
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayKey = todayStart.toIso8601String().split('T')[0];
    
    print('🔄 FirestoreService: Today key: $todayKey');
    
    return _firestore.collection('users').snapshots().asyncMap((usersSnapshot) async {
      print('📊 FirestoreService: Retrieved ${usersSnapshot.docs.length} users');
      
      final List<Map<String, dynamic>> result = [];
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final userId = userDoc.id;
          
          // Get today's progress for this user
          final progressDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('dailyProgress')
              .doc(todayKey)
              .get();
          
          if (progressDoc.exists) {
            final progressData = progressDoc.data()!;
            final todayJumps = progressData['jumps'] ?? 0;
            
            if (todayJumps > 0) {
              final user = {
                'userId': userId,
                'displayName': userData['displayName'] ?? 'Anonymous',
                'todayJumps': todayJumps,
                'isCurrentUser': userId == _auth.currentUser?.uid,
              };
              result.add(user);
              print('👤 FirestoreService: ✅ Added to today\'s leaderboard: ${user['displayName']} - ${user['todayJumps']} jumps today');
            }
          }
        } catch (e) {
          print('⚠️ FirestoreService: Error getting progress for user ${userDoc.id}: $e');
        }
      }
      
      // Sort by today's jumps (descending)
      result.sort((a, b) => (b['todayJumps'] as int).compareTo(a['todayJumps'] as int));
      
      // Limit results
      final limitedResult = result.take(limit).toList();
      print('🏆 FirestoreService: Today\'s leaderboard: ${limitedResult.length} users');
      
      return limitedResult;
    }).handleError((error, stackTrace) {
      print('❌ FirestoreService: Today\'s leaderboard stream error: $error');
      print('❌ FirestoreService: Stack trace: $stackTrace');
      return <Map<String, dynamic>>[];
    });
  }

  /// Gets today's leaderboard data (daily jumps) - fallback method
  Future<List<Map<String, dynamic>>> getTodayLeaderboardData({int limit = 50}) async {
    try {
      print('🔄 FirestoreService: Starting today\'s leaderboard fetch...');
      
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayKey = todayStart.toIso8601String().split('T')[0];
      
      print('🔄 FirestoreService: Today key: $todayKey');
      
      // Get all users first
      final usersSnapshot = await _firestore.collection('users').get();
      print('📊 FirestoreService: Retrieved ${usersSnapshot.docs.length} users');
      
      if (usersSnapshot.docs.isEmpty) {
        print('⚠️ FirestoreService: No users found');
        return [];
      }
      
      final users = <Map<String, dynamic>>[];
      
      // For each user, get their today's progress
      for (int i = 0; i < usersSnapshot.docs.length; i++) {
        final userDoc = usersSnapshot.docs[i];
        final userData = userDoc.data();
        
        print('👤 FirestoreService: Checking user $i: ${userData['displayName'] ?? userData['email']}');
        print('👤 FirestoreService: User ID: ${userDoc.id}');
        
        try {
          // Get today's progress for this user
          final progressDoc = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('dailyProgress')
              .doc(todayKey)
              .get();
          
          print('👤 FirestoreService: Progress doc path: users/${userDoc.id}/dailyProgress/$todayKey');
          print('👤 FirestoreService: Progress doc exists: ${progressDoc.exists}');
          if (progressDoc.exists) {
            print('👤 FirestoreService: Progress data: ${progressDoc.data()}');
          } else {
            print('👤 FirestoreService: No progress document found for today');
          }
          
          final todayJumps = (progressDoc.data()?['jumps'] ?? 0) as int;
          print('👤 FirestoreService: Today jumps for ${userData['displayName']}: $todayJumps');
          
          if (todayJumps > 0) { // Only include users who jumped today
            final user = {
              'displayName': userData['displayName'] ?? userData['email'] ?? 'Anonymous',
              'todayJumps': todayJumps,
            };
            users.add(user);
            print('👤 FirestoreService: ✅ Added to today\'s leaderboard: ${user['displayName']} - ${user['todayJumps']} jumps today');
          } else {
            print('👤 FirestoreService: ❌ User ${userData['displayName']} has 0 jumps today, not included');
          }
        } catch (e) {
          print('⚠️ FirestoreService: Error getting progress for user ${userDoc.id}: $e');
        }
      }
      
      // Sort by today's jumps descending
      users.sort((a, b) => (b['todayJumps'] as int).compareTo(a['todayJumps'] as int));
      
      final result = users.take(limit).toList();
      print('🏆 FirestoreService: Today\'s leaderboard: ${result.length} users');
      return result;
    } catch (e, stackTrace) {
      print('❌ FirestoreService: Error fetching today\'s leaderboard: $e');
      print('❌ FirestoreService: Stack trace: $stackTrace');
      return [];
    }
  }

  /// Debug method to check current user's today's data
  Future<Map<String, dynamic>> debugCurrentUserData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return {'error': 'No user logged in'};
      }
      
      print('🔍 Debug: Current user UID: $uid');
      
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayKey = todayStart.toIso8601String().split('T')[0];
      
      print('🔍 Debug: Today key: $todayKey');
      
      // Get user document
      final userDoc = await _firestore.collection('users').doc(uid).get();
      print('🔍 Debug: User doc exists: ${userDoc.exists}');
      if (userDoc.exists) {
        print('🔍 Debug: User data: ${userDoc.data()}');
      }
      
      // Get today's progress
      final progressDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyProgress')
          .doc(todayKey)
          .get();
      
      print('🔍 Debug: Progress doc exists: ${progressDoc.exists}');
      if (progressDoc.exists) {
        print('🔍 Debug: Progress data: ${progressDoc.data()}');
      }
      
      return {
        'uid': uid,
        'todayKey': todayKey,
        'userExists': userDoc.exists,
        'userData': userDoc.data(),
        'progressExists': progressDoc.exists,
        'progressData': progressDoc.data(),
      };
    } catch (e, stackTrace) {
      print('❌ Debug error: $e');
      print('❌ Stack trace: $stackTrace');
      return {'error': e.toString()};
    }
  }

  /// Test method to check Firestore connection
  Future<Map<String, dynamic>> testConnection() async {
    try {
      print('🔄 Testing Firestore connection...');
      final usersSnapshot = await _firestore.collection('users').get();
      print('📊 Retrieved ${usersSnapshot.docs.length} documents');
      
      if (usersSnapshot.docs.isEmpty) {
        return {
          'success': true,
          'message': 'Connection successful, but no users found',
          'userCount': 0,
        };
      }
      
      final firstUser = usersSnapshot.docs.first.data();
      return {
        'success': true,
        'message': 'Connection successful',
        'userCount': usersSnapshot.docs.length,
        'firstUser': firstUser,
      };
    } catch (e, stackTrace) {
      print('❌ Firestore connection test failed: $e');
      return {
        'success': false,
        'message': 'Connection failed: $e',
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  /// Gets user achievements
  Future<List<Map<String, dynamic>>> getUserAchievements() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final stats = await getUserStats();
      final totalJumps = stats['totalJumps'] as int;
      final goalStreak = stats['goalStreak'] as int;
      
      final achievements = [
        {
          'id': 'first_jump',
          'title': 'First Jump',
          'description': 'Complete your first jump session',
          'iconName': 'play_arrow',
          'unlocked': totalJumps > 0,
        },
        {
          'id': 'daily_goal_3',
          'title': 'Daily Goal',
          'description': 'Complete your daily goal 3 days in a row',
          'iconName': 'today',
          'unlocked': goalStreak >= 3,
        },
        {
          'id': 'week_warrior',
          'title': 'Week Warrior',
          'description': 'Complete your daily goal for a full week',
          'iconName': 'calendar_today',
          'unlocked': goalStreak >= 7,
        },
        {
          'id': 'jump_master',
          'title': 'Jump Master',
          'description': 'Complete 100 total jumps',
          'iconName': 'star',
          'unlocked': totalJumps >= 100,
        },
      ];
      
      return achievements;
    } catch (e) {
      return [];
    }
  }

  // Wall Post Methods

  /// Create a new wall post
  Future<String> createWallPost(String content, {String? imagePath}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // Get user display name
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final displayName = userData?['displayName'] ?? 'Anonymous';

      final postData = {
        'userId': uid,
        'userDisplayName': displayName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'isReported': false,
        'reportCount': 0,
        'reportedBy': [],
        if (imagePath != null) 'imagePath': imagePath,
      };

      final docRef = await _firestore.collection('wallPosts').add(postData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create wall post: $e');
    }
  }

  /// Get wall posts stream (excluding reported posts)
  Stream<List<WallPost>> getWallPostsStream() {
    return _firestore
        .collection('wallPosts')
        .where('isReported', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return WallPost.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Like a wall post
  Future<void> likeWallPost(String postId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('wallPosts').doc(postId);
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');

        final postData = postDoc.data()!;
        final likedBy = List<String>.from(postData['likedBy'] ?? []);
        
        if (likedBy.contains(uid)) {
          // Unlike
          likedBy.remove(uid);
          transaction.update(postRef, {
            'likes': FieldValue.increment(-1),
            'likedBy': likedBy,
          });
        } else {
          // Like
          likedBy.add(uid);
          transaction.update(postRef, {
            'likes': FieldValue.increment(1),
            'likedBy': likedBy,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to like post: $e');
    }
  }

  /// Report a wall post
  Future<void> reportWallPost(String postId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('wallPosts').doc(postId);
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');

        final postData = postDoc.data()!;
        final reportedBy = List<String>.from(postData['reportedBy'] ?? []);
        
        if (!reportedBy.contains(uid)) {
          reportedBy.add(uid);
          final newReportCount = (postData['reportCount'] ?? 0) + 1;
          
          transaction.update(postRef, {
            'reportCount': newReportCount,
            'reportedBy': reportedBy,
            'isReported': newReportCount >= 3, // Hide after 3 reports
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to report post: $e');
    }
  }

  /// Delete a wall post (only by the author)
  Future<void> deleteWallPost(String postId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('wallPosts').doc(postId);
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');

        final postData = postDoc.data()!;
        if (postData['userId'] != uid) {
          throw Exception('You can only delete your own posts');
        }

        transaction.delete(postRef);
      });
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  /// Gets user stats for a specific user (for profile viewing)
  Future<Map<String, dynamic>> getUserStatsForUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data()!;
      return {
        'totalJumps': userData['totalJumps'] ?? 0,
        'goalStreak': userData['goalStreak'] ?? 0,
        'displayName': userData['displayName'] ?? 'Anonymous',
      };
    } catch (e) {
      throw Exception('Failed to get user stats: $e');
    }
  }

  /// Gets today's stats for a specific user
  Future<Map<String, dynamic>> getTodayStatsForUser(String userId) async {
    try {
      final today = DateTime.now();
      final todayKey = today.toIso8601String().split('T')[0];
      
      final progressDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyProgress')
          .doc(todayKey)
          .get();
      
      if (progressDoc.exists) {
        final progressData = progressDoc.data()!;
        return {
          'jumps': progressData['jumps'] ?? 0,
          'goal': progressData['goal'] ?? 0,
        };
      } else {
        return {
          'jumps': 0,
          'goal': 0,
        };
      }
    } catch (e) {
      throw Exception('Failed to get today\'s stats: $e');
    }
  }

  /// Checks and updates goal reminders based on current progress
  Future<void> _checkAndUpdateGoalReminders(String uid, int currentJumps) async {
    try {
      // Import notification service
      final notificationService = await _getNotificationService();
      
      // Get user's daily goal
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final dailyGoal = (userDoc.data()?['dailyGoal'] ?? 10) as int;
      
      // Check if goal is completed and update reminders
      await notificationService.checkAndUpdateGoalReminders(
        userId: uid.hashCode, // Convert string to int for notification IDs
        currentJumps: currentJumps,
        dailyGoal: dailyGoal,
      );
    } catch (e) {
      print('❌ Error checking goal reminders: $e');
    }
  }

  /// Gets notification service instance
  NotificationService _getNotificationService() {
    return NotificationService();
  }

  /// Schedules goal reminders for a user
  Future<void> scheduleGoalReminders({
    required String uid,
    required int dailyGoal,
    bool enabled = true,
  }) async {
    try {
      final notificationService = await _getNotificationService();
      
      // Get user's reminder settings
      final settings = await getReminderSettings();
      final reminderIntervalHours = settings['reminderIntervalHours'] ?? 4;
      
      await notificationService.scheduleGoalReminders(
        userId: uid.hashCode,
        dailyGoal: dailyGoal,
        enabled: enabled,
        reminderIntervalHours: reminderIntervalHours,
      );
    } catch (e) {
      print('❌ Error scheduling goal reminders: $e');
    }
  }

  /// Updates user reminder settings
  Future<void> updateReminderSettings({
    required bool goalRemindersEnabled,
    required int reminderIntervalHours,
    required bool smartRemindersEnabled,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _firestore.collection('users').doc(uid).update({
      'goalRemindersEnabled': goalRemindersEnabled,
      'reminderIntervalHours': reminderIntervalHours,
      'smartRemindersEnabled': smartRemindersEnabled,
      'reminderSettingsUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gets user reminder settings
  Future<Map<String, dynamic>> getReminderSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};
    
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data() ?? {};
    
    return {
      'goalRemindersEnabled': data['goalRemindersEnabled'] ?? true,
      'reminderIntervalHours': data['reminderIntervalHours'] ?? 4,
      'smartRemindersEnabled': data['smartRemindersEnabled'] ?? true,
    };
  }
}