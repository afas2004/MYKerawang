import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. The State
class ProfileState {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> listings; // Items you sell
  final List<Map<String, dynamic>> events;   // Events you organized
  final bool isLoading;
  final String? errorMessage;

  ProfileState({
    this.profile,
    this.listings = const [],
    this.events = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  ProfileState copyWith({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? listings,
    List<Map<String, dynamic>>? events,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      listings: listings ?? this.listings,
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// 2. The Cubit
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileState()) {
    loadProfile();
  }

  final _supabase = Supabase.instance.client;

  Future<void> loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      if (state.profile == null) {
        emit(state.copyWith(isLoading: true));
      }

      // 1. Fetch Profile
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      // 2. Fetch Listings
      final listingsData = await _supabase
          .from('listings')
          .select()
          .eq('seller_id', user.id);

      // 3. Fetch Events (Check if your column is 'organizer_id' or 'created_by')
      final eventsData = await _supabase
          .from('events')
          .select()
          .eq('organizer_id', user.id); 

      emit(state.copyWith(
          isLoading: false, // Done!
          profile: profileData,
          listings: listingsData,
          events: eventsData,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
      }
  }

  // ... (Keep updateProfile and uploadAvatar functions EXACTLY as they were before) ...
  Future<void> updateProfile({required String fullName, required String phone, required String bio}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      emit(state.copyWith(isLoading: true));
      await _supabase.from('profiles').update({'full_name': fullName, 'phone_number': phone, 'bio': bio}).eq('id', user.id);
      await loadProfile();
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      emit(state.copyWith(isLoading: true));
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _supabase.storage.from('avatars').upload(fileName, imageFile, fileOptions: const FileOptions(upsert: true));
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      await _supabase.from('profiles').update({'avatar_url': imageUrl}).eq('id', user.id);
      await loadProfile();
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: "Upload failed: $e"));
    }
  }
}