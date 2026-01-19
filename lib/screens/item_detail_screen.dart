import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final sellerId = item['seller_id'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                  // 1. Zoomable Image
                  Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
                    body: PhotoView(imageProvider: NetworkImage(item['image_url'])),
                  )));
                },
                child: Image.network(item['image_url'], fit: BoxFit.cover),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(label: Text(item['category'] ?? 'General'), backgroundColor: Colors.orange[50], side: BorderSide.none),
                      Text("RM ${(item['price'] as num).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(item['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // 5. User Card (Tappable)
                  FutureBuilder(
                    future: Supabase.instance.client.from('profiles').select().eq('id', sellerId).single(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final user = snapshot.data as Map;
                      return GestureDetector(
                        // Tap to view user profile (reusing ProfileScreen logic/UI in a new wrapper or passing ID)
                        // For simplicity, we just show a snackbar or navigate to a public profile view
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Profile View coming next")));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white, // 6. Lining
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(backgroundImage: NetworkImage(user['avatar_url'] ?? '')),
                              const SizedBox(width: 12),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(user['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(user['role'] == 'club' ? 'Club Organizer' : 'Student', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ]),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(item['description'] ?? ''),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          )
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: () async {
             // WhatsApp Logic
             final url = Uri.parse("https://wa.me/?text=Hi, I am interested in ${item['title']}");
             if (await canLaunchUrl(url)) launchUrl(url);
          }, 
          icon: const Icon(Icons.message),
          label: const Text("Contact Seller"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        ),
      ),
    );
  }
}