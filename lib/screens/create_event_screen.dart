import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? eventToEdit; 

  const CreateEventScreen({super.key, this.eventToEdit});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descController;
  
  DateTime? _startDate;
  DateTime? _endDate; // NEW: Added End Date
  
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isPublic = true;
  
  final List<String> _availableTags = ['Academic', 'Tech', 'Food', 'Fun', 'Sports', 'Workshop', 'Arts'];
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    
    _titleController = TextEditingController(text: event?['title'] ?? '');
    _locationController = TextEditingController(text: event?['location'] ?? '');
    _descController = TextEditingController(text: event?['description'] ?? '');
    
    if (event != null) {
      _startDate = DateTime.parse(event['start_datetime']).toLocal();
      // Load End Date or default to Start + 2 hours
      _endDate = event['end_datetime'] != null 
          ? DateTime.parse(event['end_datetime']).toLocal() 
          : _startDate!.add(const Duration(hours: 2));
          
      _existingImageUrl = event['image_url'];
      _isPublic = event['is_public'] ?? true;
      if (event['tags'] != null) {
        _selectedTags = List<String>.from(event['tags']);
      }
    }
  }

  // Unified Date Picker Logic
  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart 
        ? (_startDate ?? now) 
        : (_endDate ?? _startDate ?? now);
        
    final pickedDate = await showDatePicker(
      context: context, 
      firstDate: now.subtract(const Duration(days: 1)), // Allow slightly past for editing
      lastDate: now.add(const Duration(days: 365)),
      initialDate: initialDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme, // Use App Theme
          ),
          child: child!,
        );
      }
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context, 
        initialTime: TimeOfDay.fromDateTime(initialDate)
      );
      
      if (pickedTime != null) {
        final finalDateTime = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day, 
          pickedTime.hour, pickedTime.minute
        );

        setState(() {
          if (isStart) {
            _startDate = finalDateTime;
            // Smart UX: If End Date is missing or before Start Date, auto-fix it
            if (_endDate == null || _endDate!.isBefore(_startDate!)) {
              _endDate = _startDate!.add(const Duration(hours: 2));
            }
          } else {
            // Validation: End Date cannot be before Start Date
            if (_startDate != null && finalDateTime.isBefore(_startDate!)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('End time cannot be before Start time'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              );
              return;
            }
            _endDate = finalDateTime;
          }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: Theme.of(context).colorScheme.primary),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill title and dates'),
          backgroundColor: Theme.of(context).colorScheme.error,
        )
      );
      return;
    }
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String? imageUrl = _existingImageUrl;
      
      if (_imageFile != null) {
        // Simple compression by extension (Use standard jpg/png)
        final fileExt = _imageFile!.path.split('.').last;
        final path = 'events/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        await supabase.storage.from('images').upload(path, _imageFile!);
        imageUrl = supabase.storage.from('images').getPublicUrl(path);
      }

      final data = {
        'title': _titleController.text,
        'location': _locationController.text,
        'description': _descController.text,
        
        // SAVE UTC DATES
        'start_datetime': _startDate!.toUtc().toIso8601String(),
        'end_datetime': _endDate!.toUtc().toIso8601String(),
        
        'image_url': imageUrl,
        'is_public': _isPublic,
        'tags': _selectedTags,
        'organizer_id': user.id,
      };

      if (widget.eventToEdit != null) {
        await supabase.from('events').update(data).eq('id', widget.eventToEdit!['id']);
      } else {
        await supabase.from('events').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.eventToEdit != null ? 'Event Updated!' : 'Event Published!'),
            backgroundColor: Colors.green,
          )
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;
    final theme = Theme.of(context); // Cache theme for cleaner code

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create New Event'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1), 
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.1))
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label("Event Title"),
            _input(_titleController, "Enter a catchy title"),
            
            // --- DATE ROW (START & END) ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Starts", topPad: 0),
                        GestureDetector(
                          onTap: () => _pickDateTime(true),
                          child: AbsorbPointer(
                            child: _input(
                              TextEditingController(text: _formatDate(_startDate)), 
                              "Select Start", 
                              icon: Icons.calendar_today
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label("Ends", topPad: 0),
                        GestureDetector(
                          onTap: () => _pickDateTime(false),
                          child: AbsorbPointer(
                            child: _input(
                              TextEditingController(text: _formatDate(_endDate)), 
                              "Select End", 
                              icon: Icons.event_busy
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            _label("Location", topPad: 0),
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
                      selected ? _selectedTags.add(tag) : _selectedTags.remove(tag);
                    });
                  },
                  // Dynamic Colors
                  selectedColor: theme.colorScheme.secondaryContainer,
                  checkmarkColor: theme.colorScheme.onSecondaryContainer,
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  labelStyle: TextStyle(
                    color: isSelected 
                      ? theme.colorScheme.onSecondaryContainer 
                      : theme.colorScheme.onSurface,
                  ),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _label("Description"),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: _inputDeco("Tell us more...", theme),
            ),

            const SizedBox(height: 20),
            
            _label("Event Media"),
            GestureDetector(
              onTap: () => _showImageOptions(),
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
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
                          Icon(Icons.add_a_photo, color: theme.colorScheme.primary, size: 40),
                          const SizedBox(height: 8),
                          Text("Add Event Photo", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 20),
            _label("Privacy"),
            SwitchListTile(
              title: const Text("Public Event"),
              subtitle: Text("Visible to everyone", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              value: _isPublic,
              activeThumbColor: theme.colorScheme.primary,
              onChanged: (val) => setState(() => _isPublic = val),
            ),
            const SizedBox(height: 80), // Bottom padding for FAB/Button
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, 
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1)))
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                    : const Icon(Icons.publish),
                label: Text(_isLoading ? "Processing..." : (isEditing ? "Save Changes" : "Publish Event")),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return "${date.day}/${date.month} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}";
  }

  Widget _label(String text, {double topPad = 16}) => Padding(
    padding: EdgeInsets.only(bottom: 8, top: topPad), 
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))
  );
  
  Widget _input(TextEditingController ctrl, String hint, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      decoration: _inputDeco(hint, Theme.of(context), icon: icon),
      readOnly: icon != null, // Make read-only if it has an icon (implies picker)
    );
  }

  InputDecoration _inputDeco(String hint, ThemeData theme, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: icon != null ? Icon(icon, color: theme.colorScheme.onSurfaceVariant) : null,
      filled: true,
      // Adaptive Background Color
      fillColor: theme.colorScheme.surfaceContainer, 
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide(color: theme.colorScheme.primary)
      ),
    );
  }
}