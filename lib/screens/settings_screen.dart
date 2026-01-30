import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';
import 'package:mykerawang/theme_cubit.dart';

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
    final themeState = context.watch<ThemeCubit>().state;
    final isDarkMode = themeState.themeMode == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader("Event Alerts"),
              SwitchListTile(
                title: const Text("Dark Mode"),
                subtitle: const Text("Easy on the eyes"),
                secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
                value: isDarkMode,
                onChanged: (val) => context.read<ThemeCubit>().toggleTheme(val),
              ),
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
              ListTile(
                leading: const Icon(Icons.settings_applications, color: Colors.orange),
                title: const Text("Fix Notification Permissions"),
                subtitle: const Text("Open system settings to enable"),
                onTap: () async {
                  // This forces the phone's App Settings page to open
                  await openAppSettings(); 
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
              // --- COLOR PICKER ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text("App Theme", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
              Builder(
                builder: (context) {
                  // 1. Get the current active color
                  final currentSeed = context.watch<ThemeCubit>().state.seedColor;

                  // 2. Helper to check if colors match (safer to compare integer values)
                  bool isSelected(Color c) => currentSeed.value == c.value;

                  return SizedBox(
                    height: 60,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _colorButton(context, const Color(0xFF5B3E96), isSelected(const Color(0xFF5B3E96))), // UiTM Purple
                        _colorButton(context, Colors.blue, isSelected(Colors.blue)),
                        _colorButton(context, Colors.teal, isSelected(Colors.teal)),
                        _colorButton(context, Colors.orange, isSelected(Colors.orange)),
                        _colorButton(context, Colors.red, isSelected(Colors.red)),
                        _colorButton(context, Colors.green, isSelected(Colors.green)),
                      ],
                    ),
                  );
                },
              ),
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

Widget _colorButton(BuildContext context, Color color, bool isSelected) {
  return GestureDetector(
    onTap: () => context.read<ThemeCubit>().changeColor(color),
    child: Container(
      width: 45, // Made slightly bigger for better touch target
      height: 45,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          // Highlight the border if selected
          color: isSelected ? Colors.black : Colors.grey.shade300, 
          width: isSelected ? 3 : 2,
        ),
        boxShadow: isSelected 
            ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] 
            : [],
      ),
      // SHOW CHECKMARK IF SELECTED
      child: isSelected 
          ? const Icon(Icons.check, color: Colors.white, size: 24) 
          : null,
    ),
  );
}