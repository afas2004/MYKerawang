import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    // Magenta Theme
    final primaryColor = const Color(0xFF7B1FA2); // Purple from detail html
    final date = DateTime.parse(event['start_datetime']);
    
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: event['image_url'] != null
                    ? Image.network(event['image_url'], fit: BoxFit.cover)
                    : Container(color: Colors.grey[300], child: const Icon(Icons.event, size: 80, color: Colors.grey)),
                ),
                actions: [
                  IconButton(onPressed: (){}, icon: const Icon(Icons.more_vert)),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['title'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // Tags
                      Wrap(
                        spacing: 8,
                        children: ["Workshop", "Technology", "Career"].map((t) => 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text("#$t", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 12)),
                          )
                        ).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Info Rows
                      _infoRow(Icons.calendar_month, DateFormat('EEE, d MMM yyyy • h:mm a').format(date), primaryColor),
                      _infoRow(Icons.location_on, event['location'] ?? 'TBA', primaryColor),
                      _infoRow(Icons.group, "128 people going", primaryColor),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),

                      const Text("About this event", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        event['description'] ?? 'No description.',
                        style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[800]),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Organizer Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.school)),
                            const SizedBox(width: 12),
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text("UiTM Kerawang Events", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("Organizer", style: TextStyle(fontSize: 12, color: Colors.grey))
                            ])),
                            TextButton(onPressed: (){}, child: const Text("Follow"))
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              )
            ],
          ),
          
          // Bottom Sticky Bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    _actionIcon(Icons.favorite_border, "Favourite"),
                    _actionIcon(Icons.share, "Share"),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Join Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }
}