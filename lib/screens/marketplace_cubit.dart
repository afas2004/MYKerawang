import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database_helper.dart'; // Import DB Helper

class MarketplaceState {
  final List<Map<String, dynamic>> allItems;
  final List<Map<String, dynamic>> displayedItems;
  final String selectedFilter;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  MarketplaceState({
    this.allItems = const [],
    this.displayedItems = const [],
    this.selectedFilter = 'All',
    this.searchQuery = '',
    this.isLoading = true,
    this.errorMessage,
  });

  MarketplaceState copyWith({
    List<Map<String, dynamic>>? allItems,
    List<Map<String, dynamic>>? displayedItems,
    String? selectedFilter,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MarketplaceState(
      allItems: allItems ?? this.allItems,
      displayedItems: displayedItems ?? this.displayedItems,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class MarketplaceCubit extends Cubit<MarketplaceState> {
  MarketplaceCubit() : super(MarketplaceState()) {
    _loadData();
  }

  StreamSubscription? _subscription;
  final _supabase = Supabase.instance.client;

  Future<void> _loadData() async {
    emit(state.copyWith(isLoading: true));

    // 1. FAST: Cache Load
    final cachedData = await DatabaseHelper.instance.getCachedListings();
    
    if (cachedData.isNotEmpty) {
      final filtered = _applyFilters(cachedData, state.selectedFilter, state.searchQuery);
      emit(state.copyWith(
        allItems: cachedData,
        displayedItems: filtered,
        isLoading: false,
      ));
    }

    // 2. SLOW: Network Load
    _subscription = _supabase
        .from('listings')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((data) async {
          final items = List<Map<String, dynamic>>.from(data);
          
          // Update Cache
          await DatabaseHelper.instance.cacheListings(items);

          final filtered = _applyFilters(items, state.selectedFilter, state.searchQuery);

          if (!isClosed) {
            emit(state.copyWith(
              allItems: items,
              displayedItems: filtered,
              isLoading: false,
            ));
          }
        }, onError: (error) {
          if (!isClosed) emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
        });
  }

  void updateFilter(String filter) {
    final filtered = _applyFilters(state.allItems, filter, state.searchQuery);
    emit(state.copyWith(selectedFilter: filter, displayedItems: filtered));
  }

  void updateSearch(String query) {
    final filtered = _applyFilters(state.allItems, state.selectedFilter, query);
    emit(state.copyWith(searchQuery: query, displayedItems: filtered));
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> items, String filter, String query) {
    return items.where((i) {
      final matchesCategory = filter == 'All' || i['category'] == filter;
      final matchesSearch = query.isEmpty ||
          (i['title'] as String).toLowerCase().contains(query.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}