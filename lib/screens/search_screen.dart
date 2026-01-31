import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'event_detail_screen.dart';
import 'item_detail_screen.dart';
import '../widgets/universal_card.dart'; // Uncomment if you created this file

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _activeFilter = 'All'; // Options: All, People, Events, Market

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Wait 500ms before hitting the database (Save API calls)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        setState(() => _query = query);
        _performSearch();
      } else {
        setState(() {
          _query = '';
          _results = [];
        });
      }
    });
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    
    List<Map<String, dynamic>> tempResults = [];
    final q = "%$_query%"; // SQL Wildcard for "contains"

    try {
      // 1. Search PROFILES (People)
      if (_activeFilter == 'All' || _activeFilter == 'People') {
        final people = await _supabase.from('profiles')
            .select('id, full_name, avatar_url, role')
            .ilike('full_name', q)
            .limit(5);
            
        for (var p in people) {
          tempResults.add({...p, 'type': 'person'});
        }
      }

      // 2. Search EVENTS
      if (_activeFilter == 'All' || _activeFilter == 'Events') {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final events = await _supabase.from('events')
            .select()
            .ilike('title', q)
            .gte('end_datetime', nowStr) // Only future events
            .limit(5);
            
        for (var e in events) {
          tempResults.add({...e, 'type': 'event'});
        }
      }

      // 3. Search MARKETPLACE
      if (_activeFilter == 'All' || _activeFilter == 'Market') {
        final items = await _supabase.from('listings')
            .select()
            .ilike('title', q)
            .eq('is_sold', false) // Only unsold items
            .limit(5);
            
        for (var i in items) {
          tempResults.add({...i, 'type': 'market'});
        }
      }

      // 4. Shuffle mixed results so they don't look grouped strictly by table
      if (_activeFilter == 'All') tempResults.shuffle();

      if (mounted) {
        setState(() {
          _results = tempResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Search Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Search UiTM...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            suffixIcon: _query.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear), 
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  }
                ) 
              : null,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: Column(
        children: [
          // --- FILTER CHIPS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: ['All', 'People', 'Events', 'Market'].map((filter) {
                final isSelected = _activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _activeFilter = filter;
                        // Re-run search immediately if we already have a query
                        if (_query.isNotEmpty) _performSearch();
                      });
                    },
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected 
                        ? Theme.of(context).colorScheme.onPrimaryContainer 
                        : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // --- RESULTS LIST ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64, color: Theme.of(context).dividerColor),
                          const SizedBox(height: 16),
                          Text(
                            _query.isEmpty ? "Start typing to search" : "No results found",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (_,__) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        final type = item['type'];

                        // RENDER DIFFERENT CARDS BASED ON TYPE
                        if (type == 'person') return _buildPersonCard(item);
                        return _buildContentCard(item, type);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Person Card ---
  Widget _buildPersonCard(Map<String, dynamic> item) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: item['avatar_url'] != null 
            ? CachedNetworkImageProvider(item['avatar_url']) 
            : null,
        child: item['avatar_url'] == null ? const Icon(Icons.person) : null,
      ),
      title: Text(item['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(item['role'] == 'student' ? 'Student' : 'Club/Admin'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Navigate to a generic "Public Profile" screen (To be built later?)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile view coming soon!")));
      },
    );
  }

  // --- WIDGET: Event/Market Card (Reusing your style) ---
  Widget _buildContentCard(Map<String, dynamic> item, String type) {
    final isEvent = type == 'event';
    final title = item['title'] ?? 'No Title';
    final image = item['image_url'];
    final subtitle = isEvent 
        ? (item['start_datetime'] != null 
            ? DateFormat('d MMM, h:mm a').format(DateTime.parse(item['start_datetime']).toLocal()) 
            : 'Date TBA')
        : "RM ${(item['price'] ?? 0).toStringAsFixed(2)}";

    return GestureDetector(
      onTap: () {
        if (isEvent) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: item)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
        }
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Row(
          children: [
            // Image Section
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: SizedBox(
                width: 100,
                height: 100,
                child: image != null
                    ? CachedNetworkImage(
                        imageUrl: image, 
                        fit: BoxFit.cover,
                        placeholder: (_,__) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                        errorWidget: (_,__,___) => const Icon(Icons.broken_image),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(isEvent ? Icons.event : Icons.store, color: Colors.grey),
                      ),
              ),
            ),
            // Text Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge (Event or Market)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEvent 
                            ? Theme.of(context).colorScheme.primaryContainer 
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isEvent ? 'EVENT' : 'MARKET',
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: isEvent 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}