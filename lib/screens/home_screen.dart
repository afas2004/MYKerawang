import 'package:flutter/material.dart';
import 'package:mykerawang/screens/create_event_screen.dart';
import 'package:mykerawang/screens/create_listing_screen.dart';
import 'package:mykerawang/screens/post_detail_screen.dart';
import 'package:mykerawang/widgets/linear_refresher';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/universal_card.dart';
import '../widgets/post_card.dart';
import 'event_detail_screen.dart';
import 'item_detail_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart'; // We will create this next
import 'create_post_screen.dart'; // We will create this next

class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;

  const HomeScreen({super.key, required this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  List<dynamic> _socialFeed = []; 
  List<dynamic> _featuredEvents = []; 
  List<dynamic> _freshMarketItems = []; // New Horizontal Section

  @override
  void initState() {
    super.initState();
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Fetch Events (Carousel)
      final events = await _supabase.from('events')
          .select()
          .gt('end_datetime', now)
          .order('start_datetime', ascending: true)
          .limit(8);
      
      // 2. Fetch Listings (Horizontal Scroll)
      final listings = await _supabase.from('listings')
          .select()
          .eq('is_sold', false)
          .order('created_at', ascending: false)
          .limit(8);

      // 3. Fetch Posts and linked Events
      // We also mix in a few events/listings into the feed for variety
      final posts = await _supabase.from('posts')
          .select('*,profiles(*), events(*), listings(*)')
          .order('created_at', ascending: false);

      final List<dynamic> mixedFeed = [];
      for (var p in posts) { mixedFeed.add({...p, 'type': 'post'}); }
      
      // Shuffle 2 random events into the feed just for fun
      if (events.length > 2) {
        mixedFeed.insert(5, {...events[5], 'type': 'event'});
      }

      if (mounted) {
        setState(() {
          _featuredEvents = events;
          _freshMarketItems = listings;
          _socialFeed = mixedFeed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching feed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // FAB for "Functional" Creation
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: LinearRefresher(
        onRefresh: _fetchFeedData,
        offset: topPadding,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. APP BAR
            SliverAppBar(
              floating: true,
              snap: true,
            title: const Text("MYKerawang", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            centerTitle: false,
            actions: [
              // Notification Bell (Working)
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
              ),
              // Settings Icon (Replaces Avatar)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // 2. EVENTS CAROUSEL (Horizontal)
          if (!_isLoading && _featuredEvents.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader("Happening Soon", () => widget.onTabChange(3)), // Jump to Events Tab
                  SizedBox(
                    height: 280, // INCREASED HEIGHT (Fixes Overflow)
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _featuredEvents.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 260,
                          margin: const EdgeInsets.only(right: 12, bottom: 10),
                          child: UniversalCard(
                            data: _featuredEvents[index], 
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: _featuredEvents[index]))),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // 3. MARKETPLACE CAROUSEL (New Horizontal Section)
          if (!_isLoading && _freshMarketItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader("Fresh Finds", () => widget.onTabChange(2)), // Jump to Market Tab
                  SizedBox(
                    height: 280, 
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _freshMarketItems.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 200, // Slightly smaller cards for items
                          margin: const EdgeInsets.only(right: 12, bottom: 10),
                          child: UniversalCard(
                            data: _freshMarketItems[index], 
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: _freshMarketItems[index]))),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(thickness: 8, height: 24), // Thick separator
                ],
              ),
            ),

          // 4. SOCIAL FEED (Vertical)
          _isLoading 
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _socialFeed[index];
                    if (item['type'] == 'event') {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: UniversalCard(
                          data: item, 
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: item)))
                        ),
                      );
                    }
                    return PostCard(
                      post: item,
                      onTap: () {
                         Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => PostDetailScreen(post: item))
                        );
                      },
                    );
                  },
                  childCount: _socialFeed.length,
                ),
              ),
        ],
      ),
      )
    );
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(onPressed: onSeeAll, child: const Text("See All")),
        ],
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Create Post'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()));
              }
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Host Event'),
              onTap: () {
                Navigator.pop(ctx);
                // We assume CreateEventScreen is already imported
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen()));
              }
            ),
            ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('Sell Item'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateListingScreen()));
              }
            ),
          ],
        ),
      ),
    );
  }
}