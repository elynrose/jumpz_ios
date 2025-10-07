import 'package:cloud_firestore/cloud_firestore.dart';

class WallPost {
  final String id;
  final String userId;
  final String userDisplayName;
  final String content;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  final bool isReported;
  final int reportCount;
  final List<String> reportedBy;
  final String? imagePath;

  WallPost({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.likedBy = const [],
    this.isReported = false,
    this.reportCount = 0,
    this.reportedBy = const [],
    this.imagePath,
  });

  factory WallPost.fromMap(Map<String, dynamic> data, String id) {
    // Handle Firestore Timestamp conversion
    DateTime timestamp;
    if (data['timestamp'] != null) {
      if (data['timestamp'] is DateTime) {
        timestamp = data['timestamp'] as DateTime;
      } else {
        // Convert Firestore Timestamp to DateTime
        timestamp = (data['timestamp'] as dynamic).toDate();
      }
    } else {
      timestamp = DateTime.now();
    }

    return WallPost(
      id: id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: timestamp,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      isReported: data['isReported'] ?? false,
      reportCount: data['reportCount'] ?? 0,
      reportedBy: List<String>.from(data['reportedBy'] ?? []),
      imagePath: data['imagePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'content': content,
      'timestamp': timestamp,
      'likes': likes,
      'likedBy': likedBy,
      'isReported': isReported,
      'reportCount': reportCount,
      'reportedBy': reportedBy,
      if (imagePath != null) 'imagePath': imagePath,
    };
  }

  WallPost copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? content,
    DateTime? timestamp,
    int? likes,
    List<String>? likedBy,
    bool? isReported,
    int? reportCount,
    List<String>? reportedBy,
    String? imagePath,
  }) {
    return WallPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      isReported: isReported ?? this.isReported,
      reportCount: reportCount ?? this.reportCount,
      reportedBy: reportedBy ?? this.reportedBy,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
