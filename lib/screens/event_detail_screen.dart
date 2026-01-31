import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_event_screen.dart';
import '../screens/profile_cubit.dart'; // Ensure this path is correct

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final bool isOwnerOverride; // Optional: Force owner view if coming from Profile

  const EventDetailScreen({
    super.key, 
    required this.event, 
    this.isOwnerOverride = false
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> _eventData;
  Map<String, dynamic>? _organizerProfile;
  bool _isLoading = true;
  bool _isJoined = false;
  int _attendeeCount = 0;

  @override
  void initState() {
    super.initState();
    _eventData = widget.event;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      // 1. Fetch Organizer Profile
      final organizerRes = await _supabase
          .from('profiles')
          .select()
          .eq('id', _eventData['organizer_id'])
          .maybeSingle();

      // 2. Fetch Attendee Count
      final countRes = await _supabase
          .from('event_participants')
          .count()
          .eq('event_id', _eventData['id']);

      // 3. Check if Current User Joined
      bool joined = false;
      if (currentUserId != null) {
        final joinRes = await _supabase
            .from('event_participants')
            .select()
            .eq('event_id', _eventData['id'])
            .eq('user_id', currentUserId)
            .maybeSingle();
        joined = joinRes != null;
      }

      if (mounted) {
        setState(() {
          _organizerProfile = organizerRes;
          _attendeeCount = countRes;
          _isJoined = joined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleJoin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to join")));
      return;
    }

    try {
      if (_isJoined) {
        // LEAVE
        await _supabase
            .from('event_participants')
            .delete()
            .eq('event_id', _eventData['id'])
            .eq('user_id', user.id);
        setState(() {
          _isJoined = false;
          _attendeeCount--;
        });
      } else {
        // JOIN
        await _supabase
            .from('event_participants')
            .insert({'event_id': _eventData['id'], 'user_id': user.id});
        setState(() {
          _isJoined = true;
          _attendeeCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Event?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text("Delete", style: TextStyle(color: Theme.of(context).colorScheme.error))
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _supabase.from('events').delete().eq('id', _eventData['id']);
        if (mounted) {
          // Refresh profile if we came from there
          if (widget.isOwnerOverride) {
            context.read<ProfileCubit>().loadProfile();
          }
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final isOwner = widget.isOwnerOverride || (user != null && user.id == _eventData['organizer_id']);
    
    // SAFETY CHECK: Handle null image
    final String? imageUrl = _eventData['image_url']; 
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    // SAFETY CHECK: Handle dates
    final startDate = DateTime.parse(_eventData['start_datetime']).toLocal();
    final endDate = _eventData['end_datetime'] != null 
        ? DateTime.parse(_eventData['end_datetime']).toLocal() 
        : startDate.add(const Duration(hours: 2)); // Fallback for old events

    final dateString = "${DateFormat('d MMM').format(startDate)} • ${DateFormat('h:mm a').format(startDate)} - ${DateFormat('h:mm a').format(endDate)}";
    final tags = List<String>.from(_eventData['tags'] ?? []);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(Icons.event, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  // TITLE
                  Text(
                    _eventData['title'] ?? 'Untitled Event', // SAFETY
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  // TAGS
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: tags.map((tag) => Chip(
                        label: Text(tag, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  const SizedBox(height: 20),

                  // INFO ROWS
                  _infoRow(Icons.calendar_month, dateString, context),
                  const SizedBox(height: 12),
                  _infoRow(Icons.location_on, _eventData['location'] ?? 'UiTM Kerawang', context),
                  const SizedBox(height: 12),
                  _infoRow(Icons.group, "$_attendeeCount people going", context),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // ORGANIZER CARD
                  if (_organizerProfile != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surfaceContainer,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: _organizerProfile!['avatar_url'] != null
                                ? CachedNetworkImageProvider(_organizerProfile!['avatar_url'])
                                : null,
                            onBackgroundImageError: _organizerProfile!['avatar_url'] != null ? (_, __) {} : null,
                            child: _organizerProfile!['avatar_url'] == null 
                                ? Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant) 
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_organizerProfile!['full_name'] ?? 'Organizer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("Event Host", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  Text("About Event", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Text(
                    _eventData['description'] ?? 'No description provided.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, height: 1.5),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: isOwner
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deleteEvent,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                           _fetchDetails(); // Refresh details
                           // Update the local data map too so the UI updates instantly
                           // (Ideally re-fetch full event, but this is a quick fix)
                         }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Update"),
                    ),
                  ),
                ],
              )
            : ElevatedButton(
                onPressed: _isLoading ? null : _toggleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isJoined 
                      ? Theme.of(context).colorScheme.surfaceContainerHighest 
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: _isJoined 
                      ? Theme.of(context).colorScheme.onSurface 
                      : Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text(_isJoined ? "Joined" : "Join Event", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}