import 'dart:math'; // Import this for Random()
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
import 'notification_screen.dart'; 
import 'create_post_screen.dart'; 

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
  List<dynamic> _freshMarketItems = []; 

  @override
  void initState() {
    super.initState();
    _fetchFeedData();
  }

  Future<void> _fetchFeedData() async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Fetch Events (For Carousel & Injection)
      final events = await _supabase.from('events')
          .select()
          .gt('end_datetime', now)
          .order('start_datetime', ascending: true)
          .limit(20); // Fetch more for injection
      
      // 2. Fetch Listings (For Horizontal & Injection)
      final listings = await _supabase.from('listings')
          .select()
          .eq('is_sold', false)
          .order('created_at', ascending: false)
          .limit(20);

      // 3. Fetch Posts
      final posts = await _supabase.from('posts')
          .select('*,profiles(*), events(*), listings(*)')
          .order('created_at', ascending: false)
          .limit(50); // Fetch enough posts

      // 4. PREPARE MIXED FEED
      final List<dynamic> mixedFeed = [];
      
      // Create a pool of "Injectable" items (Events + Listings)
      final List<dynamic> injectables = [
        ...events.map((e) => {...e, 'type': 'event'}),
        ...listings.map((l) => {...l, 'type': 'listing'})
      ];
      injectables.shuffle(); // Shuffle so it's not always the same items

      int postCounter = 0;
      int injectionInterval = 5 + Random().nextInt(4); // Random interval: 5, 6, 7, or 8

      for (var p in posts) {
        // Add the post
        mixedFeed.add({...p, 'type': 'post'});
        postCounter++;

        // Check if it's time to inject
        if (postCounter >= injectionInterval) {
          if (injectables.isNotEmpty) {
            // Take one item from the pool and insert it
            mixedFeed.add(injectables.removeAt(0));
            
            // Reset counter and pick a new random interval
            postCounter = 0;
            injectionInterval = 5 + Random().nextInt(4);
          }
        }
      }

      if (mounted) {
        setState(() {
          _featuredEvents = events.take(8).toList(); // Keep top 8 for carousel
          _freshMarketItems = listings.take(8).toList();
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
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                ),
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
                    _sectionHeader("Happening Soon", () => widget.onTabChange(3)), 
                    SizedBox(
                      height: 280,
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

            // 3. MARKETPLACE CAROUSEL (Horizontal)
            if (!_isLoading && _freshMarketItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader("Fresh Finds", () => widget.onTabChange(2)), 
                    SizedBox(
                      height: 280, 
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _freshMarketItems.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 200, 
                            margin: const EdgeInsets.only(right: 12, bottom: 10),
                            child: UniversalCard(
                              data: _freshMarketItems[index], 
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: _freshMarketItems[index]))),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(thickness: 8, height: 24), 
                  ],
                ),
              ),

            // 4. SOCIAL FEED (Vertical Mixed)
            _isLoading 
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _socialFeed[index];
                      
                      // RENDER INJECTED CARDS (Event or Listing)
                      if (item['type'] == 'event' || item['type'] == 'listing') {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  item['type'] == 'event' ? "Suggested Event" : "Featured Item",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              UniversalCard(
                                data: item, 
                                onTap: () {
                                  if (item['type'] == 'event') {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: item)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
                                  }
                                }
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                            ],
                          ),
                        );
                      }
                      
                      // RENDER POST
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