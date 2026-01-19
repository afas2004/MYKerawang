import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'item_detail_screen.dart';
import 'create_listing_screen.dart';
import 'marketplace_cubit.dart'; // Ensure this matches your file name

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Provide the Cubit
    return BlocProvider(
      create: (context) => MarketplaceCubit(),
      child: const MarketplaceView(),
    );
  }
}

class MarketplaceView extends StatefulWidget {
  const MarketplaceView({super.key});

  @override
  State<MarketplaceView> createState() => _MarketplaceViewState();
}

class _MarketplaceViewState extends State<MarketplaceView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final List<String> _filters = ['All', 'Books', 'Electronics', 'Food', 'Others'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Consume the State
    return BlocBuilder<MarketplaceCubit, MarketplaceState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Marketplace"),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    // Read state for selection
                    final isSelected = state.selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        // Call Cubit
                        onSelected: (v) => context.read<MarketplaceCubit>().updateFilter(filter),
                        backgroundColor: Colors.white,
                        selectedColor: Colors.orange[100],
                        checkmarkColor: Colors.orange,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchCtrl,
                        // Call Cubit on change
                        onChanged: (v) => context.read<MarketplaceCubit>().updateSearch(v),
                        decoration: InputDecoration(
                          hintText: "Search items...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Expanded(
                      // Use state.displayedItems from Cubit
                      child: state.displayedItems.isEmpty
                          ? const Center(child: Text("No items found"))
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: state.displayedItems.length,
                              itemBuilder: (context, index) {
                                final item = state.displayedItems[index];
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ItemDetailScreen(item: item))),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                            child: Image.network(
                                              item['image_url'] ?? '',
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              // ADD THIS PROTECTOR:
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(child: Icon(Icons.store_mall_directory_outlined, color: Colors.grey)),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item['title'],
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                  "RM ${(item['price'] as num).toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CreateListingScreen())),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}