import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/image_compressor.dart'; // Ensure you have this file from previous steps

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController(); // <--- NEW
  final _bioCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _originalUsername;
  
  // Images
  File? _avatarFile;
  File? _qrFile;
  String? _currentAvatarUrl;
  String? _currentQrUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client.from('profiles').select().eq('id', user.id).single();
      
      setState(() {
        _nameCtrl.text = data['display_name'] ?? '';
        _usernameCtrl.text = data['username'] ?? ''; // <--- NEW
        _bioCtrl.text = data['bio'] ?? '';
        _websiteCtrl.text = data['website'] ?? '';
        _phoneCtrl.text = data['phone_number'] ?? '';
        
        _currentAvatarUrl = data['avatar_url'];
        _currentQrUrl = data['payment_qr_url'];
        
        _originalUsername = data['username']; // Keep track for uniqueness check
        
      });
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        if (isAvatar) {
          _avatarFile = File(picked.path);
        } else {
          _qrFile = File(picked.path);
        }
      });
    }
  }

  // --- VALIDATION HELPER ---
  Future<bool> _isUsernameTaken(String username) async {
    if (username == _originalUsername) return false; // No change = Safe

    final result = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
        
    return result != null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return "Username is required";
    if (value.length < 3) return "Min 3 chars";
    // Regex: Only letters, numbers, underscore
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) return "Only letters, numbers, '_'";
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = Supabase.instance.client.auth.currentUser;
    final supabase = Supabase.instance.client;

    try {
      final newUsername = _usernameCtrl.text.trim().toLowerCase();

      // 1. Check Username Uniqueness
      if (await _isUsernameTaken(newUsername)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Username @$newUsername is already taken."), backgroundColor: Colors.red),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      String? newAvatarUrl = _currentAvatarUrl;
      String? newQrUrl = _currentQrUrl;

      // 2. Upload Images (With Compression)
      if (_avatarFile != null) {
        // Try compressing, fallback to original if utility missing
        final fileToUpload = await ImageCompressor.compress(_avatarFile!);
        final path = 'avatars/${user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('images').upload(path, fileToUpload);
        newAvatarUrl = supabase.storage.from('images').getPublicUrl(path);
      }
      
      if (_qrFile != null) {
        final fileToUpload = await ImageCompressor.compress(_qrFile!);
        final uniquePath = 'qrs/${user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('images').upload(uniquePath, fileToUpload);
        newQrUrl = supabase.storage.from('images').getPublicUrl(uniquePath);
      }

      // 3. Update Database
      await supabase.from('profiles').update({
        'display_name': _nameCtrl.text.trim(),
        'username': newUsername, // <--- NEW
        'bio': _bioCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'avatar_url': newAvatarUrl,
        'payment_qr_url': newQrUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user!.id);

      if (mounted) {
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- AVATAR ---
            Center(
              child: GestureDetector(
                onTap: () => _pickImage(true),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _avatarFile != null 
                    ? FileImage(_avatarFile!) 
                    : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) : null) as ImageProvider?,
                  child: _avatarFile == null && _currentAvatarUrl == null 
                    ? const Icon(Icons.camera_alt, size: 30) 
                    : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- USERNAME & NAME ---
            TextFormField(
              controller: _usernameCtrl,
              decoration: _inputDeco("Username (Unique ID)").copyWith(prefixText: "@ "),
              validator: _validateUsername,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco("Display Name"),
              validator: (v) => v!.isEmpty ? "Name required" : null,
            ),
            const SizedBox(height: 16),
            
            // --- BIO ---
            TextFormField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: _inputDeco("Bio"),
              maxLength: 150,
            ),
            const SizedBox(height: 16),

            
            // --- CONTACT INFO ---
            const Divider(),
            const SizedBox(height: 16),
            const Text("Contact Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 0123456789',
                prefixText: '+60 ', // Visual cue
              ),
              // 1. Show Number Pad only
              keyboardType: TextInputType.phone, 
              
              // 2. BLOCK letters/symbols completely
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // Only allows 0-9
                LengthLimitingTextInputFormatter(11),   // Limit length (optional)
              ],
              validator: (val) {
                if (val == null || val.length < 9) return "Please enter a valid number";
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _websiteCtrl,
              decoration: _inputDeco("Website / Link"),
            ),
            const SizedBox(height: 24),

            // --- DUITNOW QR ---
            const Text("DuitNow QR (For Selling)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickImage(false),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest,
                  image: _qrFile != null 
                      ? DecorationImage(image: FileImage(_qrFile!), fit: BoxFit.cover)
                      : (_currentQrUrl != null ? DecorationImage(image: NetworkImage(_currentQrUrl!), fit: BoxFit.cover) : null),
                ),
                child: (_qrFile == null && _currentQrUrl == null)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, size: 40, color: theme.colorScheme.onSurfaceVariant),
                          Text("Upload QR Image", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainer,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}