import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'event_detail_screen.dart';
import 'item_detail_screen.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart'; // Ensure this exists

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
  String _activeFilter = 'All'; // Options: All, People, Events, Market, Posts
  
  // Pagination State
  int _searchLimit = 10;
  bool _hasMore = true; // Simple check to see if we hit the limit

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Wait 500ms before hitting the database (Optimization)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        setState(() {
          _query = query;
          _searchLimit = 10; // Reset limit on new search
          _hasMore = true;
        });
        _performSearch();
      } else {
        setState(() {
          _query = '';
          _results = [];
        });
      }
    });
  }

  Future<void> _loadMore() async {
    setState(() {
      _searchLimit += 10;
    });
    await _performSearch();
  }

  Future<void> _performSearch() async {
    if (_query.isEmpty) return;
    setState(() => _isLoading = true);
    
    List<Map<String, dynamic>> tempResults = [];
    final q = "%$_query%";
    // Split limit across categories if "All" is selected to ensure variety
    final int limitPerCategory = _activeFilter == 'All' ? (_searchLimit ~/ 4) + 2 : _searchLimit;

    // Track IDs for Contextual Post Search
    List<String> foundEventIds = [];
    List<String> foundListingIds = [];

    try {
      // 1. Search PROFILES
      if (_activeFilter == 'All' || _activeFilter == 'People') {
        final people = await _supabase.from('profiles')
            .select('id, full_name, display_name, avatar_url, role')
            .or('full_name.ilike.$q, display_name.ilike.$q')
            .limit(limitPerCategory);
            
        for (var p in people) {
          tempResults.add({...p, 'type': 'person'});
        }
      }

      // 2. Search EVENTS
      if (_activeFilter == 'All' || _activeFilter == 'Events' || _activeFilter == 'Posts') {
        final nowStr = DateTime.now().toUtc().toIso8601String();
        final events = await _supabase.from('events')
            .select('id, title, start_datetime, image_url')
            .ilike('title', q)
            .gte('end_datetime', nowStr)
            .limit(limitPerCategory);
            
        for (var e in events) {
          if (_activeFilter != 'Posts') tempResults.add({...e, 'type': 'event'});
          foundEventIds.add(e['id']); 
        }
      }

      // 3. Search MARKETPLACE
      if (_activeFilter == 'All' || _activeFilter == 'Market' || _activeFilter == 'Posts') {
        final items = await _supabase.from('listings')
            .select('id, title, price, image_url, is_sold')
            .ilike('title', q)
            .eq('is_sold', false)
            .limit(limitPerCategory);
            
        for (var i in items) {
          if (_activeFilter != 'Posts') tempResults.add({...i, 'type': 'market'});
          foundListingIds.add(i['id']); 
        }
      }

      // 4. Search POSTS (Direct + Contextual)
      if (_activeFilter == 'All' || _activeFilter == 'Posts') {
        // Build robust filter: matches body OR matches related event/item
        String postFilter = 'title.ilike.$q, body.ilike.$q';
        
        if (foundEventIds.isNotEmpty) {
          postFilter += ', shared_event_id.in.(${foundEventIds.join(',')})';
        }
        if (foundListingIds.isNotEmpty) {
          postFilter += ', shared_listing_id.in.(${foundListingIds.join(',')})';
        }

        final posts = await _supabase.from('posts')
            // Fetch related data to show nice titles
            .select('*, profiles(display_name, avatar_url), events(title), listings(title)') 
            .or(postFilter)
            .order('created_at', ascending: false)
            .limit(limitPerCategory);

        for (var p in posts) {
          // Smart Title Generation
          String displayTitle = p['title'] ?? "Post";
          if ((p['title'] == null || p['title'].toString().trim().isEmpty)) {
            if (p['events'] != null) displayTitle = "Re: ${p['events']['title']}";
            else if (p['listings'] != null) displayTitle = "Re: ${p['listings']['title']}";
          }

          tempResults.add({
            ...p, 
            'type': 'post',
            'title': displayTitle,
          });
        }
      }

      // Shuffle for discovery feel if "All"
      if (_activeFilter == 'All') tempResults.shuffle();

      if (mounted) {
        setState(() {
          _results = tempResults;
          _isLoading = false;
          // If we got fewer results than we asked for, we probably hit the end
          _hasMore = tempResults.length >= _searchLimit; 
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
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search posts, people, items...',
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
              children: ['All', 'Posts', 'People', 'Events', 'Market'].map((filter) {
                final isSelected = _activeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _activeFilter = filter;
                        // Reset pagination on filter change
                        _searchLimit = 10;
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
            child: _isLoading && _results.isEmpty 
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
                      itemCount: _results.length + 1, // +1 for Show More button
                      separatorBuilder: (_,__) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        // --- SHOW MORE BUTTON (At the end) ---
                        if (index == _results.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: _isLoading 
                              ? const Center(child: CircularProgressIndicator())
                              : TextButton(
                                  onPressed: _loadMore,
                                  child: const Text("Show More Results"),
                                ),
                          );
                        }

                        final item = _results[index];
                        final type = item['type'];

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
      title: Text(item['display_name'] ?? item['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(item['role'] == 'student' ? 'Student' : 'Club/Admin'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: item['id']))
        );
      },
    );
  }

  // --- WIDGET: Content Card (Event, Market, Post) ---
  Widget _buildContentCard(Map<String, dynamic> item, String type) {
    final isEvent = type == 'event';
    final isPost = type == 'post';
    
    final title = item['title'] ?? 'No Content';
    final image = item['image_url'];
    
    String subtitle;
    String badgeLabel;
    Color badgeColor;
    IconData placeholderIcon;

    if (isEvent) {
      subtitle = item['start_datetime'] != null 
          ? DateFormat('d MMM, h:mm a').format(DateTime.parse(item['start_datetime']).toLocal()) 
          : 'Date TBA';
      badgeLabel = 'EVENT';
      badgeColor = Theme.of(context).colorScheme.primary;
      placeholderIcon = Icons.event;
    } else if (isPost) {
      // For posts, show who posted it
      final author = item['profiles']?['display_name'] ?? 'Anonymous';
      subtitle = "Posted by $author"; 
      badgeLabel = 'POST';
      badgeColor = Colors.blueGrey;
      placeholderIcon = Icons.article;
    } else {
      // Market
      subtitle = "RM ${(item['price'] ?? 0).toStringAsFixed(2)}";
      badgeLabel = 'MARKET';
      badgeColor = Colors.orange;
      placeholderIcon = Icons.store;
    }

    return GestureDetector(
      onTap: () {
        if (isEvent) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: item)));
        } else if (isPost) {
           _navigateToPost(item['id']);
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
                        child: Icon(placeholderIcon, color: Colors.grey),
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
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
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

  Future<void> _navigateToPost(String postId) async {
    try {
      final post = await _supabase.from('posts').select('*, profiles(*), events(*), listings(*)').eq('id', postId).single();
      if (mounted) {
         Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
      }
    } catch (e) {
      debugPrint("Error opening post: $e");
    }
  }
}