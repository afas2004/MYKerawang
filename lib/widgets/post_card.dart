import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago; // Add 'timeago' to pubspec.yaml if missing

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAnon = post['is_anonymous'] ?? false;
    final theme = Theme.of(context);
    
    // Safety check for date
    final createdVal = post['created_at'];
    final date = createdVal != null ? DateTime.parse(createdVal) : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0, // Flat look like Reddit/Twitter
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0), // Full width look
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      color: theme.cardColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER (User + Time)
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isAnon ? Colors.grey : theme.colorScheme.primaryContainer,
                    child: Icon(
                      isAnon ? Icons.visibility_off : Icons.person,
                      size: 14,
                      color: isAnon ? Colors.white : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAnon ? "Anonymous Student" : "UiTM Student",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "• ${timeago.format(date, locale: 'en_short')}",
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const Spacer(),
                  if (post['tags'] != null && (post['tags'] as List).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "#${post['tags'][0]}",
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. TITLE (The "Hook")
              Text(
                post['title'] ?? 'No Title',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // 3. BODY PREVIEW
              if (post['body'] != null)
                Text(
                  post['body'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                ),
              
              // 4. SHARED EVENT (If any)
              if (post['shared_event_id'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text("Shared an Event", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // 5. FOOTER (Votes & Comments)
              Row(
                children: [
                  _actionIcon(Icons.arrow_upward, "${post['upvotes'] ?? 0}", theme),
                  const SizedBox(width: 16),
                  _actionIcon(Icons.chat_bubble_outline, "${post['comment_count'] ?? 0}", theme),
                  const Spacer(),
                  Icon(Icons.share_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}