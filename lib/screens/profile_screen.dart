import 'package:flutter/material.dart';
import 'package:mykerawang/screens/edit_profile_screen.dart';
import 'package:mykerawang/screens/event_detail_screen.dart';
import 'package:mykerawang/screens/follow_list_screen.dart';
import 'package:mykerawang/screens/image_preview_screen.dart';
import 'package:mykerawang/screens/post_detail_screen.dart';
import 'package:mykerawang/widgets/linear_refresher';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import '../widgets/universal_card.dart';
import '../widgets/post_card.dart';
import 'settings_screen.dart';
import 'item_detail_screen.dart'; // Needed for navigation
import 'package:mobile_scanner/mobile_scanner.dart';

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
  int _followerCount = 0;   // <--- Add this
  int _followingCount = 0;
  
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
      final posts = await _supabase.from('posts').select('*,profiles(*), events(*), listings(*)').eq('user_id', targetUid).order('created_at', ascending: false);
      final events = await _supabase.from('events').select().eq('organizer_id', targetUid).order('start_datetime', ascending: false);
      
      // <--- NEW: Fetch Listings
      final listings = await _supabase.from('listings').select().eq('seller_id', targetUid).eq('is_sold', false).order('created_at', ascending: false);

      // 3. Check Follow Status
      if (!_isMe && currentUid != null) {
        final followCheck = await _supabase.from('followers')
            .select()
            .eq('follower_id', currentUid)
            .eq('following_id', targetUid)
            .maybeSingle();
        _isFollowing = followCheck != null;
      }

      // 1. Count how many people follow THIS user
      final followers = await _supabase
          .from('followers')
          .count(CountOption.exact)
          .eq('following_id', targetUid);

      // 2. Count how many people THIS user follows
      final following = await _supabase
          .from('followers')
          .count(CountOption.exact)
          .eq('follower_id', targetUid);

      if (mounted) {
        setState(() {
          _profile = profileData;
          _userPosts = posts.map((p) => {...p, 'type': 'post'}).toList();
          _userEvents = events.map((e) => {...e, 'type': 'event'}).toList();
          _userListings = listings.map((l) => {...l, 'type': 'listing'}).toList(); // <--- NEW
          _isLoading = false;
          _followerCount = followers;
          _followingCount = following;
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

    // Optimistic UI Update
    setState(() => _isFollowing = !_isFollowing); 

    try {
      if (_isFollowing) {
        // 1. Insert Follow Record
        await _supabase.from('followers').insert({'follower_id': currentUid, 'following_id': targetUid});
        
        // 2. SEND NOTIFICATION (New!)
        // Fetch my name first so the notification looks nice ("Fahmi followed you")
        final myProfile = await _supabase.from('profiles').select('display_name').eq('id', currentUid).single();
        
        await _supabase.from('notifications').insert({
          'user_id': targetUid,      // Send TO target
          'actor_id': currentUid,    // From ME
          'type': 'follow',
          'title': 'New Follower',
          'body': '${myProfile['display_name']} started following you.',
          'data': {}, // No extra data needed for follow
        });

      } else {
        // Unfollow
        await _supabase.from('followers').delete().match({'follower_id': currentUid, 'following_id': targetUid});
      }
    } catch (e) {
      // Revert if error
      setState(() => _isFollowing = !_isFollowing); 
    }
  }

  void _showQRCode() {
    final theme = Theme.of(context);
    final qrColor = theme.colorScheme.onSurface; 

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: DefaultTabController(
          length: 2,
          child: SizedBox(
            height: 450,
            child: Column(
              children: [
                const TabBar(
                  tabs: [Tab(text: "My Code"), Tab(text: "Scan")],
                ),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // TAB 1: MY CODE
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: "mykerawang://user/${widget.userId ?? _supabase.auth.currentUser?.id}",
                              version: QrVersions.auto,
                              size: 200.0,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: qrColor,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: qrColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "@${_profile?['username'] ?? 'User'}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),

                      // TAB 2: SCANNER (FIXED)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        child: MobileScanner(
                          // FIX 1: Only 2 arguments (context, error)
                          errorBuilder: (context, error) { 
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam_off, color: Colors.grey, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Camera Error: ${error.errorCode}",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                          // FIX 2: Only 1 argument (context)
                          placeholderBuilder: (context) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null) {
                                final code = barcode.rawValue!;
                                if (code.startsWith("mykerawang://user/")) {
                                  final userId = code.split("/").last;
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
                                  );
                                  break;
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                  GestureDetector(
                    onTap: () {
                      if (_profile!['avatar_url'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ImagePreviewScreen(imageUrl: _profile!['avatar_url'])),
                        );
                      }
                    },
                    child: CircleAvatar(
                        radius: 40,
                        backgroundImage: _profile!['avatar_url'] != null 
                            ? NetworkImage(_profile!['avatar_url']) 
                            : null,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: _profile!['avatar_url'] == null 
                            ? Text(_profile!['display_name']?[0] ?? "U", style: const TextStyle(fontSize: 30)) 
                            : null,
                      ),
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


                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem("Posts", "${_userPosts.length}"), // No tap for posts
                      
                      // Followers Tap
                      _statItem(
                        "Followers", 
                        "$_followerCount", 
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(userId: widget.userId ?? _supabase.auth.currentUser!.id, type: 'followers')))
                      ),
                      
                      // Following Tap
                      _statItem(
                        "Following", 
                        "$_followingCount",
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(userId: widget.userId ?? _supabase.auth.currentUser!.id, type: 'following')))
                      ),
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
                        itemCount: _userPosts.length,
                        itemBuilder: (context, index) {
                          return PostCard(
                            post: _userPosts[index],
                            showProfileHeader: false, // remove profile header in post card
                            onTap: () { 
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: _userPosts[index]))); 
                            },
                          );
                        },
                      ),
                  
                  // Tab 2: Events - SWITCH TO GRID
                  _userEvents.isEmpty 
                    ? const Center(child: Text("No events hosted"))
                    : _buildPhotoGrid(_userEvents, true), // <--- USE YOUR FUNCTION HERE
                    
                  // Tab 3: Shop - SWITCH TO GRID
                  _userListings.isEmpty
                    ? const Center(child: Text("Not selling anything"))
                    : _buildPhotoGrid(_userListings, false), // <--- AND HERE
                ],
              ),
            ),
          ],
        ),
      ),
      )
    );
  }

  Widget _statItem(String label, String count, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // Helper Widget for Insta-Grid
  Widget _buildPhotoGrid(List<dynamic> items, bool isEvent) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 across like Instagram
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () {
            // Navigate to details
            if (isEvent) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: item)));
            } else {
              // Check type (Listing vs Post) if mixed, otherwise assume Listing
              Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
            }
          },
          onLongPress: () {
            // Point 5: "Pop up details" - Simple implementation is a SnackBar or Dialog
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(item['image_url'], height: 200, fit: BoxFit.cover),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(item['title'] ?? "No Title", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Image.network(
            item['image_url'] ?? '', // Ensure your posts/events have image_url
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
          ),
        );
      },
    );
  }
}