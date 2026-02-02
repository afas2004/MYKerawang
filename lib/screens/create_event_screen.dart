import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/image_compressor.dart'; // Ensure this exists from previous step
import 'gallery_view_screen.dart'; // Ensure this exists

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? eventToEdit; 

  const CreateEventScreen({super.key, this.eventToEdit});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descController;
  late TextEditingController _linkController;
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isPublic = true;
  
  // UNIFIED MEDIA LIST (Stores both Strings (URLs) and Files)
  // Index 0 is ALWAYS the Cover Photo.
  final List<dynamic> _mediaItems = [];
  
  final List<String> _availableTags = ['Academic', 'Tech', 'Food', 'Fun', 'Sports', 'Workshop', 'Arts'];
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    
    _titleController = TextEditingController(text: event?['title'] ?? '');
    _locationController = TextEditingController(text: event?['location'] ?? '');
    _descController = TextEditingController(text: event?['description'] ?? '');
    _linkController = TextEditingController(text: event?['registration_link'] ?? '');
    
    if (event != null) {
      _startDate = DateTime.parse(event['start_datetime']).toLocal();
      _endDate = event['end_datetime'] != null 
          ? DateTime.parse(event['end_datetime']).toLocal() 
          : _startDate!.add(const Duration(hours: 2));
      _isPublic = event['is_public'] ?? true;
      if (event['tags'] != null) {
        _selectedTags = List<String>.from(event['tags']);
      }

      // LOAD EXISTING MEDIA
      // 1. Cover
      if (event['image_url'] != null) {
        _mediaItems.add(event['image_url']);
      }
      // 2. Gallery
      if (event['gallery_urls'] != null) {
        _mediaItems.addAll(List<String>.from(event['gallery_urls']));
      }
    } else {
      _startDate = DateTime.now(); 
      _endDate = DateTime.now().add(const Duration(hours: 2));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // --- NEW: UNIFIED PICKER LOGIC ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.camera) {
        final XFile? picked = await picker.pickImage(source: ImageSource.camera);
        if (picked != null) {
          setState(() => _mediaItems.add(File(picked.path)));
        }
      } else {
        // Multi-picker for Gallery
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

  // --- SUBMIT LOGIC (SMART SORTING) ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one photo (Cover)")));
      return;
    }

    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    final supabase = Supabase.instance.client;

    try {
      String? finalCoverUrl;
      List<String> finalGalleryUrls = [];

      // Loop through all items and process them
      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];
        String url;

        if (item is File) {
          // It's a new file: Compress -> Upload
          final compressed = await ImageCompressor.compress(item);
          final path = 'events/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await supabase.storage.from('images').upload(path, compressed);
          url = supabase.storage.from('images').getPublicUrl(path);
        } else {
          // It's already a URL
          url = item as String;
        }

        // Assign first item to Cover, rest to Gallery
        if (i == 0) {
          finalCoverUrl = url;
        } else {
          finalGalleryUrls.add(url);
        }
      }

      final data = {
        'title': _titleController.text,
        'location': _locationController.text,
        'description': _descController.text,
        'registration_link': _linkController.text.isEmpty ? null : _linkController.text,
        'start_datetime': _startDate!.toUtc().toIso8601String(),
        'end_datetime': _endDate!.toUtc().toIso8601String(),
        'image_url': finalCoverUrl,      // Index 0
        'gallery_urls': finalGalleryUrls, // Index 1+
        'is_public': _isPublic,
        'tags': _selectedTags,
        'organizer_id': user!.id,
      };

      if (widget.eventToEdit != null) {
        await supabase.from('events').update(data).eq('id', widget.eventToEdit!['id']);
      } else {
        await supabase.from('events').insert(data);
      }
      
      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.eventToEdit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Event' : 'Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Event Media", topPad: 0),
              
              // --- UNIFIED MEDIA GRID ---
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
                  height: 140, // Height of the horizontal strip
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaItems.length + 1, // +1 for "Add More" button
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
                          width: 140, // Slightly wider to show detail
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item is File 
                                    ? Image.file(item, fit: BoxFit.cover) 
                                    : Image.network(item as String, fit: BoxFit.cover),
                              ),
                              
                              // "Cover" Badge
                              if (isCover)
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: const Text("COVER", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),

                              // Delete Button (Small X)
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
                  padding: EdgeInsets.only(top: 8),
                  child: Text("Tip: Tap a photo to set it as Cover or View.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),

              const SizedBox(height: 20),

              // ... REST OF THE FORM (Title, Date, etc.) ...
              _label("Event Title"),
              _input(_titleController, "Enter a catchy title"),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: _dateSelector(true)), // Helper below
                    const SizedBox(width: 12),
                    Expanded(child: _dateSelector(false)), // Helper below
                  ],
                ),
              ),

              _label("Location", topPad: 0),
              _input(_locationController, "e.g. Dewan Aspirasi"),

              _label("Registration Link (Optional)"),
              _input(_linkController, "https://forms.gle/...", icon: Icons.link),

              _label("Description"),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: _inputDeco("Tell us more...", theme),
              ),

              const SizedBox(height: 20),
              _label("Privacy"),
              SwitchListTile(
                title: const Text("Public Event"),
                value: _isPublic,
                activeThumbColor: theme.colorScheme.primary,
                onChanged: (val) => setState(() => _isPublic = val),
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
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
              : const Icon(Icons.publish),
          label: Text(_isLoading ? "Processing..." : "Publish Event"),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  // --- HELPER: Image Menu ---
  void _showImageMenu(int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (index != 0) // Only show "Make Cover" if it's not already cover
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Set as Cover Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    final item = _mediaItems.removeAt(index);
                    _mediaItems.insert(0, item); // Move to front
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

  // --- FORM HELPERS (Date, Input) ---
  Widget _dateSelector(bool isStart) {
    final date = isStart ? _startDate : _endDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(isStart ? "Starts" : "Ends", topPad: 0),
        GestureDetector(
          onTap: () => _pickDateTime(isStart),
          child: AbsorbPointer(
            child: _input(TextEditingController(text: _formatDate(date)), "Select", icon: Icons.calendar_today),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? now);
    
    final d = await showDatePicker(
      context: context, 
      firstDate: now.subtract(const Duration(days: 365)), 
      lastDate: now.add(const Duration(days: 365)), 
      initialDate: initial
    );
    if (d == null) return;
    
    if (mounted) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
      if (t == null) return;
      
      setState(() {
        final res = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        if (isStart) {
          _startDate = res;
          if (_endDate == null || _endDate!.isBefore(res)) _endDate = res.add(const Duration(hours: 2));
        } else {
          _endDate = res;
        }
      });
    }
  }

  String _formatDate(DateTime? d) => d == null ? '' : "${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2,'0')}";
  
  Widget _label(String text, {double topPad = 16}) => Padding(
    padding: EdgeInsets.only(bottom: 8, top: topPad), 
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))
  );

  Widget _input(TextEditingController c, String h, {IconData? icon}) => TextField(
    controller: c, 
    readOnly: icon != null,
    decoration: _inputDeco(h, Theme.of(context), icon: icon)
  );

  InputDecoration _inputDeco(String h, ThemeData t, {IconData? icon}) => InputDecoration(
    hintText: h, 
    suffixIcon: icon != null ? Icon(icon) : null, 
    filled: true, 
    fillColor: t.colorScheme.surfaceContainer, 
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
  );
}