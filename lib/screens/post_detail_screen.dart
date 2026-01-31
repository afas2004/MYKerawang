import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../widgets/post_card.dart'; // Reuse your card for consistent look

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isAnon = false;

  // Stream of Comments (Live Updates!)
  Stream<List<Map<String, dynamic>>> _commentsStream() {
    return _supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', widget.post['id'])
        .order('created_at', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to comment")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.from('comments').insert({
        'post_id': widget.post['id'],
        'user_id': user.id,
        'body': text,
        'is_anonymous': _isAnon,
      });

      // Update local UI state (Optional, but nice feedback)
      _commentCtrl.clear();
      FocusScope.of(context).unfocus(); // Hide keyboard
      
      // Update the comment count on the post (Optimistic UI)
      // Note: Real apps usually use a Database Trigger for this count
      await _supabase.rpc('increment_comment_count', params: {'row_id': widget.post['id']});
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NOTE: You need to create this RPC function in Supabase SQL Editor if you want accurate counts:
  /*
  create or replace function increment_comment_count(row_id uuid)
  returns void as $$
    update posts 
    set comment_count = comment_count + 1
    where id = row_id;
  $$ language sql;
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thread")),
      body: Column(
        children: [
          // 1. SCROLLABLE CONTENT (Post + Comments)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // The Main Post (Reuse your Card, but disable onTap)
                  PostCard(post: widget.post, onTap: null),
                  
                  const Divider(thickness: 4), // Visual separation
                  
                  // Comments Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.surface,
                    child: const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),

                  // Comments List
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _commentsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text("Error: ${snapshot.error}"));
                      if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator());
                      
                      final comments = snapshot.data!;
                      if (comments.isEmpty) {
                         return const Padding(
                           padding: EdgeInsets.all(32.0),
                           child: Text("Be the first to reply!", style: TextStyle(color: Colors.grey)),
                         );
                      }

                      return ListView.separated(
                        shrinkWrap: true, // Critical for nesting inside SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Let the parent handle scrolling
                        itemCount: comments.length,
                        separatorBuilder: (_,__) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          final isAnon = c['is_anonymous'] ?? false;
                          // In real app, you would fetch the User Profile for Name/Avatar
                          // For now, we assume simple display
                          
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isAnon ? Colors.grey : Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(isAnon ? Icons.visibility_off : Icons.person, size: 16, color: isAnon ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer),
                            ),
                            title: Row(
                              children: [
                                Text(isAnon ? "Anonymous" : "Student", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 8),
                                Text(timeago.format(DateTime.parse(c['created_at']), locale: 'en_short'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            subtitle: Text(c['body'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 80), // Space for bottom bar
                ],
              ),
            ),
          ),
          
          // 2. INPUT BAR (Pinned to bottom)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Anon Toggle
                  IconButton(
                    icon: Icon(
                      _isAnon ? Icons.visibility_off : Icons.visibility,
                      color: _isAnon ? Theme.of(context).colorScheme.primary : Colors.grey,
                    ),
                    onPressed: () => setState(() => _isAnon = !_isAnon),
                    tooltip: "Toggle Anonymity",
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: _isAnon ? "Reply anonymously..." : "Write a reply...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
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