import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_listing_screen.dart';
import 'item_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Books', 'Electronics', 'Food', 'Services', 'Clothing'];

  // Stream to listen to database changes in real-time
  Stream<List<Map<String, dynamic>>> _listingsStream() {
    final supabase = Supabase.instance.client;
    
    // Start building the query
    var query = supabase.from('listings').stream(primaryKey: ['id']);

    // Note: Supabase Stream filtering is limited. 
    // For complex filtering (Search + Category), it's often better to fetch 
    // and filter in memory for small datasets, or use .select() with modifiers for large ones.
    // Here we will filter the stream results in the builder for simplicity and reactivity.
    return query;
  }

  @override
  Widget build(BuildContext context) {
    // Marketplace specific color (Orange from item_detail.html)
    final marketplaceColor = const Color(0xFFec7f13);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Marketplace'),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement advanced filters (Price range, Condition)
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() {}), // Trigger rebuild to filter
              decoration: InputDecoration(
                hintText: 'Search for textbooks, food...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                // Subtle shadow
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          // 2. Category Chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                  selectedColor: marketplaceColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? marketplaceColor : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.white,
                  side: isSelected ? BorderSide(color: marketplaceColor) : BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // 3. Listings Grid
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _listingsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Client-side Filtering
                var listings = snapshot.data!;
                
                // Filter by Category
                if (_selectedCategory != 'All') {
                  listings = listings.where((item) => item['category'] == _selectedCategory).toList();
                }

                // Filter by Search Text
                if (_searchController.text.isNotEmpty) {
                  final query = _searchController.text.toLowerCase();
                  listings = listings.where((item) {
                    final title = (item['title'] ?? '').toString().toLowerCase();
                    final desc = (item['description'] ?? '').toString().toLowerCase();
                    return title.contains(query) || desc.contains(query);
                  }).toList();
                }

                if (listings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No items found', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Bottom padding for FAB
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75, // Matches the vertical card aspect ratio
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final item = listings[index];
                    return _buildListingCard(context, item, marketplaceColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateListingScreen()),
          );
        },
        backgroundColor: marketplaceColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Sell Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildListingCard(BuildContext context, Map<String, dynamic> item, Color accentColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item['image_url'] != null
                      ? Image.network(item['image_url'], fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[100],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                  // "New" or "Used" Tag overlay
                  if (item['condition'] != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['condition'],
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['category']?.toString().toUpperCase() ?? 'ITEM',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['title'] ?? 'No Title',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${(item['price'] ?? 0).toString()}',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}