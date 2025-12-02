import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Teal accent from profile.html
    final profileColor = const Color(0xFF00A99D);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Header Profile
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: profileColor, width: 4),
                      image: const DecorationImage(image: NetworkImage('https://i.pravatar.cc/300?img=9'), fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("Aina Natasha", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("2022123456 - Student", style: TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                style: OutlinedButton.styleFrom(
                  foregroundColor: profileColor,
                  side: BorderSide(color: profileColor.withOpacity(0.5)),
                  shape: const StadiumBorder(),
                ),
                child: const Text("Edit Profile"),
              ),
            ),

            const SizedBox(height: 30),

            // Tabs
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.yellow[700], // Accent Yellow from HTML
                    tabs: const [
                      Tab(text: "My Posts"),
                      Tab(text: "Saved"),
                      Tab(text: "Notifications"),
                    ],
                  ),
                  SizedBox(
                    height: 400, // Fixed height for grid demo
                    child: TabBarView(
                      children: [
                        _buildPostsGrid(),
                        const Center(child: Text("No saved items")),
                        const Center(child: Text("No notifications")),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsGrid() {
    // Dummy data from profile.html
    final posts = [
      {'title': 'Preloved Novel', 'price': 'RM 15.00', 'status': 'Active', 'image': 'https://via.placeholder.com/150/0000FF'},
      {'title': 'Career Fair', 'price': 'Free', 'status': 'Upcoming', 'image': 'https://via.placeholder.com/150/FF0000'},
      {'title': 'Arduino Kit', 'price': 'RM 50.00', 'status': 'Sold', 'image': 'https://via.placeholder.com/150/00FF00'},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemBuilder: (context, index) {
        final post = posts[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(image: NetworkImage(post['image']!), fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(post['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1),
            Text(post['price']!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(post['status']!, style: TextStyle(fontSize: 11, color: post['status'] == 'Sold' ? Colors.red : Colors.green)),
          ],
        );
      },
    );
  }
}