import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mykerawang/screens/image_preview_screen.dart';
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
    // 1. INSTANT LOAD
    _itemData = widget.item; 
    _isLoading = false; // Don't show spinner

    // 2. BACKGROUND FETCH
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
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5), // Semi-transparent dark circle
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white), // White arrow always pops
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => ImagePreviewScreen(imageUrl: _itemData['image_url'])
                    )
                  );
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
                      // 1. DYNAMIC CHIP (Matches Theme)
                      Chip(
                        label: Text(_itemData['category'] ?? 'General'),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer, 
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                        side: BorderSide.none,
                      ),
                      // 2. DYNAMIC PRICE (Matches Theme Primary Color)
                      Text(
                        "RM ${(_itemData['price'] as num).toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: Theme.of(context).colorScheme.primary, // <--- ADAPTS TO THEME
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_itemData['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // 3. SELLER CARD (Adapts to Dark Mode)
                  if (_sellerProfile != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                        // Use 'surfaceContainer' for a subtle card background in M3
                        color: Theme.of(context).colorScheme.surfaceContainer, 
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: _sellerProfile!['avatar_url'] != null
                            ? CachedNetworkImageProvider(_sellerProfile!['avatar_url'])
                            : null,
                            onBackgroundImageError: _sellerProfile!['avatar_url'] != null ? (_,__) {} : null,
                            child: _sellerProfile!['avatar_url'] == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_sellerProfile!['full_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              _sellerProfile!['role'] == 'club' ? 'Club Organizer' : 'Student', 
                              // Use 'onSurfaceVariant' for grey subtitle text
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                            ),
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
        decoration: BoxDecoration(
          // FIX: Background adapts to Dark Mode
          color: Theme.of(context).scaffoldBackgroundColor, 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]
        ),
        child: isOwner
            ? Row(
                children: [
                  // DELETE BUTTON (Use Error Color)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deleteItem,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                      ),
                      child: const Text("Delete"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // UPDATE BUTTON (Use Primary Color)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // ... existing update logic ...
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text("Update"),
                    ),
                  ),
                ],
              )
            : ElevatedButton.icon(
                onPressed: () async {
                  // ... existing contact logic ...
                },
                icon: const Icon(Icons.message),
                label: const Text("Contact Seller"),
                // CONTACT BUTTON (Use Tertiary or Primary)
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}