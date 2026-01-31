import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(); // <--- NEW CONTROLLER
  
  bool _isLoading = false;
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

    final data = await Supabase.instance.client.from('profiles').select().eq('id', user.id).single();
    
    setState(() {
      _nameCtrl.text = data['display_name'] ?? '';
      _bioCtrl.text = data['bio'] ?? '';
      _websiteCtrl.text = data['website'] ?? '';
      _phoneCtrl.text = data['phone_number'] ?? ''; // <--- LOAD PHONE
      _currentAvatarUrl = data['avatar_url'];
      _currentQrUrl = data['payment_qr_url'];
    });
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

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    final supabase = Supabase.instance.client;

    try {
      String? newAvatarUrl = _currentAvatarUrl;
      String? newQrUrl = _currentQrUrl;

      // 1. Upload Images (Avatar & QR)
      if (_avatarFile != null) {
        final path = 'avatars/${user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('images').upload(path, _avatarFile!);
        newAvatarUrl = supabase.storage.from('images').getPublicUrl(path);
      }
      if (_qrFile != null) {
        final uniquePath = 'qrs/${user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('images').upload(uniquePath, _qrFile!);
        newQrUrl = supabase.storage.from('images').getPublicUrl(uniquePath);
      }

      // 2. Update Profile
      await supabase.from('profiles').update({
        'display_name': _nameCtrl.text,
        'bio': _bioCtrl.text,
        'website': _websiteCtrl.text,
        'phone_number': _phoneCtrl.text, // <--- SAVE PHONE
        'avatar_url': newAvatarUrl,
        'payment_qr_url': newQrUrl,
      }).eq('id', user!.id);

      if (mounted) {
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
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
        title: const Text("Edit Profile"),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar Section
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

          // Basic Info
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: "Display Name", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Bio", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          
          // Contact Info
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "WhatsApp Number", 
              hintText: "e.g. 60123456789 (No + symbol)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _websiteCtrl,
            decoration: const InputDecoration(labelText: "Website / Social Link", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),

          // Payment QR
          const Text("DuitNow QR (For Selling)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickImage(false),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                image: _qrFile != null 
                    ? DecorationImage(image: FileImage(_qrFile!), fit: BoxFit.cover)
                    : (_currentQrUrl != null ? DecorationImage(image: NetworkImage(_currentQrUrl!), fit: BoxFit.cover) : null),
              ),
              child: (_qrFile == null && _currentQrUrl == null)
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 40, color: Colors.grey),
                        Text("Upload QR Code Image"),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}