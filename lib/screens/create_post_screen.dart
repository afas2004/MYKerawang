import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

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
        'tags': _selectedTag != null ? [_selectedTag] : [],
      });
      if (mounted) Navigator.pop(context);
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