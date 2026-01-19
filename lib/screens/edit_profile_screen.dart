import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_cubit.dart'; // Ensure this matches the file name exactly

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  File? _pickedImage; 

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    // Check if context is valid and state exists
    final state = context.read<ProfileCubit>().state;
    if (state.profile != null) {
      _nameCtrl.text = state.profile!['full_name'] ?? '';
      _phoneCtrl.text = state.profile!['phone_number'] ?? '';
      _bioCtrl.text = state.profile!['bio'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _pickedImage = File(pickedFile.path));
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading image...")));
         await context.read<ProfileCubit>().uploadAvatar(_pickedImage!);
      }
    }
  }

  Future<void> _saveProfile() async {
    await context.read<ProfileCubit>().updateProfile(
      fullName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      bio: _bioCtrl.text,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for specific changes
    final isLoading = context.select((ProfileCubit c) => c.state.isLoading);
    final profile = context.select((ProfileCubit c) => c.state.profile);

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!) as ImageProvider
                        : NetworkImage(profile?['avatar_url'] ?? 'https://via.placeholder.com/150'),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
            const SizedBox(height: 16),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: "Phone Number")),
            const SizedBox(height: 16),
            TextField(controller: _bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Bio")),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveProfile,
                child: isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) 
                  : const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}