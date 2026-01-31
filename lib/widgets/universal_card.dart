import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class UniversalCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  
  // Logic: If it has 'price', it's a listing. If it has 'start_datetime', it's an event.
  // We can pass a manual 'isEvent' override if needed, but auto-detection usually works.
  const UniversalCard({
    super.key, 
    required this.data, 
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isListing = data.containsKey('price');
    final title = data['title'] ?? 'No Title';
    final image = data['image_url'] ?? '';
    
    // Formatted Subtitle logic
    String badgeText = '';
    Color badgeColor = Theme.of(context).colorScheme.primary;
    
    if (isListing) {
      badgeText = "RM ${(data['price'] as num).toStringAsFixed(2)}";
      badgeColor = Colors.orange; // Money is usually Gold/Orange
    } else {
      if (data['start_datetime'] != null) {
        final date = DateTime.parse(data['start_datetime']).toLocal();
        badgeText = DateFormat('d MMM').format(date); // e.g. "14 Jan"
      } else {
        badgeText = "Event";
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160, // Standard width for horizontal lists
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer, // Dark Mode Safe
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- IMAGE SECTION ---
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero, // No flicker
                      placeholder: (context, url) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  // --- BADGE (Price or Date) ---
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: isListing ? Colors.orangeAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // --- TEXT SECTION ---
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isListing ? (data['category'] ?? 'Item') : (data['location'] ?? 'UiTM'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}