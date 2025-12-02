import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  Future<void> _launchWhatsApp(String phone, String message) async {
    // Basic formatting to remove non-digits
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse("https://wa.me/6$cleanPhone?text=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback or error handling
      debugPrint("Could not launch WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fetch seller details if not included in the 'item' map
    // Assuming 'listings' table has a 'seller_id' foreign key linked to 'profiles'
    final supabase = Supabase.instance.client;
    final marketplaceColor = const Color(0xFFec7f13);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // 1. Sliver App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black, // Back button color
            flexibleSpace: FlexibleSpaceBar(
              background: item['image_url'] != null
                  ? Image.network(
                      item['image_url'],
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // Implement share functionality
                },
              ),
            ],
          ),

          // 2. Content Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item['title'] ?? 'Untitled Item',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Price
                  Text(
                    'RM ${(item['price'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 28, color: marketplaceColor, fontWeight: FontWeight.w800),
                  ),

                  const SizedBox(height: 20),

                  // Chips (Category, Condition)
                  Row(
                    children: [
                      _buildChip(item['category'] ?? 'General', false),
                      const SizedBox(width: 8),
                      if (item['condition'] != null)
                        _buildChip(item['condition'], true),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Description
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    item['description'] ?? 'No description provided.',
                    style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
                  ),

                  const SizedBox(height: 32),

                  // Seller Info (FutureBuilder to fetch profile based on seller_id)
                  FutureBuilder(
                    future: supabase.from('profiles').select().eq('id', item['seller_id']).single(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const ListTile(
                          leading: CircleAvatar(child: Icon(Icons.person)),
                          title: Text("Loading seller..."),
                        );
                      }

                      final seller = snapshot.data as Map<String, dynamic>;
                      final sellerName = seller['full_name'] ?? 'Unknown Seller';
                      final sellerPhone = seller['phone_number'];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: seller['avatar_url'] != null 
                                ? NetworkImage(seller['avatar_url']) 
                                : null,
                              child: seller['avatar_url'] == null 
                                ? Text(sellerName[0].toUpperCase()) 
                                : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sellerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    "Student • Joined 2024", // Placeholder logic
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                // Navigate to seller profile
                              },
                              icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      
      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: SafeArea(
          child: FutureBuilder(
            // Fetch seller phone again or pass it down
             future: supabase.from('profiles').select('phone_number').eq('id', item['seller_id']).single(),
             builder: (context, snapshot) {
               final phone = snapshot.data?['phone_number'];
               
               return ElevatedButton.icon(
                onPressed: phone != null ? () {
                  _launchWhatsApp(phone, "Hi, I'm interested in your listing: ${item['title']}");
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("Contact on WhatsApp", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              );
             }
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFec7f13).withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPrimary ? const Color(0xFFec7f13) : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}