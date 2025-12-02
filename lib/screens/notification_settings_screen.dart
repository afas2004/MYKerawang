import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Orange primary from notification_center.settings.html
  final primary = const Color(0xFFf98c1f);
  
  String _category = 'Events';
  bool _newEvents = true;
  bool _reminders = false;
  bool _updates = true;
  String _freq = 'Instant Push';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfcfaf8),
      appBar: AppBar(
        title: const Text("Notification Settings"),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Segmented Control
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFf4ede6), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                _segment("Events"),
                _segment("Marketplace"),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Events", style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                ),
                _switchTile(Icons.campaign, "New Event Announcements", "Get notified when a new campus event is posted.", _newEvents, (v) => setState(() => _newEvents = v)),
                
                // Radio Options for Frequency
                if (_newEvents) ...[
                  _radioTile("Instant Push"),
                  _radioTile("Daily Digest"),
                ],
                const Divider(),

                _switchTile(Icons.notifications_active, "Event Reminders", "Get a reminder 1 hour before.", _reminders, (v) => setState(() => _reminders = v)),
                const Divider(),
                _switchTile(Icons.event_busy, "Updates & Cancellations", "Critical info about event changes.", _updates, (v) => setState(() => _updates = v)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                  shadowColor: primary.withOpacity(0.4),
                ),
                child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _segment(String text) {
    final isSelected = _category == text;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _category = text),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: isSelected ? Colors.black : const Color(0xFF9e7347))
          ),
        ),
      ),
    );
  }

  Widget _switchTile(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFf4ede6), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: Color(0xFF9e7347), fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeColor: primary,
          )
        ],
      ),
    );
  }

  Widget _radioTile(String value) {
    return RadioListTile(
      value: value,
      groupValue: _freq,
      onChanged: (v) => setState(() => _freq = v.toString()),
      activeColor: primary,
      title: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}