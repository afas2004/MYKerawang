import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    // Handle edge case where user might be null unexpectedly
    if (user == null) return const Center(child: Text("Not Logged In"));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: FutureBuilder(
        // Fetch Real Profile Data
        future: Supabase.instance.client.from('profiles').select().eq('id', user.id).single(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final profile = snapshot.data as Map;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(radius: 60, backgroundImage: NetworkImage(profile['avatar_url'] ?? 'https://via.placeholder.com/150')),
                const SizedBox(height: 16),
                Text(profile['full_name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(profile['role'] == 'student' ? 'UiTM Student' : 'Club Admin', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  child: const Text("Edit Profile"),
                ),
                const SizedBox(height: 20),
                // Display User's Listings
                const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text("My Listings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
                SizedBox(
                  height: 200,
                  child: FutureBuilder(
                    future: Supabase.instance.client.from('listings').select().eq('seller_id', user.id),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const Center(child: Text("Loading..."));
                      final items = snap.data as List;
                      if (items.isEmpty) return const Center(child: Text("No active listings"));
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (c, i) => Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Image.network(items[i]['image_url'] ?? '', fit: BoxFit.cover, width: double.infinity)),
                              Padding(padding: const EdgeInsets.all(8), child: Text(items[i]['title'], maxLines: 1, overflow: TextOverflow.ellipsis))
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}