import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

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
                      future: _fetchUserProfile(supabase),
                      builder: (context, snapshot) {
                        final profileData = snapshot.data as Map<String, dynamic>?;
                        final avatarUrl = profileData?['avatar_url'] as String?;

                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                          ),
                          child: ClipOval(
                            child: avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    // Show spinner while loading
                                    placeholder: (context, url) => const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    // Show Person Icon if URL fails (Safe Fallback)
                                    errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey),
                                  )
                                // Show Person Icon if URL is null
                                : const Icon(Icons.person, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    FutureBuilder(
                      future: _fetchUserProfile(supabase),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text("Happening Soon", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 12),

              // Events Horizontal List
              SizedBox(
                height: 240,
                child: FutureBuilder(
                  future: supabase.from('events').select().limit(5),
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
                        return Container(
                          width: 260,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: CachedNetworkImage(
                                  imageUrl: event['image_url'] ?? '',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200], 
                                    child: const Center(child: CircularProgressIndicator())
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200], 
                                    child: const Icon(Icons.broken_image, color: Colors.grey)
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(event['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
  DateFormat('d MMM y, h:mm a').format(
    DateTime.parse(event['start_datetime']).toLocal()
  ),
  style: TextStyle(
    color: Theme.of(context).primaryColor, 
    fontWeight: FontWeight.bold, 
    fontSize: 12
  ),
)
                                  ],
                                ),
                              )
                            ],
                          ),
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
                    TextButton(onPressed: () {}, child: const Text("See All"))
                  ],
                ),
              ),

              // Marketplace Grid (Replicating the 2-column grid in home.html)
              FutureBuilder(
                future: supabase.from('listings').select().limit(4),
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
                      return Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CachedNetworkImage(
                                imageUrl: item['image_url'] ?? '',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) => const Icon(Icons.store, color: Colors.grey),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text("RM ${item['price']}", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
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

  static Future<Map<String, dynamic>?> _fetchUserProfile(SupabaseClient supabase) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      
      final profileData = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      return profileData;
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      return null;
    }
  }
}