import 'package:flutter/material.dart';
import 'package:mykerawang/screens/edit_profile_screen.dart';
import 'package:mykerawang/screens/event_detail_screen.dart';
import 'package:mykerawang/widgets/linear_refresher';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import '../widgets/universal_card.dart';
import '../widgets/post_card.dart';
import 'settings_screen.dart';
import 'item_detail_screen.dart'; // Needed for navigation

class ProfileScreen extends StatefulWidget {
  final String? userId; 

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController; // Controls the 3 tabs
  
  bool _isLoading = true;
  bool _isMe = false;
  bool _isFollowing = false;
  
  Map<String, dynamic>? _profile;
  List<dynamic> _userPosts = [];
  List<dynamic> _userEvents = [];
  List<dynamic> _userListings = []; // <--- NEW: Store Listings
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // <--- CHANGED: 2 -> 3
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final currentUid = _supabase.auth.currentUser?.id;
    final targetUid = widget.userId ?? currentUid;

    if (targetUid == null) return; 

    _isMe = (currentUid == targetUid);

    try {
      // 1. Fetch Profile
      final profileData = await _supabase.from('profiles').select().eq('id', targetUid).single();
      
      // 2. Fetch Content (Posts, Events, AND Listings)
      final posts = await _supabase.from('posts').select().eq('user_id', targetUid).order('created_at', ascending: false);
      final events = await _supabase.from('events').select().eq('organizer_id', targetUid).order('start_datetime', ascending: false);
      
      // <--- NEW: Fetch Listings
      final listings = await _supabase.from('listings').select().eq('seller_id', targetUid).eq('is_sold', false).order('created_at', ascending: false);

      // 3. Check Follow Status
      if (!_isMe && currentUid != null) {
        final followCheck = await _supabase.from('follows')
            .select()
            .eq('follower_id', currentUid)
            .eq('following_id', targetUid)
            .maybeSingle();
        _isFollowing = followCheck != null;
      }

      if (mounted) {
        setState(() {
          _profile = profileData;
          _userPosts = posts.map((p) => {...p, 'type': 'post'}).toList();
          _userEvents = events.map((e) => {...e, 'type': 'event'}).toList();
          _userListings = listings.map((l) => {...l, 'type': 'listing'}).toList(); // <--- NEW
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _toggleFollow() async {
    final currentUid = _supabase.auth.currentUser?.id;
    final targetUid = widget.userId;
    if (currentUid == null || targetUid == null) return;

    setState(() => _isFollowing = !_isFollowing); 

    try {
      if (_isFollowing) {
        await _supabase.from('follows').insert({'follower_id': currentUid, 'following_id': targetUid});
      } else {
        await _supabase.from('follows').delete().match({'follower_id': currentUid, 'following_id': targetUid});
      }
    } catch (e) {
      setState(() => _isFollowing = !_isFollowing); 
    }
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Scan to Follow", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              QrImageView(
                data: "mykerawang://user/${widget.userId ?? _supabase.auth.currentUser?.id}",
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 20),
              Text("@${_profile?['username'] ?? 'user'}", style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return const Scaffold(body: Center(child: Text("User not found")));

    final theme = Theme.of(context);
    final isClub = _profile!['role'] == 'club';

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile!['username'] != null ? "@${_profile!['username']}" : "Profile"),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code), onPressed: _showQRCode),
          if (_isMe)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
        ],
      ),
      body: LinearRefresher(
      onRefresh: _fetchProfileData,
      offset: 0.0,
      child: NestedScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _profile!['avatar_url'] != null 
                        ? NetworkImage(_profile!['avatar_url']) 
                        : null,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: _profile!['avatar_url'] == null 
                        ? Text(_profile!['display_name']?[0] ?? "U", style: const TextStyle(fontSize: 30)) 
                        : null,
                  ),
                  const SizedBox(height: 12),
                  
                  // Name & Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _profile!['display_name'] ?? "UiTM Student",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (_profile!['is_verified'] == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 20),
                      ]
                    ],
                  ),
                  
                  if (_profile!['bio'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_profile!['bio'], textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ),

                  const SizedBox(height: 16),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem("Posts", "${_userPosts.length}"),
                      _statItem("Selling", "${_userListings.length}"), // <--- NEW: Selling Count
                      _statItem("Followers", "${_profile!['followers_count'] ?? 0}"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Follow / Edit Button
                  if (!_isMe)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _toggleFollow,
                        style: FilledButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.grey[300] : theme.colorScheme.primary,
                          foregroundColor: _isFollowing ? Colors.black : Colors.white,
                        ),
                        child: Text(_isFollowing ? "Following" : "Follow"),
                      ),
                    ),
                  if (_isMe && !isClub)
                    OutlinedButton(
                      onPressed: () {
                         Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const EditProfileScreen())
                        ).then((value) {
                          if (value == true) _fetchProfileData(); // Refresh profile when back
                        });
                      },
                      child: const Text("Edit Profile"),
                    ),
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: "Activity"),
                Tab(text: "Events"),
                Tab(text: "Shop"), // <--- NEW TAB
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Posts
                  _userPosts.isEmpty
                    ? const Center(child: Text("No posts yet"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _userPosts.length,
                        itemBuilder: (context, index) {
                          return PostCard(post: _userPosts[index], onTap: () {});
                        },
                      ),
                  
                  // Tab 2: Events
                  _userEvents.isEmpty 
                    ? const Center(child: Text("No events hosted"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _userEvents.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: UniversalCard(
                              data: _userEvents[index], 
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: _userEvents[index]))) // Use Event Detail if available
                            ),
                          );
                        },
                      ),

                  // Tab 3: Shop (Listings) <--- NEW LISTVIEW
                  _userListings.isEmpty
                    ? const Center(child: Text("Not selling anything"))
                    : GridView.builder( // Use Grid for items looks better
                        padding: const EdgeInsets.all(14),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _userListings.length,
                        itemBuilder: (context, index) {
                          return UniversalCard(
                            data: _userListings[index], 
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: _userListings[index]))),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      )
    );
  }

  Widget _statItem(String label, String count) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}