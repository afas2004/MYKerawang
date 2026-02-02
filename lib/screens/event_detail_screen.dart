import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mykerawang/widgets/linear_refresher';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'profile_screen.dart';
import 'create_post_screen.dart'; // To share event to feed
import 'image_preview_screen.dart'; // Ensure you have this file

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
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _fetchEventDetails();
  }

  Future<void> _fetchEventDetails() async {
    final supabase = Supabase.instance.client;
    try {
      // 1. Refresh Event Data (in case of updates)
      final freshEvent = await supabase.from('events').select().eq('id', _event['id']).single();
      
      // 2. Fetch Organizer Profile
      final organizer = await supabase
          .from('profiles')
          .select()
          .eq('id', freshEvent['organizer_id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _event = freshEvent;
          _organizer = organizer;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    }
  }

  // Live Comment Stream
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
        'event_id': _event['id'], // Link to Event
        'user_id': user.id,
        'body': _commentCtrl.text.trim(),
      });
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startDate = DateTime.parse(_event['start_datetime']);
    final DateTime? endDate = _event['end_datetime'] != null 
        ? DateTime.parse(_event['end_datetime']) 
        : null;
    final gallery = List<String>.from(_event['gallery_urls'] ?? []);

    return Scaffold(
      body: LinearRefresher(
        onRefresh: _fetchEventDetails,
        offset: 0.0,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. APP BAR WITH IMAGE PREVIEW
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
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                   // PREVIEW IMAGE LOGIC
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (_) => ImagePreviewScreen(imageUrl: _event['image_url'] ?? ''))
                   );
                },
                child: Hero(
                  tag: _event['id'],
                  child: CachedNetworkImage(
                    imageUrl: _event['image_url'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_,__) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (_,__,___) => Container(color: Colors.grey, child: const Icon(Icons.event)),
                  ),
                ),
              ),
            ),
          ),

          // 2. EVENT DETAILS BODY
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(_event['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Info Rows (Date & Location)
                  _infoRow(
                    Icons.calendar_today, 
                    endDate != null
                        ? "${DateFormat('d MMM yyyy').format(startDate)} - ${DateFormat('d MMM yyyy').format(endDate)}"
                        : DateFormat('d MMM yyyy • h:mm a').format(startDate), // Fallback if no end date
                    theme
                  ),
                  const SizedBox(height: 12),
                  _infoRow(Icons.location_on, _event['location'] ?? 'Campus', theme),
                  
                  const SizedBox(height: 24),
                  const Divider(),

                  // Organizer Tile
                  if (_organizer != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: _organizer!['avatar_url'] != null 
                          ? NetworkImage(_organizer!['avatar_url']) 
                          : null,
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

                  // Gallery (Horizontal Scroll)
                  if (gallery.isNotEmpty) ...[
                    const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: gallery.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImagePreviewScreen(imageUrl: gallery[index]))),
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(image: NetworkImage(gallery[index]), fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("About Event", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      
                      // THE NEW "POST" BUTTON
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => CreatePostScreen(sharedEvent: _event))
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text("Post"),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Removes extra padding
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_event['description'] ?? 'No details provided.', style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.grey)),
                  
                  const SizedBox(height: 32),
                  
                  // Registration Button
                  if (_event['registration_link'] != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text("Register Online"),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          final uri = Uri.parse(_event['registration_link']);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  const Divider(thickness: 4),

                  // DISCUSSION HEADER ROW
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // <--- Pushes text left, button right
                      children: [
                        const Text(
                          "Discussion", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                        ),
                        
                        // RELOAD BUTTON (Cleaner Style)
                        IconButton(
                          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                          onPressed: () {
                            setState(() => _isLoading = true);
                            _fetchEventDetails(); 
                          },
                        ),
                      ],
                    ),
                  ),
                  // Comments List
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _commentsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text("No comments yet. Ask a question!")));
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
                  
                  const SizedBox(height: 80), // Space for input field
                ],
              ),
            ),
          ),
        ],
      ),
      ),
      
      // 3. BOTTOM INPUT BAR (For Comments)
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
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