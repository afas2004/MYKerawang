import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// Ensure you have this utility (or copy it from previous steps)
import '../utils/image_compressor.dart'; 
import 'gallery_view_screen.dart';

class CreateListingScreen extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit; 

  const CreateListingScreen({super.key, this.itemToEdit});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  
  // State
  String _category = 'Books';
  final List<String> _categories = ['Electronics', 'Books', 'Furniture', 'Clothing', 'Sports', 'Others'];
  bool _isLoading = false;

  // UNIFIED MEDIA LIST (Stores both Strings/URLs and Files)
  // Index 0 is ALWAYS the Cover Photo.
  final List<dynamic> _mediaItems = [];

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    
    _titleController = TextEditingController(text: item?['title'] ?? '');
    _priceController = TextEditingController(text: item?['price']?.toString() ?? '');
    _descriptionController = TextEditingController(text: item?['description'] ?? '');
    
    if (item != null) {
      _category = item['category'] ?? 'Books';
      
      // LOAD EXISTING MEDIA
      // 1. Cover
      if (item['image_url'] != null) {
        _mediaItems.add(item['image_url']);
      }
      // 2. Gallery
      if (item['gallery_urls'] != null) {
        final extras = List<String>.from(item['gallery_urls']);
        // Avoid duplicates if cover is also in gallery list
        for (var url in extras) {
          if (!_mediaItems.contains(url)) _mediaItems.add(url);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- 1. UNIFIED PICKER LOGIC ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.camera) {
        final XFile? picked = await picker.pickImage(source: ImageSource.camera);
        if (picked != null) {
          setState(() => _mediaItems.add(File(picked.path)));
        }
      } else {
        final List<XFile> pickedList = await picker.pickMultiImage();
        if (pickedList.isNotEmpty) {
          setState(() {
            _mediaItems.addAll(pickedList.map((x) => File(x.path)));
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Select from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. UPLOAD LOGIC ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_mediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least 1 photo.')));
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? finalCoverUrl;
      List<String> finalGalleryUrls = [];

      // Loop and Process
      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];
        String url;

        if (item is File) {
          // Compress & Upload
          final compressed = await ImageCompressor.compress(item);
          final path = 'listings/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await _supabase.storage.from('images').upload(path, compressed);
          url = _supabase.storage.from('images').getPublicUrl(path);
        } else {
          // Already a URL
          url = item as String;
        }

        if (i == 0) {
          finalCoverUrl = url;
        } else {
          finalGalleryUrls.add(url);
        }
      }
      
      final data = {
        'seller_id': user.id,
        'title': _titleController.text.trim(),
        'price': double.parse(_priceController.text),
        'category': _category,
        'description': _descriptionController.text.trim(),
        'image_url': finalCoverUrl,      // Index 0
        'gallery_urls': finalGalleryUrls, // Index 1+
        'fulfillment_type': 'Pickup',
      };

      if (widget.itemToEdit != null) {
        await _supabase.from('listings').update(data).eq('id', widget.itemToEdit!['id']);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing Updated!')));
      } else {
        await _supabase.from('listings').insert(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing Published!')));
      }

      if (mounted) Navigator.pop(context, true); 

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 3. UI HELPER: IMAGE MENU ---
  void _showImageMenu(int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (index != 0)
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Set as Cover Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    final item = _mediaItems.removeAt(index);
                    _mediaItems.insert(0, item);
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('View Fullscreen'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GalleryViewScreen(galleryItems: _mediaItems, initialIndex: index)
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _mediaItems.removeAt(index));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Listing' : 'Sell Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- UNIFIED MEDIA GRID ---
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text("Photos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              if (_mediaItems.isEmpty)
                GestureDetector(
                  onTap: _showAddOptions,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 40, color: theme.colorScheme.primary),
                        const SizedBox(height: 8),
                        Text("Add Photos", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaItems.length + 1,
                    itemBuilder: (context, index) {
                      // "Add More" Button at the end
                      if (index == _mediaItems.length) {
                        return GestureDetector(
                          onTap: _showAddOptions,
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.add, size: 30),
                          ),
                        );
                      }

                      final item = _mediaItems[index];
                      final isCover = index == 0;

                      return GestureDetector(
                        onTap: () => _showImageMenu(index),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item is File 
                                    ? Image.file(item, fit: BoxFit.cover) 
                                    : Image.network(item as String, fit: BoxFit.cover),
                              ),
                              if (isCover)
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: const Text("COVER", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              Positioned(
                                top: 4, right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _mediaItems.removeAt(index)),
                                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
              if (_mediaItems.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 20),
                  child: Text("Tip: Tap a photo to set it as Cover.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              SizedBox(height: 12),

              // --- FORM FIELDS ---
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Pre-loved Textbook', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price (RM)', prefixText: 'RM ', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true, border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, 
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1)))
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : Text(isEditing ? "Save Changes" : "Publish Listing"),
        ),
      ),
    );
  }
}