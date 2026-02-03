import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String type; // 'followers' or 'following'

  const FollowListScreen({super.key, required this.userId, required this.type});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchList();
  }

  Future<void> _fetchList() async {
    try {
      dynamic response;
      
      // The Logic:
      // If 'followers': We want the profiles of people who follow userId.
      // If 'following': We want the profiles of people userId follows.

      if (widget.type == 'followers') {
        // Get rows where 'following_id' is target. Expand 'follower_id' profile.
        response = await _supabase
            .from('followers')
            .select('profiles!follower_id(*)') // <--- Magic Line
            .eq('following_id', widget.userId);
      } else {
        // Get rows where 'follower_id' is target. Expand 'following_id' profile.
        response = await _supabase
            .from('followers')
            .select('profiles!following_id(*)') // <--- Magic Line
            .eq('follower_id', widget.userId);
      }

      if (mounted) {
        setState(() {
          // Clean up the data structure (unwrap the nested profile)
          _users = List<Map<String, dynamic>>.from(
            response.map((row) => row['profiles'])
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching follow list: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == 'followers' ? 'Followers' : 'Following'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _users.isEmpty 
          ? const Center(child: Text("List is empty"))
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['avatar_url'] != null 
                        ? NetworkImage(user['avatar_url']) 
                        : null,
                    child: user['avatar_url'] == null 
                        ? const Icon(Icons.person) 
                        : null,
                  ),
                  title: Text(user['display_name'] ?? 'User'),
                  subtitle: Text("@${user['username'] ?? ''}"),
                  onTap: () {
                    // Navigate to their profile
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: user['id'])
                      )
                    );
                  },
                );
              },
            ),
    );
  }
}