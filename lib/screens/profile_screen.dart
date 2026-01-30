import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'item_detail_screen.dart';
import 'event_detail_screen.dart';
import 'profile_cubit.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileView();
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Wrap everything in DefaultTabController
    return DefaultTabController(
      length: 2, // We have 2 tabs: Market & Events
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Profile"),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state.isLoading) return const Center(child: CircularProgressIndicator());
            if (state.errorMessage != null) {
              return Center(child: Text(state.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)));
            }
            if (state.profile == null) return const Center(child: Text("Profile not found"));

            final profile = state.profile!;
            
            return NestedScrollView(
              // 2. The Header stays visible (or scrolls away if you prefer)
              headerSliverBuilder: (context, _) {
                return [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _buildProfileHeader(context, profile),
                    ]),
                  ),
                ];
              },
              // 3. The Body holds the Tabs
              body: Column(
                children: [
                  // --- THE TABS ---
                  TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on), text: "Listings"),
                      Tab(icon: Icon(Icons.calendar_month_outlined), text: "Events"),
                    ],
                  ),
                  
                  // --- THE VIEWS ---
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildMarketGrid(state.listings),
                        _buildEventsList(state.events),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 1. HEADER SECTION ---
  Widget _buildProfileHeader(BuildContext context, Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: profile['avatar_url'] != null
                ? CachedNetworkImageProvider(profile['avatar_url'])
                : null,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: profile['avatar_url'] == null 
                ? Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.onSurfaceVariant) 
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            profile['full_name'] ?? 'No Name',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            profile['role'] == 'student' ? 'UiTM Student' : 'Club Admin',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 20),
          // Edit Profile Button (Optional)
          OutlinedButton(
            onPressed: () {
               // Navigation to Edit Profile Screen
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Edit Profile"),
          ),
        ],
      ),
    );
  }

  // --- 2. MARKET GRID (Instagram Style) ---
  Widget _buildMarketGrid(List<dynamic> listings) {
    if (listings.isEmpty) return _emptyState("No active listings");

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      itemCount: listings.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 items per row
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1, // Square tiles
      ),
      itemBuilder: (context, index) {
        final item = listings[index];
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))
            );
            // Refresh on return
            if (context.mounted) context.read<ProfileCubit>().loadProfile();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item['image_url'] ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
              ),
              // Price Tag Overlay
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "RM${item['price']}",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // --- 3. EVENTS LIST (Vertical Cards) ---
  Widget _buildEventsList(List<dynamic> events) {
    if (events.isEmpty) return _emptyState("No upcoming events");

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        
        // Date Formatting
        String dateString = 'Event';
        if (event['start_datetime'] != null) {
           final date = DateTime.parse(event['start_datetime']).toLocal();
           dateString = DateFormat('d MMM, h:mm a').format(date);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainer, // Darker card in light mode
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: event['image_url'] ?? '',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (_,__,___) => const Icon(Icons.event),
              ),
            ),
            title: Text(event['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(dateString, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            onTap: () async {
              await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => EventDetailScreen(event: event, isOwnerOverride: true))
              );
              if (context.mounted) context.read<ProfileCubit>().loadProfile();
            },
          ),
        );
      },
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear, size: 48, color: Theme.of(context as BuildContext).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Theme.of(context as BuildContext).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

}