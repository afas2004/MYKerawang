import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'create_listing_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  // We allow passing an ID optionally if we just want to load by ID later
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Map<String, dynamic> _itemData;
  bool _isLoading = false;
  Map<String, dynamic>? _sellerProfile;

  @override
  void initState() {
    super.initState();
    // Start with the data passed in
    _itemData = widget.item;
    // Then fetch fresh data (including seller profile)
    _refreshData();
  }

  Future<void> _refreshData() async {
    try {
      final supabase = Supabase.instance.client;
      
      // 1. Fetch fresh item details
      final freshItem = await supabase
          .from('listings')
          .select()
          .eq('id', _itemData['id'])
          .single();

      // 2. Fetch Seller Profile
      final seller = await supabase
          .from('profiles')
          .select()
          .eq('id', freshItem['seller_id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _itemData = freshItem;
          _sellerProfile = seller;
        });
      }
    } catch (e) {
      debugPrint("Error refreshing item: $e");
    }
  }

  Future<void> _deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this listing?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('listings').delete().eq('id', _itemData['id']);
        if (mounted) {
          Navigator.pop(context, true); // Return true to refresh previous screen
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Listing deleted")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwner = currentUser != null && currentUser.id == _itemData['seller_id'];

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
                    body: PhotoView(imageProvider: NetworkImage(_itemData['image_url'] ?? '')),
                  )));
                },
                child: CachedNetworkImage(
                  imageUrl: _itemData['image_url'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                ),
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
                      Chip(label: Text(_itemData['category'] ?? 'General'), backgroundColor: Colors.orange[50], side: BorderSide.none),
                      Text("RM ${(_itemData['price'] as num).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_itemData['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Seller Card (Now uses loaded state)
                  if (_sellerProfile != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12), color: Colors.white),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: _sellerProfile!['avatar_url'] != null
                            ? CachedNetworkImageProvider(_sellerProfile!['avatar_url'])
                            : null,
                            onBackgroundImageError: (_,__) {},
                            child: _sellerProfile!['avatar_url'] == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_sellerProfile!['full_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(_sellerProfile!['role'] == 'club' ? 'Club Organizer' : 'Student', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
                    
                  const SizedBox(height: 20),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_itemData['description'] ?? 'No description provided.'),
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
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, -2))]),
        child: isOwner
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deleteItem,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text("Delete"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Navigate to Edit
                        final result = await Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => CreateListingScreen(itemToEdit: _itemData))
                        );
                        // If we saved changes, refresh this screen
                        if (result == true) {
                           _refreshData();
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
                  final url = Uri.parse("https://wa.me/?text=Hi, I am interested in ${_itemData['title']}");
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