import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. The State
class ProfileState {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> listings;
  final bool isLoading;
  final String? errorMessage;

  ProfileState({
    this.profile,
    this.listings = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  ProfileState copyWith({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? listings,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      listings: listings ?? this.listings,
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

      emit(state.copyWith(isLoading: true));

      final profileData = await _supabase.from('profiles').select().eq('id', user.id).single();
      final listingsData = await _supabase.from('listings').select().eq('seller_id', user.id);

      emit(state.copyWith(
        isLoading: false,
        profile: profileData,
        listings: List<Map<String, dynamic>>.from(listingsData),
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String bio,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      emit(state.copyWith(isLoading: true));
      await _supabase.from('profiles').update({
        'full_name': fullName,
        'phone_number': phone,
        'bio': bio,
      }).eq('id', user.id);
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

      // Upload to Supabase
      await _supabase.storage.from('avatars').upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get URL
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);

      // Update Profile
      await _supabase.from('profiles').update({
        'avatar_url': imageUrl,
      }).eq('id', user.id);

      await loadProfile();
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: "Upload failed: $e"));
    }
  }
}