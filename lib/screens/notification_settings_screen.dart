import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // These would typically sync with SharedPreferences or a 'user_settings' table
  bool _newEvents = true;
  bool _eventReminders = true;
  bool _marketplaceUpdates = false;
  bool _appUpdates = true;

  final primary = const Color(0xFF5B3E96);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
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