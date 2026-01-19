import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

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
  bool _isLoading = true;

  final primary = const Color(0xFF5B3E96);
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 1. Fetch current settings from Supabase
  Future<void> _loadSettings() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('notify_new_events, notify_reminders, notify_marketplace')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _newEvents = profile['notify_new_events'] ?? true;
          _eventReminders = profile['notify_reminders'] ?? true;
          _marketplaceUpdates = profile['notify_marketplace'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Save changes to Supabase instantly
  Future<void> _updateSetting(String column, bool value) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('profiles').update({column: value}).eq('id', user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving setting: $e")));
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader("Event Alerts"),
              SwitchListTile(
                title: const Text("New Events"),
                subtitle: const Text("Get notified when new events are posted"),
                value: _newEvents,
                activeThumbColor: primary,
                onChanged: (v) {
                  setState(() => _newEvents = v);
                  _updateSetting('notify_new_events', v); // Save to DB
                },
              ),
              SwitchListTile(
                title: const Text("Reminders"),
                subtitle: const Text("1 hour before events you joined"),
                value: _eventReminders,
                activeThumbColor: primary,
                onChanged: (v) {
                  setState(() => _eventReminders = v);
                  _updateSetting('notify_reminders', v); // Save to DB
                },
              ),
              
              const Divider(height: 40),
              _sectionHeader("Marketplace"),
              SwitchListTile(
                title: const Text("Price Drops"),
                subtitle: const Text("Notify when saved items drop in price"),
                value: _marketplaceUpdates,
                activeThumbColor: primary,
                onChanged: (v) {
                  setState(() => _marketplaceUpdates = v);
                  _updateSetting('notify_marketplace', v); // Save to DB
                },
              ),
              
              const Divider(height: 40),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
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