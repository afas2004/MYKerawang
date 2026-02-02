import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart'; // Import your DB Helper

class EventsState {
  final List<Map<String, dynamic>> allEvents;
  final List<Map<String, dynamic>> displayedEvents;
  final String selectedTag;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  EventsState({
    this.allEvents = const [],
    this.displayedEvents = const [],
    this.selectedTag = 'All',
    this.searchQuery = '',
    this.isLoading = true,
    this.errorMessage,
  });

  EventsState copyWith({
    List<Map<String, dynamic>>? allEvents,
    List<Map<String, dynamic>>? displayedEvents,
    String? selectedTag,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EventsState(
      allEvents: allEvents ?? this.allEvents,
      displayedEvents: displayedEvents ?? this.displayedEvents,
      selectedTag: selectedTag ?? this.selectedTag,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EventsCubit extends Cubit<EventsState> {
  EventsCubit() : super(EventsState()) {
    loadData();
  }

  StreamSubscription? _subscription;
  final _supabase = Supabase.instance.client;

  Future<void> loadData() async {
   
    emit(state.copyWith(isLoading: true));

    final cachedData = await DatabaseHelper.instance.getCachedEvents();
    final nowStr = DateTime.now().toUtc().toIso8601String();
    
    if (cachedData.isNotEmpty) {
      final filtered = _applyFilters(cachedData, state.selectedTag, state.searchQuery);
      emit(state.copyWith(
        allEvents: cachedData,
        displayedEvents: filtered,
        isLoading: false, // UI appears instantly
      ));
    }

    // 3. SLOW: Subscribe to Supabase (Background Download)
    _subscription = _supabase
        .from('events')
        .stream(primaryKey: ['id'])
        .gte('end_datetime', nowStr) // Only show future events
        .order('created_at', ascending: false)
        .listen((data) async {
          final items = List<Map<String, dynamic>>.from(data);
          
          // 4. Update SQLite so next time is fast too
          await DatabaseHelper.instance.cacheEvents(items);

          // 5. Update UI with fresh data
          final filtered = _applyFilters(items, state.selectedTag, state.searchQuery);
          
          if (!isClosed) {
            emit(state.copyWith(
              allEvents: items,
              displayedEvents: filtered,
              isLoading: false,
            ));
          }
        }, onError: (error) {
          if (!isClosed) emit(state.copyWith(errorMessage: error.toString()));
        });
  }

  void updateTag(String tag) {
    final filtered = _applyFilters(state.allEvents, tag, state.searchQuery);
    emit(state.copyWith(selectedTag: tag, displayedEvents: filtered));
  }

  void updateSearch(String query) {
    final filtered = _applyFilters(state.allEvents, state.selectedTag, query);
    emit(state.copyWith(searchQuery: query, displayedEvents: filtered));
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> items, String tag, String query) {
    return items.where((e) {
      final title = (e['title'] as String).toLowerCase();
      final search = query.toLowerCase();
      final eventTags = List<String>.from(e['tags'] ?? []);
      
      final matchesSearch = title.contains(search);
      final matchesTag = tag == 'All' || eventTags.contains(tag);
      
      return matchesSearch && matchesTag;
    }).toList();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}