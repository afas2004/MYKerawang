import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  final Map<String, dynamic>? sharedEvent;

  const CreatePostScreen({super.key, this.sharedEvent});

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
      await Supabase.instance.client.from('posts').insert({
        'user_id': user!.id,
        'title': _titleCtrl.text,
        'body': _bodyCtrl.text,
        'is_anonymous': _isAnon,
        'shared_event_id': widget.sharedEvent?['id'],
        'tags': _selectedTag != null ? [_selectedTag] : [],
      });
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

  @override
  Widget build(BuildContext context) {
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
          // 1. THE REFERENCE BAR (Only if sharedEvent exists)
          if (widget.sharedEvent != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest, // Grey background
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Referencing Event:", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          widget.sharedEvent!['title'], 
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
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
          TextField(
            controller: _bodyCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              border: InputBorder.none,
            ),
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