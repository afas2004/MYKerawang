import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'image_preview_screen.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});
  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Books';
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        final path = 'listings/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('images').upload(path, _imageFile!);
        imageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(path);
      }

      await Supabase.instance.client.from('listings').insert({
        'seller_id': user.id,
        'title': _titleCtrl.text,
        'price': double.parse(_priceCtrl.text),
        'category': _category,
        'description': _descCtrl.text,
        'image_url': imageUrl,
        'fulfillment_type': 'Pickup'
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing Created!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sell Item")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "Title"), validator: (v) => v!.isEmpty ? "Required" : null),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price (RM)"), validator: (v) => v!.isEmpty ? "Required" : null)),
                const SizedBox(width: 16),
                Expanded(child: DropdownButtonFormField(value: _category, items: ['Books', 'Electronics', 'Clothing', 'Services'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _category = v!))),
              ]),
              const SizedBox(height: 16),
              TextFormField(controller: _descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: "Description")),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(context: context, builder: (_) => Wrap(children: [
                    ListTile(leading: const Icon(Icons.camera), title: const Text('Camera'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
                    ListTile(leading: const Icon(Icons.image), title: const Text('Gallery'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
                  ]));
                },
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null),
                  child: _imageFile == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo), Text("Add Photo")]) : null,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : _submit, child: _isLoading ? const CircularProgressIndicator() : const Text("Publish")))
            ],
          ),
        ),
      ),
    );
  }
}