import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:mykerawang/services/share_service.dart';
import 'package:mykerawang/utils/report_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'create_listing_screen.dart'; 
import 'create_post_screen.dart'; // Ensure this exists
import 'profile_screen.dart'; 
import 'gallery_view_screen.dart';

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
  int _currentImageIndex = 0; 

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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error refreshing item: $e");
    }
  }

  // --- TOGGLE SOLD STATUS ---
  Future<void> _toggleSoldStatus() async {
    final currentStatus = _itemData['is_sold'] ?? false;
    final newStatus = !currentStatus;

    // Optimistic Update
    setState(() => _itemData['is_sold'] = newStatus);

    try {
      await Supabase.instance.client
          .from('listings')
          .update({'is_sold': newStatus})
          .eq('id', _itemData['id']);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus ? "Marked as Sold" : "Marked as Available"))
      );
    } catch (e) {
      // Revert if error
      setState(() => _itemData['is_sold'] = currentStatus);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this listing permanently?"),
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
          Navigator.pop(context, true); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Listing deleted")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _saveQR(String url) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saving QR..."), duration: Duration(seconds: 1)));
      
      // 1. Download bytes using existing http package
      final response = await http.get(Uri.parse(url));
      
      // 2. Save to Gallery
      await Gal.putImageBytes(response.bodyBytes);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR Saved to Gallery!")));
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not save image. Check permissions.")));
    }
  }
  
  Future<void> _showPurchaseDialog() async {
    if (_sellerProfile == null) return;

    final qrUrl = _sellerProfile!['payment_qr_url'];
    final phone = _sellerProfile!['phone_number'];
    final sellerName = _sellerProfile!['username'] ?? "Seller";

    // Track state LOCALLY inside this function logic
    bool isSaving = false;
    bool isSaved = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        // 'setModalState' allows us to rebuild ONLY this bottom sheet
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Contact Seller", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Buying from @$sellerName", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                if (qrUrl != null) ...[
                  const Text("DuitNow QR", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 200, width: 200,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
                    child: CachedNetworkImage(
                      imageUrl: qrUrl,
                      fit: BoxFit.cover,
                      placeholder: (_,__) => const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  
                  // --- SAVE BUTTON (Fixed) ---
                  TextButton.icon(
                    onPressed: (isSaving || isSaved) 
                      ? null // Disable if busy or done
                      : () async {
                          // 1. Update UI to "Saving..."
                          setModalState(() => isSaving = true);

                          try {
                            // 2. Download & Save
                            final response = await http.get(Uri.parse(qrUrl));
                            await Gal.putImageBytes(response.bodyBytes);
                            
                            // 3. Update UI to "Success"
                            setModalState(() {
                              isSaving = false;
                              isSaved = true;
                            });
                          } catch (e) {
                            debugPrint("Save error: $e");
                            setModalState(() => isSaving = false);
                          }
                        },
                    // Dynamic Icon
                    icon: isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : Icon(isSaved ? Icons.check_circle : Icons.save_alt, color: isSaved ? Colors.green : null),
                    // Dynamic Text
                    label: Text(
                      isSaving ? "Saving..." : (isSaved ? "Saved to Gallery!" : "Save to Gallery"),
                      style: TextStyle(
                        color: isSaved ? Colors.green : null, 
                        fontWeight: isSaved ? FontWeight.bold : null
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text("Screenshot & Scan to Pay", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 24),
                ],

                // 2. WHATSAPP BUTTON (Keep your existing one)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text("Chat on WhatsApp"),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                       // ... (Paste your existing WhatsApp logic here) ...
                       // Short version for context:
                       if (phone != null && phone.isNotEmpty) {
                         // ShareService.openWhatsApp(...);
                       }
                    },
                  ),
                ),
                
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
              ],
            ),
          );
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwner = currentUser != null && currentUser.id == _itemData['seller_id'];
    final isSold = _itemData['is_sold'] == true;

    final List<String> allImages = [
      if (_itemData['image_url'] != null) _itemData['image_url'],
      ...?(_itemData['gallery_urls'] as List?)?.cast<String>(),
    ];

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
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: allImages.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => GalleryViewScreen(galleryItems: allImages, initialIndex: index)));
                        },
                        child: Hero(
                          tag: index == 0 ? _itemData['id'] : "gallery_$index", 
                          child: CachedNetworkImage(
                            imageUrl: allImages[index],
                            fit: BoxFit.cover,
                            color: isSold ? Colors.grey : null,
                            colorBlendMode: isSold ? BlendMode.saturation : null,
                            placeholder: (_,__) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (_,__,___) => Container(color: Colors.grey, child: const Icon(Icons.broken_image, color: Colors.white)),
                          ),
                        ),
                      );
                    },
                  ),
                  if (isSold)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black38,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), color: Colors.red.withOpacity(0.8)),
                            child: const Text("SOLD", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
                          ),
                        ),
                      ),
                    ),
                  if (allImages.length > 1)
                    Positioned(
                      bottom: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text("${_currentImageIndex + 1} / ${allImages.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
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
                      Text("RM ${(_itemData['price'] ?? 0).toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text(_itemData['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                      IconButton(
                        icon: const CircleAvatar(backgroundColor: Colors.black45, child: Icon(Icons.share, color: Colors.white, size: 20)),
                        onPressed: () {
                          ShareService.shareContent(context, _itemData['title'], "Price: RM ${_itemData['price']}\n${_itemData['description'] ?? ''}", _itemData['image_url']);
                        },
                      ),
                      PopupMenuButton<String>(
                        icon: const CircleAvatar(
                          backgroundColor: Colors.black45, 
                          child: Icon(Icons.more_vert, color: Colors.white)
                        ),
                        onSelected: (val) {
                          // Change 'listing' to 'event' depending on the screen
                          showReportDialog(context, _itemData['id'], 'listing'); 
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'report',
                            child: Text("Report this content", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_sellerProfile != null)
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: _sellerProfile!['id']))),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)), borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.surfaceContainer),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundImage: _sellerProfile!['avatar_url'] != null ? CachedNetworkImageProvider(_sellerProfile!['avatar_url']) : null, child: _sellerProfile!['avatar_url'] == null ? const Icon(Icons.person) : null),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_sellerProfile!['display_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text("View Profile", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                            ]),
                            const Spacer(),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  
                  // --- NEW POST FUNCTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      TextButton.icon(
                        onPressed: () {
                          // Requires updating CreatePostScreen to accept 'sharedListing'
                          // Use a Try-Catch or ensure CreatePostScreen is updated
                          try {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(sharedListing: _itemData))); 
                          } catch (e) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please update CreatePostScreen first!")));
                          }
                        },
                        icon: const Icon(Icons.repeat, size: 16),
                        label: const Text("Repost"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_itemData['description'] ?? 'No description provided.'),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          )
        ],
      ),
      
      // --- OWNER CONTROLS ---
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
                  // 1. MARK SOLD BUTTON
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _toggleSoldStatus,
                      style: OutlinedButton.styleFrom(
                        // If sold: Green text (to make available), If available: Orange text (to mark sold)
                        foregroundColor: isSold ? Colors.green : Colors.orange, 
                        side: BorderSide(color: isSold ? Colors.green : Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(isSold ? "Mark Available" : "Mark as Sold"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 2. EDIT BUTTON
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateListingScreen(itemToEdit: _itemData)));
                        if (result == true) _refreshData(); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Edit"),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. DELETE ICON (Small, beside edit)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: "Delete Permanently",
                      onPressed: _deleteItem,
                    ),
                  ),
                ],
              )
            // BUYER VIEW
            : ElevatedButton.icon(
                onPressed: isSold ? null : _showPurchaseDialog, 
                icon: const Icon(Icons.chat),
                label: Text(isSold ? "Item Sold" : "Contact / Buy"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSold ? Colors.grey : Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
      ),
    );
  }
}