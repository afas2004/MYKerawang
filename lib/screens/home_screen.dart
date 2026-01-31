import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mykerawang/screens/event_detail_screen.dart';
import 'package:mykerawang/screens/events_screen.dart';
import 'package:mykerawang/screens/marketplace_screen.dart';
import 'package:mykerawang/widgets/universal_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const HomeScreen({super.key, required this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Store the "Futures" so they don't reload on rebuilds
  late Future<List<dynamic>> _eventsFuture;
  late Future<List<dynamic>> _listingsFuture;
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
  
    // 1. FILTER PAST EVENTS
    // "gte" means Greater Than or Equal to.
    // We compare 'end_datetime' to the current time (ISO string).
    final nowStr = DateTime.now().toUtc().toIso8601String();

    _eventsFuture = supabase
        .from('events')
        .select()
       .gte('end_datetime', nowStr) // <--- THIS LINE FIXES THE BUG
        .order('start_datetime', ascending: true)
        .limit(5);

    _listingsFuture = supabase.from('listings').select().limit(5);
    _profileFuture = _fetchUserProfile(supabase);
  }

  // Helper to keep code clean
  static Future<Map<String, dynamic>?> _fetchUserProfile(SupabaseClient supabase) async {
     try {
       final user = supabase.auth.currentUser;
       if (user == null) return null;
       return await supabase.from('profiles').select().eq('id', user.id).single();
     } catch (e) { return null; }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar (Welcome + Notifs)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    FutureBuilder(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        final profileData = snapshot.data;
                        final avatarUrl = profileData?['avatar_url'] as String?;

                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipOval(
                            child: avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    fit: BoxFit.cover,
                                    // Show spinner while loading
                                    placeholder: (context, url) => const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    // Show Person Icon if URL fails (Safe Fallback)
                                    errorWidget: (context, url, error) => Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                                  )
                                // Show Person Icon if URL is null
                                : Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    FutureBuilder(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        final fullName = (snapshot.data as Map<String, dynamic>?)?['full_name'] as String? ?? 'User';
                        return Text('Welcome, $fullName!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
                      },
                    ),
                    const Spacer(),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined), 
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          }
                        ),
                        Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle), child: const Text('3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Happening Soon Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Happening Soon", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        widget.onTabChange(2); // Switch to Events tab
                      }, 
                      child: const Text("See All")
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),

              // Events Horizontal List
              SizedBox(
                height: 240,
                child: FutureBuilder(
                  future: _eventsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final events = snapshot.data as List;
                    
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return UniversalCard(
                          data: event, 
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
                          }
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Marketplace Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("New in Marketplace", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () {
                      widget.onTabChange(1); // Switch to Marketplace tab
                    }, child: const Text("See All"))
                  ],
                ),
              ),

              // Marketplace Grid (Replicating the 2-column grid in home.html)
              FutureBuilder(
                future: _listingsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final items = snapshot.data as List;
                  
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return UniversalCard(
                        data: item, 
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: item)));
                        }
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}