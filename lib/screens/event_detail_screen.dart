import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'create_event_screen.dart'; 

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? event; 
  final String? eventId; 
  final bool isOwnerOverride; // <--- THIS WAS MISSING!

  const EventDetailScreen({
    super.key, 
    this.event, 
    this.eventId,
    this.isOwnerOverride = false, // <--- DEFAULT VALUE
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _eventData;
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
    try {
      if (widget.event != null) {
        _eventData = widget.event;
      } else if (widget.eventId != null) {
        final data = await supabase.from('events').select().eq('id', widget.eventId!).single();
        _eventData = data;
      }

      final countRes = await supabase.from('event_attendees').count(CountOption.exact).eq('event_id', _eventData!['id']);
      
      final user = supabase.auth.currentUser;
      bool joined = false;
      bool owner = widget.isOwnerOverride; // <--- USE THE KEY HERE
      
      if (user != null) {
        // Only check ID if the Override key wasn't used
        if (!owner) {
             owner = (user.id == _eventData!['organizer_id']); 
        }
        
        final myJoin = await supabase.from('event_attendees').select().eq('event_id', _eventData!['id']).eq('user_id', user.id).maybeSingle();
        joined = myJoin != null;
      }

      if (mounted) {
        setState(() {
          _attendeeCount = countRes ?? 0;
          _isJoined = joined;
          _isOwner = owner;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Event"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('events').delete().eq('id', _eventData!['id']);
        if (mounted) {
          Navigator.pop(context, true); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted")));
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
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
         _attendeeCount++;
       } else {
         await Supabase.instance.client.from('event_attendees').delete().match({'event_id': _eventData!['id'], 'user_id': user.id});
         _attendeeCount--;
       }
       setState(() {});
     } catch (e) {
       setState(() => _isJoined = !_isJoined);
     }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _eventData == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final primary = const Color(0xFFE02097);
    final start = DateTime.parse(_eventData!['start_datetime']);
    String timeString = DateFormat('d MMM, h:mm a').format(start);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                _eventData!['image_url'] ?? '', 
                fit: BoxFit.cover,
                errorBuilder: (_,__,___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_eventData!['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _infoRow(Icons.calendar_month, timeString, primary),
                  _infoRow(Icons.location_on, _eventData!['location'] ?? 'UiTM Kerawang', primary),
                  _infoRow(Icons.group, "$_attendeeCount people going", primary),
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
                          setState(() => _isLoading = true);
                          final newData = await Supabase.instance.client.from('events').select().eq('id', _eventData!['id']).single();
                          setState(() { _eventData = newData; _isLoading = false; });
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