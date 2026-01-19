import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Listen to the 'notifications' table in real-time
        stream: Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId ?? '')
            .order('created_at'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;
          
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No notifications yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_,__) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final date = DateTime.parse(notif['created_at']);
              final timeAgo = DateFormat('MMM d, h:mm a').format(date);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  child: const Icon(Icons.campaign, color: Colors.purple),
                ),
                title: Text(notif['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notif['message']),
                    const SizedBox(height: 4),
                    Text(timeAgo, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                tileColor: (notif['is_read'] ?? false) ? null : Colors.purple.withOpacity(0.05),
                onTap: () async {
                  // Mark as read when tapped
                  await Supabase.instance.client
                      .from('notifications')
                      .update({'is_read': true})
                      .eq('id', notif['id']);
                },
              );
            },
          );
        },
      ),
    );
  }
}