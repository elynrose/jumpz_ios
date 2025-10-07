import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import 'user_profile_screen.dart';

class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'All Time'),
          ],
        ),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTodayLeaderboard(context),
            _buildAllTimeLeaderboard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLeaderboard(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Provider.of<FirestoreService>(context, listen: false)
          .getTodayLeaderboardStream(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading today\'s leaderboard...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Card(
              elevation: 4,
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFFD700),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading today\'s leaderboard',
                      style: TextStyle(color: Colors.red, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please try again later',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Card(
              elevation: 4,
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.today,
                      color: Color(0xFFFFD700),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No jumps today yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Be the first to jump today!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final rank = index + 1;
            final isCurrentUser = user['isCurrentUser'] == true;
            
            return _buildLeaderboardItem(
              context,
              rank,
              user['displayName'] ?? user['email'] ?? 'Anonymous',
              user['todayJumps'] ?? 0,
              isCurrentUser,
              user['userId'] ?? '',
              isToday: true,
            );
          },
        );
      },
    );
  }

  Widget _buildAllTimeLeaderboard(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Provider.of<FirestoreService>(context, listen: false)
          .leaderboardStream(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading all-time leaderboard...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Card(
              elevation: 4,
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFFD700),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading all-time leaderboard',
                      style: TextStyle(color: Colors.red, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please try again later',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Card(
              elevation: 4,
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.leaderboard,
                      color: Color(0xFFFFD700),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No leaderboard data yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start jumping to appear on the leaderboard!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final rank = index + 1;
            final isCurrentUser = user['isCurrentUser'] == true;
            
            return _buildLeaderboardItem(
              context,
              rank,
              user['displayName'] ?? user['email'] ?? 'Anonymous',
              user['totalJumps'] ?? 0,
              isCurrentUser,
              user['userId'] ?? '',
              isToday: false,
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    int rank,
    String name,
    int jumps,
    bool isCurrentUser,
    String userId,
    {required bool isToday}
  ) {
    final theme = Theme.of(context);
    
    Color rankColor;
    IconData rankIcon;
    
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700);
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey[400]!;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32);
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.grey[600]!;
        rankIcon = Icons.person;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentUser ? 8 : 4,
      color: isCurrentUser ? Colors.grey[800] : Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrentUser ? const Color(0xFFFFD700) : Colors.grey[700]!,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: userId,
                displayName: name,
              ),
            ),
          );
        },
        child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rankColor, width: 1),
          ),
          child: Center(
            child: rank <= 3
                ? Icon(rankIcon, color: rankColor, size: 20)
                : Text(
                    rank.toString(),
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        title: Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            color: isCurrentUser ? const Color(0xFFFFD700) : Colors.white,
          ),
        ),
        subtitle: Text(
          isToday ? '$jumps jumps today' : '$jumps total jumps',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[400],
          ),
        ),
        trailing: rank <= 3
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rankColor, width: 1),
                ),
                child: Text(
                  rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                  style: const TextStyle(fontSize: 16),
                ),
              )
            : null,
        ),
      ),
    );
  }

}