import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  String _privacy = 'Public'; // Public vs Club-Only

  // Colors from code.html
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

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _selectedDate == null) return;
    
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      String? imageUrl;
      if (_imageFile != null) {
        final path = 'events/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
        'organizer_id': supabase.auth.currentUser?.id,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
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
                child: _input(TextEditingController(text: _selectedDate?.toString().split('.')[0] ?? ''), "Select date", icon: Icons.calendar_today),
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
            Row(
              children: [
                Expanded(child: _mediaButton(Icons.photo_camera, "Camera")),
                const SizedBox(width: 12),
                Expanded(child: _mediaButton(Icons.photo_library, "Gallery", isGallery: true)),
              ],
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

  Widget _mediaButton(IconData icon, String text, {bool isGallery = false}) {
    return GestureDetector(
      onTap: () async {
        final src = isGallery ? ImageSource.gallery : ImageSource.camera;
        final f = await ImagePicker().pickImage(source: src);
        if (f != null) setState(() => _imageFile = File(f.path));
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primaryColor, size: 30),
            const SizedBox(height: 4),
            Text(text, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500))
          ],
        ),
      ),
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