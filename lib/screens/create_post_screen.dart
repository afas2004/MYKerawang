import 'package:flutter/material.dart';
import 'package:mykerawang/widgets/mention_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  final Map<String, dynamic>? sharedEvent;
  final Map<String, dynamic>? sharedListing;

  const CreatePostScreen({super.key, this.sharedEvent, this.sharedListing});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _bodyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  bool _isAnon = false;
  bool _isLoading = false;
  String? _selectedTag;
  
  final List<String> _tags = ['Question', 'Confession', 'Lost&Found', 'Rant', 'Academic'];

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;

    try {
      // --- CHANGED SECTION START ---
      // We change .insert() to .select().single() so we get the new Post ID back
      final newPost = await Supabase.instance.client.from('posts').insert({
        'user_id': user!.id,
        'title': _titleCtrl.text,
        'body': _bodyCtrl.text, // Make sure this uses your controller name
        'is_anonymous': _isAnon,
        'shared_event_id': widget.sharedEvent?['id'],
        'shared_listing_id': widget.sharedListing?['id'],
        'tags': _selectedTag != null ? [_selectedTag] : [],
      }).select().single(); // <--- CRITICAL CHANGE

      // Trigger the notifications using the new ID
      await _processMentions(_bodyCtrl.text, newPost['id']);
      // --- CHANGED SECTION END ---

      if (mounted) {
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Posted successfully!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processMentions(String text, String postId, {String? commentId}) async {
    // 1. Extract all unique @usernames using Regex
    final regex = RegExp(r"\@(\w+)");
    final matches = regex.allMatches(text);
    final usernames = matches.map((m) => m.group(1)).toSet().toList();

    if (usernames.isEmpty) return;

    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser!.id;

    // 2. Find User IDs for these usernames
    final users = await supabase
        .from('profiles')
        .select('id, username')
        .inFilter('username', usernames);

    // 3. Send Notifications
    for (var user in users) {
      if (user['id'] == myId) continue; // Don't notify yourself

      await supabase.from('notifications').insert({
        'user_id': user['id'],
        'actor_id': myId,
        'type': 'mention',
        'title': 'You were mentioned',
        'body': 'mentioned you in a post',
        'data': {'post_id': postId, 'comment_id': commentId},
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEvent = widget.sharedEvent != null;
    final bool isListing = widget.sharedListing != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Post"),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: const Text("POST", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isEvent || isListing)
          Container(
            // Optional: Add a little border/color to make it pop (like in the event screen)
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // DYNAMIC ICON: Calendar for Event, Shopping Bag for Item
                Icon(
                  isEvent ? Icons.event : Icons.shopping_bag, 
                  size: 20,
                  color: isEvent ? Theme.of(context).primaryColor : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DYNAMIC LABEL
                      Text(
                        isEvent ? "Referencing Event:" : "Referencing Item:", 
                        style: const TextStyle(fontSize: 10, color: Colors.grey)
                      ),
                      // DYNAMIC TITLE
                      Text(
                        isEvent ? widget.sharedEvent!['title'] : widget.sharedListing!['title'], 
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              hintText: "Title (e.g. Lost Wallet)",
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          MentionInput(
            controller: _bodyCtrl,
            hintText: "What's on your mind?",
            isMultiLine: true,
          ),
          const SizedBox(height: 20),
          
          // Options
          SwitchListTile(
            title: const Text("Post Anonymously"),
            subtitle: const Text("Hide your name from everyone"),
            value: _isAnon,
            onChanged: (val) => setState(() => _isAnon = val),
          ),
          
          const SizedBox(height: 10),
          const Text("Add Tag", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _tags.map((tag) => ChoiceChip(
              label: Text(tag),
              selected: _selectedTag == tag,
              onSelected: (val) => setState(() => _selectedTag = val ? tag : null),
            )).toList(),
          )
        ],
      ),
    );
  }
}