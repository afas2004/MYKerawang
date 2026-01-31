import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UniversalCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const UniversalCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = data['title'] ?? 'No Title';
    final image = data['image_url'];
    
    // Determine subtitle based on type (Event date vs Price)
    String subtitle = '';
    bool isEvent = data.containsKey('start_datetime');
    
    if (isEvent) {
      final date = DateTime.parse(data['start_datetime']);
      subtitle = DateFormat('d MMM, h:mm a').format(date);
    } else {
      // Marketplace item
      double price = (data['price'] ?? 0).toDouble();
      subtitle = "RM ${price.toStringAsFixed(2)}";
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // REMOVED: height property (Let content decide height)
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
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
          mainAxisSize: MainAxisSize.min, // <--- CRITICAL: Shrink-wraps the card
          children: [
            // 1. IMAGE SECTION
            // FIX: Replaced 'Expanded' with 'AspectRatio' or 'SizedBox'
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 150, // <--- FIXED HEIGHT for Image
                width: double.infinity,
                child: image != null
                    ? CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainerHighest),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          isEvent ? Icons.event : Icons.store, 
                          size: 40, 
                          color: theme.colorScheme.onSurfaceVariant
                        ),
                      ),
              ),
            ),

            // 2. TEXT SECTION
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge (Event/Market)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isEvent 
                          ? theme.colorScheme.primaryContainer 
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isEvent ? 'EVENT' : 'MARKET',
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: isEvent 
                            ? theme.colorScheme.onPrimaryContainer 
                            : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant, 
                      fontSize: 14,
                      fontWeight: FontWeight.w500
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