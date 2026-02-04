import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_parsed_text/flutter_parsed_text.dart';
import 'package:mykerawang/screens/profile_screen.dart';
import 'package:mykerawang/utils/report_helper.dart';
import 'package:mykerawang/widgets/mention_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _supabase = Supabase.instance.client;
  
  // STATE VARIABLES
  bool _isLoading = false;
  bool _isAnon = false;
  late Map<String, dynamic> _postData; // <--- NEW: Dynamic Post Data
  late Stream<List<Map<String, dynamic>>> _commentsStream;

  @override
  void initState() {
    super.initState();
    _postData = widget.post; // Initialize with passed data
    _commentsStream = _fetchCommentsStream();
  }

  // 1. REFRESH FUNCTION (Updates Post Counts)
  Future<void> _refreshData() async {
    try {
      // Fetch the specific post again to get new 'comment_count'
      final freshPost = await _supabase
          .from('posts')
          .select('*, profiles(*), events(*), listings(*)')
          .eq('id', _postData['id'])
          .single();
      
      if (mounted) {
        setState(() {
          _postData = freshPost; // Update UI with new numbers
        });
      }
    } catch (e) {
      debugPrint("Refresh error: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> _fetchCommentsStream() async* {
    yield await _fetchComments();
    final stream = _supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', widget.post['id'])
        .order('created_at', ascending: true);

    await for (final _ in stream) {
      yield await _fetchComments();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchComments() async {
    final response = await _supabase
        .from('comments')
        .select('*, profiles(*)')
        .eq('post_id', widget.post['id'])
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // PASTE THIS INSIDE _PostDetailScreenState class
  Future<void> _processMentions(String text, String postId, {String? commentId}) async {
    final regex = RegExp(r"\@(\w+)");
    final matches = regex.allMatches(text);
    final usernames = matches.map((m) => m.group(1)).toSet().toList();

    if (usernames.isEmpty) return;

    final myId = _supabase.auth.currentUser!.id;

    final users = await _supabase
        .from('profiles')
        .select('id, username')
        .inFilter('username', usernames);

    for (var user in users) {
      if (user['id'] == myId) continue;

      await _supabase.from('notifications').insert({
        'user_id': user['id'],
        'actor_id': myId,
        'type': 'mention',
        'title': 'You were mentioned in a comment', // Changed title slightly
        'body': 'replied: $text',
        'data': {'post_id': postId, 'comment_id': commentId},
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    
    // ... (Your existing login check) ...

    setState(() => _isLoading = true);

    try {
      // 1. Send to Database AND Select the ID back
      final newComment = await _supabase.from('comments').insert({
        'post_id': widget.post['id'],
        'user_id': _supabase.auth.currentUser!.id,
        'body': text,
        'is_anonymous': _isAnon,
      }).select().single(); // <--- ADD .select().single()

      // 2. PROCESS MENTIONS (This was missing!)
      await _processMentions(text, widget.post['id'], commentId: newComment['id']);

      // 3. Clear Input & Refresh
      _commentCtrl.clear();
      FocusScope.of(context).unfocus(); 
      await _refreshData();
      setState(() {
        _commentsStream = _fetchCommentsStream(); 
      });
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thread")),
      body: Column(
        children: [
          Expanded(
            // 2. REFRESH INDICATOR WRAPPER
            child: RefreshIndicator(
              onRefresh: _refreshData, // Pulling triggers this
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works even if list is short
                child: Column(
                  children: [
                    // USE DYNAMIC _postData HERE
                    PostCard(post: _postData, onTap: null),
                    
                    const Divider(thickness: 4), 
                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),

                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _commentsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text("Error: ${snapshot.error}"));
                        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                        
                        final comments = snapshot.data!;
                        if (comments.isEmpty) {
                           return const Padding(
                             padding: EdgeInsets.all(32.0),
                             child: Text("Be the first to reply!", style: TextStyle(color: Colors.grey)),
                           );
                        }

                        return ListView.separated(
                          shrinkWrap: true, 
                          physics: const NeverScrollableScrollPhysics(), 
                          itemCount: comments.length,
                          separatorBuilder: (_,__) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = comments[index];
                            final isAnon = c['is_anonymous'] ?? false;
                            
                            final profile = c['profiles'];
                            final displayName = isAnon ? "Anonymous" : (profile?['display_name'] ?? "Student");
                            final avatarUrl = isAnon ? null : profile?['avatar_url'];
                            final username = isAnon ? null : profile?['username'];

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isAnon ? Colors.grey : Theme.of(context).colorScheme.primaryContainer,
                                backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                                child: (avatarUrl == null) 
                                    ? Icon(isAnon ? Icons.visibility_off : Icons.person, size: 16, color: isAnon ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer)
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (!isAnon && username != null) ...[
                                    const SizedBox(width: 4),
                                    Text("@$username", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                  const SizedBox(width: 8),
                                  Text(timeago.format(DateTime.parse(c['created_at']), locale: 'en_short'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),

                              subtitle: ParsedText(
                                text: c['body'] ?? '',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface), // Default color
                                parse: [
                                  MatchText(
                                    pattern: r"\@(\w+)", // Finds @username
                                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                    onTap: (username) async {
                                      final cleanName = username.substring(1); // Remove @
                                      
                                      // 1. Find the User ID
                                      final user = await Supabase.instance.client
                                          .from('profiles')
                                          .select('id')
                                          .eq('username', cleanName)
                                          .maybeSingle();

                                      // 2. Navigate
                                      if (user != null && context.mounted) {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user['id'])));
                                      } else if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found")));
                                      }
                                    },
                                  ),
                                ],
                              ),
                              
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'report') {
                                    // Pass 'comment' as the type
                                    showReportDialog(context, c['id'], 'comment');
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'report',
                                    child: Text("Report Comment", style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
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
          ),
          
          // INPUT BAR (Same as before)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isAnon ? Icons.visibility_off : Icons.visibility,
                      color: _isAnon ? Theme.of(context).colorScheme.primary : Colors.grey,
                    ),
                    onPressed: () => setState(() => _isAnon = !_isAnon),
                  ),
                  Expanded(
                    child: MentionInput(
                      controller: _commentCtrl,
                      hintText: "What's on your mind?",
                      isMultiLine: true,
                      reverseDirection: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isLoading ? null : _submitComment,
                    icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}