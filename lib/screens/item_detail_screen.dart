import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this to pubspec.yaml
import 'create_listing_screen.dart'; // Ensure this matches your filename
import 'profile_screen.dart'; 
import 'image_preview_screen.dart'; 

class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Map<String, dynamic> _itemData;
  Map<String, dynamic>? _sellerProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _itemData = widget.item;
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

      // 2. Fetch Seller Profile (needed for WhatsApp/QR)
      final seller = await supabase
          .from('profiles')
          .select() // Get everything (payment_qr_url, phone_number, etc.)
          .eq('id', freshItem['seller_id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _itemData = freshItem;
          _sellerProfile = seller;
          _isLoading = false;
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

  Future<void> _showPurchaseDialog() async {
    if (_sellerProfile == null) return;

    final qrUrl = _sellerProfile!['payment_qr_url'];
    final phone = _sellerProfile!['phone_number'];
    final sellerName = _sellerProfile!['username'] ?? "Seller";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Contact Seller", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Buying from @$sellerName", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // 1. QR CODE SECTION
            if (qrUrl != null) ...[
              const Text("DuitNow QR", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
                child: CachedNetworkImage(
                  imageUrl: qrUrl,
                  fit: BoxFit.cover,
                  placeholder: (_,__) => const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 8),
              const Text("Screenshot & Scan to Pay", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
            ],

            // 2. WHATSAPP BUTTON
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text("Chat on WhatsApp"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green, // WhatsApp Green
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  if (phone == null || phone.isEmpty) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seller hasn't provided a phone number.")));
                    return;
                  }

                  // Format number for WhatsApp API
                  final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
                  final message = "Hi, I am interested in your item: ${_itemData['title']}";
                  final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open WhatsApp")));
                    }
                  }
                },
              ),
            ),
            
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ],
        ),
      ),
    );
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
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                  // Navigate to your existing ImagePreviewScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImagePreviewScreen(imageUrl: _itemData['image_url'] ?? ''),
                    ),
                  );
                },
                child: Hero(
                  tag: _itemData['id'], // Optional: Adds a nice zoom animation
                  child: CachedNetworkImage(
                    imageUrl: _itemData['image_url'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey, 
                      child: const Icon(Icons.broken_image, color: Colors.white)
                    ),
                  ),
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
                      Chip(
                        label: Text(_itemData['category'] ?? 'General'),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                        side: BorderSide.none,
                      ),
                      Text(
                        "RM ${(_itemData['price'] ?? 0).toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_itemData['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // SELLER CARD
                  if (_sellerProfile != null)
                    InkWell(
                      onTap: () {
                         // Navigate to Profile
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: _sellerProfile!['id'])));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: _sellerProfile!['avatar_url'] != null
                                  ? CachedNetworkImageProvider(_sellerProfile!['avatar_url'])
                                  : null,
                              child: _sellerProfile!['avatar_url'] == null ? const Icon(Icons.person) : null,
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_sellerProfile!['display_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                "View Profile",
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
                              ),
                            ]),
                            const Spacer(),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
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
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]
        ),
        child: isOwner
            ? Row(
                children: [
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
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Navigate to CreateListingScreen in EDIT MODE
                        final result = await Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => CreateListingScreen(itemToEdit: _itemData)
                          )
                        );
                        if (result == true) {
                          _refreshData(); // Refresh if updated
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text("Edit"),
                    ),
                  ),
                ],
              )
            : ElevatedButton.icon(
                onPressed: _showPurchaseDialog, // <--- CALLS THE NEW DIALOG
                icon: const Icon(Icons.chat),
                label: const Text("Contact / Buy"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
      ),
    );
  }
}