import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'item_detail_screen.dart';
import 'event_detail_screen.dart';
import 'profile_cubit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit(),
      child: const ProfileView(),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red));
        }
      },
      builder: (context, state) {
        final profile = state.profile;
        if (state.isLoading && profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (profile == null) return const Scaffold(body: Center(child: Text("Profile not found")));

        return Scaffold(
          appBar: AppBar(
            title: const Text("My Profile"),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              )
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // --- PROFILE HEADER ---
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(profile['avatar_url'] ?? 'https://via.placeholder.com/150'),
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(height: 16),
                      Text(profile['full_name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(profile['role'] == 'student' ? 'UiTM Student' : 'Club Admin', style: const TextStyle(color: Colors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text(profile['bio'] ?? 'No bio yet', textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () {
                           final cubit = context.read<ProfileCubit>();
                           Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(value: cubit, child: const EditProfileScreen())));
                        },
                        child: const Text("Edit Profile"),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // --- MARKETPLACE SECTION ---
                _sectionTitle("My Market Listings"),
                if (state.listings.isEmpty)
                  _emptyState("No items listed yet")
                else
                  SizedBox(
                    height: 190,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: state.listings.length,
                      itemBuilder: (context, index) {
                        final item = state.listings[index];
                        return _buildHorizontalCard(
                          context, 
                          imageUrl: item['image_url'], 
                          title: item['title'], 
                          subtitle: "RM ${item['price']}",
                          onTap: () async {
                             await Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
                             if (context.mounted) context.read<ProfileCubit>().loadProfile(); 
                          }
                        );
                      },
                    ),
                  ),

                const Divider(height: 50, thickness: 8, color: Color(0xFFF5F5F5)), 

                // --- EVENTS SECTION ---
                _sectionTitle("My Hosted Events"),
                if (state.events.isEmpty)
                  _emptyState("No events created yet")
                else
                  SizedBox(
                    height: 190, 
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: state.events.length,
                      itemBuilder: (context, index) {
                        final event = state.events[index]; // <--- 'event' is defined HERE
                        return _buildHorizontalCard(
                          context, 
                          imageUrl: event['image_url'], 
                          title: event['title'], 
                          subtitle: event['start_datetime'] ?? 'Event',
                          // --- THE LOGIC GOES HERE, NOT AT THE BOTTOM ---
                          onTap: () async {
                             await Navigator.push(
                               context, 
                               MaterialPageRoute(
                                 builder: (_) => EventDetailScreen(
                                   event: event,
                                   isOwnerOverride: true, // <--- MASTER KEY
                                 )
                               )
                             );
                             if (context.mounted) context.read<ProfileCubit>().loadProfile(); 
                          }
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _emptyState(String text) {
    return Padding(padding: const EdgeInsets.all(16), child: Text(text, style: const TextStyle(color: Colors.grey)));
  }

  // --- THIS FUNCTION IS NOW SIMPLE AGAIN ---
  Widget _buildHorizontalCard(BuildContext context, {required String? imageUrl, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap, // Just uses the function passed to it
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl ?? 'https://via.placeholder.com/150',
                height: 120, width: 150, fit: BoxFit.cover,
                errorBuilder: (_,__,___) => Container(height: 120, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}