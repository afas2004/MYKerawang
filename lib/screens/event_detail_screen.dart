import 'package:flutter/material.dart';
import 'package:mykerawang/screens/image_preview_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Import Cached Image
import 'create_event_screen.dart'; 

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? event; 
  final String? eventId; 
  final bool isOwnerOverride; 

  const EventDetailScreen({
    super.key, 
    this.event, 
    this.eventId,
    this.isOwnerOverride = false,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _eventData;
  Map<String, dynamic>? _organizerProfile; 
  bool _isLoading = true;
  bool _isJoined = false;
  int _attendeeCount = 0;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    // 1. INSTANT LOAD: Use the data passed from the previous screen
    if (widget.event != null) {
      _eventData = widget.event;
      _isLoading = false; // Show content immediately
    }
    
    // 2. BACKGROUND REFRESH: Fetch organizer & attendee count silently
    _refreshEventDetails();
  }

  Future<void> _refreshEventDetails() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      final String idToFetch = widget.event?['id'] ?? widget.eventId;
      
      // Fetch fresh data (in case something changed)
      final freshEventData = await supabase.from('events').select().eq('id', idToFetch).single();
      
      // Fetch Organizer
      final organizer = await supabase
          .from('profiles')
          .select()
          .eq('id', freshEventData['organizer_id'])
          .maybeSingle();

      // Fetch Attendees
      final attendeesList = await supabase
          .from('event_attendees')
          .select('user_id')
          .eq('event_id', idToFetch);
      
      final int realCount = (attendeesList as List).length;
      
      bool joined = false;
      bool owner = widget.isOwnerOverride; 
      
      if (user != null) {
        if (!owner) {
             final userId = user.id.toString().trim();
             final orgId = (freshEventData['organizer_id'] ?? '').toString().trim();
             owner = (userId == orgId && userId.isNotEmpty); 
        }
        joined = (attendeesList).any((entry) => entry['user_id'] == user.id);
      }

      if (mounted) {
        setState(() {
          _eventData = freshEventData; // Update with fresh data
          _organizerProfile = organizer;
          _attendeeCount = realCount;
          _isJoined = joined;
          _isOwner = owner;
          // _isLoading is already false, so no spinner needed!
        });
      }
    } catch (e) {
      debugPrint("Error refreshing event: $e");
    }
  }

  Future<void> _loadEventData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      final String? idToFetch = widget.event?['id'] ?? widget.eventId;
      if (idToFetch == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final freshEventData = await supabase.from('events').select().eq('id', idToFetch).single();
      
      final organizer = await supabase
          .from('profiles')
          .select()
          .eq('id', freshEventData['organizer_id'])
          .maybeSingle();

      // Fix: Use .count() logic or fetch IDs
      final attendeesList = await supabase
          .from('event_attendees')
          .select('user_id')
          .eq('event_id', idToFetch);
      
      final int realCount = (attendeesList as List).length;
      
      bool joined = false;
      bool owner = widget.isOwnerOverride; 
      
      if (user != null) {
        if (!owner) {
             final userId = user.id.toString().trim();
             final orgId = (freshEventData['organizer_id'] ?? '').toString().trim();
             owner = (userId == orgId && userId.isNotEmpty); 
        }

        // Safe Join Check
        joined = (attendeesList).any((entry) => entry['user_id'] == user.id);
      }

      if (mounted) {
        setState(() {
          _eventData = freshEventData;
          _organizerProfile = organizer;
          _attendeeCount = realCount;
          _isJoined = joined;
          _isOwner = owner;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading event: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleJoin() async {
     final user = Supabase.instance.client.auth.currentUser;
     if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to join")));
       return;
     }

     setState(() => _isJoined = !_isJoined);
     try {
       if (_isJoined) {
         await Supabase.instance.client.from('event_attendees').insert({'event_id': _eventData!['id'], 'user_id': user.id});
         setState(() => _attendeeCount++);
       } else {
         await Supabase.instance.client.from('event_attendees').delete().match({'event_id': _eventData!['id'], 'user_id': user.id});
         setState(() => _attendeeCount--);
       }
     } catch (e) {
       // Revert if error
       setState(() => _isJoined = !_isJoined);
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating status")));
     }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Event"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('events').delete().eq('id', _eventData!['id']);
      if (mounted) Navigator.pop(context, true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_eventData == null) return const Scaffold(body: Center(child: Text("Event not found")));

    final start = DateTime.parse(_eventData!['start_datetime']);
    String timeString = DateFormat('d MMM, h:mm a').format(start);

    // CRASH FIX: Safe Tags List
    // We use "?? []" so if it's null, we get an empty list instead of a crash.
    final List<dynamic> tags = _eventData!['tags'] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
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
                      builder: (_) => ImagePreviewScreen(imageUrl: _eventData!['image_url'])
                    )
                  );
                },
                // UPDATED: Uses CachedNetworkImage
                child: CachedNetworkImage(
                  imageUrl: _eventData!['image_url'] ?? '', 
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
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
                  // CRASH FIX: Render Tags Safely
                  if (tags.isNotEmpty) 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        children: tags.map((tag) => Chip(
                          label: Text("#$tag", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                          // Use Theme color
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer, 
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ),

                  Text(_eventData!['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _infoRow(Icons.calendar_month, timeString, Theme.of(context).colorScheme.primary),
                  _infoRow(Icons.location_on, _eventData!['location'] ?? 'UiTM Kerawang', Theme.of(context).colorScheme.primary),
                  _infoRow(Icons.group, "$_attendeeCount people going", Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  
                  // Organizer Card
                  if (_organizerProfile != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                        // Adapts to Dark Mode
                        color: Theme.of(context).colorScheme.surfaceContainer, 
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: _organizerProfile!['avatar_url'] != null
                                ? CachedNetworkImageProvider(_organizerProfile!['avatar_url'])
                                : null,
                            onBackgroundImageError: _organizerProfile!['avatar_url'] != null 
                                ? (_, __) {} 
                                : null,
                            child: (_organizerProfile!['avatar_url'] == null)
                                ? Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant)
                                : null,
                          ),
                          SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_organizerProfile!['full_name'] ?? 'Organizer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            // Grey Text Fix
                            Text("Event Host", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),

                  const Divider(height: 40),
                  const Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_eventData!['description'] ?? 'No description provided.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, height: 1.5)),
                  const SizedBox(height: 100),
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
          // Background Fix
          color: Theme.of(context).scaffoldBackgroundColor, 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: _isOwner 
          ? Row(
              // ... (Update/Delete buttons same logic as Item Detail) ...
              children: [
                  // Delete Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deleteEvent,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error)
                      ),
                      child: const Text("Delete"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Update Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {},
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary
                      ),
                      child: const Text("Update"),
                    ),
                  ),
              ],
            )
          : ElevatedButton(
              onPressed: _toggleJoin,
              style: ElevatedButton.styleFrom(
                // DYNAMIC JOIN BUTTON
                backgroundColor: _isJoined 
                    ? Theme.of(context).colorScheme.surfaceContainerHighest // Grey if joined
                    : Theme.of(context).colorScheme.primary, // Theme Color if not
                
                foregroundColor: _isJoined 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.onPrimary
              ),
              child: Text(_isJoined ? "Joined" : "Join Event", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 16), Expanded(child: Text(text))]),
    );
  }
}