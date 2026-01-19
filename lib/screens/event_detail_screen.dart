import 'package:flutter/material.dart';
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
    _loadEventData();
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

    final primary = const Color(0xFFE02097);
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
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
                    body: PhotoView(imageProvider: CachedNetworkImageProvider(_eventData!['image_url'] ?? '')),
                  )));
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
                          label: Text("#$tag", style: const TextStyle(fontSize: 12, color: Colors.white)),
                          backgroundColor: primary.withOpacity(0.8),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ),

                  Text(_eventData!['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _infoRow(Icons.calendar_month, timeString, primary),
                  _infoRow(Icons.location_on, _eventData!['location'] ?? 'UiTM Kerawang', primary),
                  _infoRow(Icons.group, "$_attendeeCount people going", primary),
                  
                  const SizedBox(height: 20),
                  
                  // Organizer Card
                  if (_organizerProfile != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12), color: Colors.white),
                      child: Row(
                        children: [
                          CircleAvatar(
                            // UPDATED: Cached Avatar
                            backgroundImage: _organizerProfile!['avatar_url'] != null 
                                ? CachedNetworkImageProvider(_organizerProfile!['avatar_url']) 
                                : null,
                            child: _organizerProfile!['avatar_url'] == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_organizerProfile!['full_name'] ?? 'Organizer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("Event Host", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),

                  const Divider(height: 40),
                  const Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_eventData!['description'] ?? 'No description provided.', style: TextStyle(color: Colors.grey[800], height: 1.5)),
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
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: _isOwner 
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deleteEvent,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text("Delete"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                       final result = await Navigator.push(
                         context, 
                         MaterialPageRoute(builder: (_) => CreateEventScreen(eventToEdit: _eventData))
                       );
                       if (result == true && mounted) {
                          _loadEventData(); 
                       }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                    child: const Text("Update"),
                  ),
                ),
              ],
            )
          : ElevatedButton(
              onPressed: _toggleJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isJoined ? Colors.grey[300] : primary, 
                foregroundColor: _isJoined ? Colors.black : Colors.white
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