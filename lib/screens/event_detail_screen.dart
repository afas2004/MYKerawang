import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mykerawang/services/share_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'profile_screen.dart';
import 'create_post_screen.dart'; 
import 'create_event_screen.dart';
import 'gallery_view_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Map<String, dynamic> _event;
  Map<String, dynamic>? _organizer;
  bool _isLoading = true;
  int _currentImageIndex = 0; 
  final _commentCtrl = TextEditingController();
  bool _isJoined = false;       // <--- NEW: Did I join?
  int _participantCount = 0;    // <--- NEW: Total count

  final List<String> _trustedDomains = [
    'uitm.edu.my', 
    'google.com', 'forms.gle', 'docs.google.com',
    'whatsapp.com', 'wa.me',
    'instagram.com', 'facebook.com', 'twitter.com', 'x.com',
    't.me', 'telegram.org',
    'linkedin.com'
  ];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _fetchEventDetails();
  }

  Future<void> _fetchEventDetails() async {
    final supabase = Supabase.instance.client;
    try {
      final freshEvent = await supabase.from('events').select().eq('id', _event['id']).single();
      final organizer = await supabase.from('profiles').select().eq('id', freshEvent['organizer_id']).maybeSingle();

      // 2. NEW: Fetch Participant Count
      final count = await supabase
          .from('event_participants')
          .count(CountOption.exact)
          .eq('event_id', _event['id']);
      
      // 3. NEW: Check if *I* already joined
      bool amIJoined = false;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final myEntry = await supabase
            .from('event_participants')
            .select()
            .eq('event_id', _event['id'])
            .eq('user_id', userId)
            .maybeSingle();
        amIJoined = myEntry != null;
      }

      if (mounted) {
        setState(() {
          _event = freshEvent;
          _organizer = organizer;
          _participantCount = count; // <--- Update Count
          _isJoined = amIJoined;     // <--- Update My Status
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> _commentsStream() {
    return Supabase.instance.client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('event_id', _event['id'])
        .order('created_at', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  Future<void> _postComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('comments').insert({
        'event_id': _event['id'],
        'user_id': user.id,
        'body': _commentCtrl.text.trim(),
      });
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- NEW: Delete Logic ---
  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Event"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Keep")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('events').delete().eq('id', _event['id']);
        if (mounted) {
          Navigator.pop(context, true); // Return true to refresh profile/home
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event cancelled.")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 2. SAFETY: LINK CHECKER ---
  Future<void> _launchSafeUrl(String url) async {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase().replaceFirst('www.', '');

    bool isTrusted = _trustedDomains.any((domain) => host.endsWith(domain));

    if (isTrusted) {
      // Safe -> Launch immediately
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Unknown -> Warning Dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Text("Leaving App")]),
          content: Text("This link goes to an external site:\n\n$host\n\nAre you sure it's safe?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text("Open Anyway"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _toggleJoin() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to join.")));
      return;
    }

    // 1. Instant UI Update (Makes it feel fast)
    setState(() {
      _isJoined = !_isJoined;
      _participantCount += _isJoined ? 1 : -1;
    });

    try {
      // 2. Update Database
      if (_isJoined) {
        await supabase.from('event_participants').insert({
          'event_id': _event['id'],
          'user_id': userId,
        });
      } else {
        await supabase.from('event_participants').delete().match({
          'event_id': _event['id'],
          'user_id': userId,
        });
      }
    } catch (e) {
      // 3. Revert if error
      if (mounted) {
        setState(() {
          _isJoined = !_isJoined;
          _participantCount += _isJoined ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwner = currentUser != null && currentUser.id == _event['organizer_id'];
    final theme = Theme.of(context);
    
    // Date Parsing logic remains the same...
    final startDate = DateTime.parse(_event['start_datetime']);
    final DateTime? endDate = _event['end_datetime'] != null 
        ? DateTime.parse(_event['end_datetime']) 
        : null;
    final gallery = List<String>.from(_event['gallery_urls'] ?? []);

    final List<String> allImages = [
      if (_event['image_url'] != null) _event['image_url'],
      ...?(_event['gallery_urls'] as List?)?.cast<String>(),
    ];

    final bool isPast = endDate != null 
        ? endDate.isBefore(DateTime.now()) 
        : startDate.add(const Duration(hours: 4)).isBefore(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. App Bar (Keep your existing code)
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              backgroundColor: theme.scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. THE CAROUSEL
                    PageView.builder(
                      itemCount: allImages.length,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Open your GalleryViewScreen when tapped
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => GalleryViewScreen(
                                  galleryItems: allImages, 
                                  initialIndex: index
                                )
                              )
                            );
                          },
                          child: Hero(
                            tag: "gallery_$index", // Unique tag for smooth animation
                            child: CachedNetworkImage(
                              imageUrl: allImages[index],
                              fit: BoxFit.cover,
                              placeholder: (_,__) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (_,__,___) => Container(color: Colors.grey, child: const Icon(Icons.event)),
                            ),
                          ),
                        );
                      },
                    ),

                    if (isPast)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              color: Colors.black54,
                            ),
                            child: const Text(
                              "EVENT ENDED",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. THE BADGE (e.g. "1/5")
                    if (allImages.length > 1)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "${_currentImageIndex + 1} / ${allImages.length}",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                    // 3. GRADIENT SHADOW (To make back button visible)
                    Positioned(
                      top: 0, left: 0, right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Body
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded( child:Text(_event['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                        IconButton(
                          icon: const CircleAvatar(
                            backgroundColor: Colors.black45,
                            child: Icon(Icons.share, color: Colors.white, size: 20),
                          ),
                          onPressed: () {
                            ShareService.shareContent(
                              context, 
                              _event['title'], 
                              "Event Details: ${_event['description'] ?? ''}", 
                              _event['image_url']
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date & Location Rows (Keep your existing logic)
                    _infoRow(
                      Icons.calendar_today, 
                      endDate != null
                          ? "${DateFormat('d MMM yyyy').format(startDate)} - ${DateFormat('d MMM yyyy').format(endDate)}"
                          : DateFormat('d MMM yyyy • h:mm a').format(startDate),
                      theme
                    ),
                    const SizedBox(height: 12),
                    _infoRow(Icons.location_on, _event['location'] ?? 'Campus', theme),
                    
                    const SizedBox(height: 24),
                    const Divider(),

                                        
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          // 1. The Count
                          Icon(Icons.group, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text("$_participantCount Attending", style: const TextStyle(fontWeight: FontWeight.bold)),
                          
                          const Spacer(),

                          // 2. The Button (Only show if not owner)
                          if (Supabase.instance.client.auth.currentUser?.id != _event['organizer_id'])
                            SizedBox(
                              height: 36,
                              child: _isJoined
                                  ? OutlinedButton.icon(
                                      onPressed: _toggleJoin,
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text("Joined"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(color: Colors.green),
                                      ),
                                    )
                                  : FilledButton.icon(
                                      onPressed: _toggleJoin,
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text("Join"),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Organizer Tile (Keep existing)
                    if (_organizer != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: _organizer!['avatar_url'] != null ? NetworkImage(_organizer!['avatar_url']) : null,
                          child: _organizer!['avatar_url'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(_organizer!['display_name'] ?? 'Organizer', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_organizer!['role'] == 'club' ? "Official Club" : "Student Host"),
                        trailing: OutlinedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: _organizer!['id']))),
                          child: const Text("View Profile"),
                        ),
                      ),

                    const Divider(),
                    const SizedBox(height: 16),

                   
                    // Description & Post Button (Keep existing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("About Event", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen(sharedEvent: _event)));
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text("Post"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_event['description'] ?? 'No details provided.', style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.grey)),
                    const SizedBox(height: 32),
                    
                    // --- REGISTER BUTTON (VISIBLE TO EVERYONE HERE) ---
                    if (_event['registration_link'] != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: Icon(isPast ? Icons.event_busy : Icons.link),
                        label: Text(isPast ? "Registration Closed" : "Register Online"),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          // Disable color if past
                          backgroundColor: isPast ? Colors.grey : theme.colorScheme.primary,
                        ),
                        onPressed: isPast 
                          ? null // DISABLE CLICK
                          : () => _launchSafeUrl(_event['registration_link']), // USE SAFE LAUNCHER
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(thickness: 4),

                    // Discussion Header (Keep existing)
                    Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Discussion", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        
                        // NEW REFRESH BUTTON HERE
                        IconButton(
                          icon: _isLoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.refresh, size: 20),
                          onPressed: () {
                            setState(() => _isLoading = true);
                            _fetchEventDetails();
                          },
                          tooltip: "Refresh Comments",
                        ),
                      ],
                    ),
                  ),

                    // Comments List (Keep existing)
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _commentsStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text("No comments yet.")));
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final c = snapshot.data![index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                              title: Text(c['body']),
                              subtitle: Text(timeago.format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 10)),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      
      // 3. BOTTOM SHEET LOGIC (This is where the magic happens)
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: isOwner
              // A: OWNER CONTROLS (Edit / Delete)
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _deleteEvent,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        child: const Text("Cancel Event"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Navigate to Edit Screen
                          final result = await Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => CreateEventScreen(eventToEdit: _event))
                          );
                          if (result == true) _fetchEventDetails();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
                        child: const Text("Edit"),
                      ),
                    ),
                  ],
                )
              // B: VIEWER CONTROLS (Comment Input)
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: InputDecoration(
                          hintText: "Ask about this event...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send), onPressed: _postComment),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}