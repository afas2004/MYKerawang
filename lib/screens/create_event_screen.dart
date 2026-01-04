import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'image_preview_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _selectedDate;
  File? _imageFile;
  bool _isLoading = false;
  String _privacy = 'Public';

  final primaryColor = const Color(0xFF00A7C7);
  final bgColor = const Color(0xFFF8F9FA);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context, 
      firstDate: now, 
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
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
              title: const Text('Camera'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
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
      String? imageUrl;
      
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final path = 'events/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        // Ensure 'images' bucket exists in dashboard
        await supabase.storage.from('images').upload(path, _imageFile!);
        imageUrl = supabase.storage.from('images').getPublicUrl(path);
      }

      await supabase.from('events').insert({
        'title': _titleController.text,
        'location': _locationController.text,
        'description': _descController.text,
        'start_datetime': _selectedDate!.toIso8601String(),
        'image_url': imageUrl,
        'is_public': _privacy == 'Public',
        'organizer_id': user.id,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Published!')));
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Storage Error: ${e.message}. Bucket "images" missing?'),
          backgroundColor: Colors.red,
        ));
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
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Create New Event'),
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
              children: ["Free", "Paid", "Academic", "Other"].map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: Colors.white,
                  shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
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
                if (_imageFile == null) {
                  _showImageOptions();
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ImagePreviewScreen(imageFile: _imageFile)));
                }
              },
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null,
                ),
                child: _imageFile == null 
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
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _showImageOptions,
                      icon: const Icon(Icons.edit),
                      label: const Text("Change"),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _imageFile = null),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text("Remove", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            _label("Privacy"),
            Row(
              children: [
                Expanded(child: _privacyBtn("Public", Icons.public, _privacy == 'Public')),
                const SizedBox(width: 12),
                Expanded(child: _privacyBtn("Club-Only", Icons.group, _privacy == 'Club-Only')),
              ],
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
                label: const Text("Publish"),
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

  Widget _privacyBtn(String text, IconData icon, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _privacy = text),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: selected ? primaryColor.withOpacity(0.1) : Colors.white,
          border: Border.all(color: selected ? primaryColor : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? primaryColor : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: selected ? primaryColor : Colors.grey[600], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}