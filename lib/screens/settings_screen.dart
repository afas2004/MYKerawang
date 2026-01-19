import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart'; // Ensure this matches your file structure

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Toggle states
  bool _newEvents = true;
  bool _eventReminders = true;
  bool _marketplaceUpdates = false;
  bool _appUpdates = true;

  final primary = const Color(0xFF5B3E96);

  Future<void> _signOut() async {
    try {
      // 1. Log out from Supabase
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        // 2. Clear navigation stack and go to Login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // This removes all previous screens (can't go back)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error signing out: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("Event Alerts"),
          SwitchListTile(
            title: const Text("New Events"),
            subtitle: const Text("Get notified when new events are posted"),
            value: _newEvents,
            activeThumbColor: primary,
            onChanged: (v) => setState(() => _newEvents = v),
          ),
          SwitchListTile(
            title: const Text("Reminders"),
            subtitle: const Text("1 hour before events you joined"),
            value: _eventReminders,
            activeThumbColor: primary,
            onChanged: (v) => setState(() => _eventReminders = v),
          ),
          
          const Divider(height: 40),
          _sectionHeader("Marketplace"),
          SwitchListTile(
            title: const Text("Price Drops"),
            subtitle: const Text("Notify when saved items drop in price"),
            value: _marketplaceUpdates,
            activeThumbColor: primary,
            onChanged: (v) => setState(() => _marketplaceUpdates = v),
          ),
          
          const Divider(height: 40),
          _sectionHeader("System"),
          SwitchListTile(
            title: const Text("App Updates"),
            value: _appUpdates,
            activeThumbColor: primary,
            onChanged: (v) => setState(() => _appUpdates = v),
          ),

          const Divider(height: 40),
          
          // SIGN OUT BUTTON
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _signOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50], // Light red background
                foregroundColor: Colors.red,     // Red text
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                side: const BorderSide(color: Colors.red, width: 1),
              ),
              child: const Text("Sign Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text("Version 1.0.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 16),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }
}