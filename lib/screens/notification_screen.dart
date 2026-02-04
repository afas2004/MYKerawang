import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: userId == null 
        ? const Center(child: Text("Please login to see notifications"))
        : StreamBuilder(
            stream: Supabase.instance.client
                .from('notifications')
                .stream(primaryKey: ['id'])
                .eq('user_id', userId)
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final notifications = snapshot.data!;
              if (notifications.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No new notifications"),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_,__) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  final isRead = notif['is_read'] ?? false;
                  
                  return ListTile(
                    tileColor: isRead ? null : Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    leading: CircleAvatar(
                      backgroundColor: isRead ? Colors.grey[200] : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.notifications, color: isRead ? Colors.grey : Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(notif['title'], style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text(notif['body'] ?? notif['message'] ?? ''),
                    trailing: Text(
                      timeago.format(DateTime.parse(notif['created_at']), locale: 'en_short'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      // Mark as read
                      Supabase.instance.client.from('notifications').update({'is_read': true}).eq('id', notif['id']);
                    },
                  );
                },
              );
            },
          ),
    );
  }
}