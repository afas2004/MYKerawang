import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'events_cubit.dart'; // Ensure this matches your file structure

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Provide the Cubit
    return BlocProvider(
      create: (context) => EventsCubit(),
      child: const EventsView(),
    );
  }
}

class EventsView extends StatefulWidget {
  const EventsView({super.key});

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  // Tags must tally with what you save in Create Event
  final List<String> _tags = ['All', 'Academic', 'Tech', 'Food', 'Fun', 'Sports', 'Workshop'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Consume the State
    return BlocBuilder<EventsCubit, EventsState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Events"),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    // Read selection from State
                    final isSelected = state.selectedTag == tag;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        // Call Cubit
                        onSelected: (v) => context.read<EventsCubit>().updateTag(tag),
                        backgroundColor: Colors.white,
                        selectedColor: Colors.purple[100],
                        checkmarkColor: Colors.purple,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchCtrl,
                        // Call Cubit
                        onChanged: (v) => context.read<EventsCubit>().updateSearch(v),
                        decoration: InputDecoration(
                          hintText: "Search events...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Expanded(
                      child: state.displayedEvents.isEmpty
                          ? const Center(child: Text("No events found"))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: state.displayedEvents.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final event = state.displayedEvents[index];
                                // Parse date exactly as before
                                final date = DateTime.parse(event['start_datetime']);
                                
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => EventDetailScreen(event: event))),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black12, blurRadius: 4)
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(16)),
                                          child: Image.network(
                                            event['image_url'] ??
                                                'https://via.placeholder.com/300',
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            // ADD THIS PROTECTOR:
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    height: 180,
                                                    color: Colors.grey[200],
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.event_busy,
                                                        color: Colors.grey,
                                                        size: 40,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Tags Row
                                              Row(
                                                children: (event['tags'] as List)
                                                    .take(3)
                                                    .map<Widget>((t) => Padding(
                                                          padding: const EdgeInsets.only(right: 8),
                                                          child: Text(
                                                              "#$t",
                                                              style: TextStyle(
                                                                  color: Colors.purple[700],
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.bold)),
                                                        ))
                                                    .toList(),
                                              ),
                                              const SizedBox(height: 8),
                                              // Title
                                              Text(event['title'],
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              // Date
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_today,
                                                      size: 16, color: Colors.grey[600]),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                      DateFormat('dd MMM, hh:mm a').format(date),
                                                      style: TextStyle(color: Colors.grey[600])),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Location
                                              Row(
                                                children: [
                                                  Icon(Icons.location_on,
                                                      size: 16, color: Colors.grey[600]),
                                                  const SizedBox(width: 8),
                                                  Text(event['location'] ?? 'TBA',
                                                      style: TextStyle(color: Colors.grey[600])),
                                                ],
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CreateEventScreen())),
            backgroundColor: Colors.purple,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}