import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// Ensure this exists

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? eventToEdit; // NEW: Event to edit

  const CreateEventScreen({super.key, this.eventToEdit});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descController;
  DateTime? _selectedDate;
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isPublic = true;
  
  final List<String> _availableTags = ['Academic', 'Tech', 'Food', 'Fun', 'Sports', 'Workshop', 'Arts'];
  List<String> _selectedTags = [];

  final primaryColor = const Color(0xFF00A7C7);
  final bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    
    _titleController = TextEditingController(text: event?['title'] ?? '');
    _locationController = TextEditingController(text: event?['location'] ?? '');
    _descController = TextEditingController(text: event?['description'] ?? '');
    
    if (event != null) {
      _selectedDate = DateTime.parse(event['start_datetime']);
      _existingImageUrl = event['image_url'];
      _isPublic = event['is_public'] ?? true;
      if (event['tags'] != null) {
        _selectedTags = List<String>.from(event['tags']);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context, 
      firstDate: now.subtract(const Duration(days: 365)), // Allow past dates if editing old event
      lastDate: now.add(const Duration(days: 365)),
      initialDate: initial,
    );
    if (picked != null) {
      if (mounted) {
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
        if (time != null) {
          setState(() {
            _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
          });
        }
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showImageOptions() {
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
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill title and date')));
      return;
    }
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String? imageUrl = _existingImageUrl;
      
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final path = 'events/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await supabase.storage.from('images').upload(path, _imageFile!);
        imageUrl = supabase.storage.from('images').getPublicUrl(path);
      }

      final data = {
        'title': _titleController.text,
        'location': _locationController.text,
        'description': _descController.text,
        'start_datetime': _selectedDate!.toIso8601String(),
        'image_url': imageUrl,
        'is_public': _isPublic,
        'tags': _selectedTags,
        'organizer_id': user.id,
      };

      if (widget.eventToEdit != null) {
        // UPDATE
        await supabase.from('events').update(data).eq('id', widget.eventToEdit!['id']);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Updated!')));
      } else {
        // INSERT
        await supabase.from('events').insert(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Published!')));
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create New Event'),
        backgroundColor: bgColor,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: Colors.grey[200])),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label("Event Title"),
            _input(_titleController, "Enter a catchy title"),
            
            _label("Date & Time"),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: _input(TextEditingController(text: _selectedDate?.toLocal().toString().split('.')[0] ?? ''), "Select date", icon: Icons.calendar_today),
              ),
            ),
            
            _label("Location"),
            _input(_locationController, "e.g. Dewan Aspirasi"),

            _label("Tags"),
            Wrap(
              spacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  selectedColor: primaryColor.withOpacity(0.2),
                  checkmarkColor: primaryColor,
                  backgroundColor: Colors.white,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _label("Description"),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: _inputDeco("Tell us more..."),
            ),

            const SizedBox(height: 20),
            
            _label("Event Media"),
            GestureDetector(
              onTap: () {
                if (_imageFile == null && _existingImageUrl == null) {
                  _showImageOptions();
                } else {
                   _showImageOptions();
                }
              },
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  image: _imageFile != null 
                      ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                      : (_existingImageUrl != null 
                          ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover) 
                          : null),
                ),
                child: (_imageFile == null && _existingImageUrl == null)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: primaryColor, size: 40),
                          const SizedBox(height: 8),
                          Text("Add Event Photo", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 20),
            _label("Privacy"),
            SwitchListTile(
              title: const Text("Public Event"),
              subtitle: const Text("Visible to everyone"),
              value: _isPublic,
              activeThumbColor: primaryColor,
              onChanged: (val) => setState(() => _isPublic = val),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor, border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: const Icon(Icons.publish),
                label: Text(isEditing ? "Save Changes" : "Publish"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 16), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)));
  
  Widget _input(TextEditingController ctrl, String hint, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      decoration: _inputDeco(hint, icon: icon),
    );
  }

  InputDecoration _inputDeco(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor)),
    );
  }
}