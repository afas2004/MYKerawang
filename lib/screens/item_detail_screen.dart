import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'create_listing_screen.dart'; // Import CreateListingScreen

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const ItemDetailScreen({super.key, required this.item});

  // DELETE FUNCTION
  Future<void> _deleteItem(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this listing?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('listings').delete().eq('id', item['id']);
      if (context.mounted) {
         // Return true to the Profile Screen so it refreshes
         Navigator.pop(context, true); 
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Listing deleted")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = item['seller_id'];
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwner = currentUser != null && currentUser.id == sellerId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
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
                  
                  // User Card
                  FutureBuilder(
                    future: Supabase.instance.client.from('profiles').select().eq('id', sellerId).single(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final user = snapshot.data as Map;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12), color: Colors.white),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundImage: NetworkImage(user['avatar_url'] ?? '')),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(user['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(user['role'] == 'club' ? 'Club Organizer' : 'Student', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ]),
                          ],
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
      
      // BOTTOM SHEET LOGIC
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        color: Colors.white,
        child: isOwner
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deleteItem(context),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text("Delete"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Navigate to CreateListingScreen in EDIT mode
                        final result = await Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => CreateListingScreen(itemToEdit: item)
                          )
                        );
                        // If updated (result == true), pop back to profile to refresh list
                        if (result == true && context.mounted) {
                           Navigator.pop(context, true);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      child: const Text("Update"),
                    ),
                  ),
                ],
              )
            : ElevatedButton.icon(
                onPressed: () async {
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