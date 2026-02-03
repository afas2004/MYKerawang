import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Define the detailed States for your screen
class LoginState {
  final bool isLoginMode;      // Replaces _isLogin
  final bool isLoading;        // Replaces _isLoading
  final String? errorMessage;  // For Snackbars
  final bool isSuccess;        // To trigger Navigation

  LoginState({
    this.isLoginMode = true,
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  // Helper to create a new state based on the old one
  LoginState copyWith({
    bool? isLoginMode,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return LoginState(
      isLoginMode: isLoginMode ?? this.isLoginMode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // If passed as null, it clears the error
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// 2. The Logic Controller (Cubit)
class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(LoginState());

  final supabase = Supabase.instance.client;

  // Replaces: setState(() => _isLogin = !_isLogin)
  void toggleLoginMode() {
    emit(state.copyWith(isLoginMode: !state.isLoginMode));
  }

  // Replaces: Future<void> _submit() async
  Future<void> submit(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      emit(state.copyWith(errorMessage: "Please fill in all fields"));
      return;
    }

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      if (state.isLoginMode) {
        // Log In Logic
        await supabase.auth.signInWithPassword(
          email: email.trim(),
          password: password.trim(),
        );
      } else {
        // Sign Up Logic
        await supabase.auth.signUp(
          email: email.trim(),
          password: password.trim(),
        );
        // Optional: emit a specific message for signup success if needed
      }

      // Check if session exists (Login Successful)
      if (supabase.auth.currentSession != null) {
        emit(state.copyWith(isLoading: false, isSuccess: true));
      } else {
        // Sometimes signup requires email confirmation, so session might be null
        emit(state.copyWith(isLoading: false, errorMessage: "Check your email for confirmation link."));
      }

    } on AuthException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: "An error occurred. Check connection."));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // 1. Trigger Supabase OAuth
      // NOTE: Ensure you have "Google" enabled in Supabase Auth Providers
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'mykerawang://login-callback', // Match this with Supabase URL settings
      );
      
      // Note: OAuth flow continues outside the app usually. 
      // When they return, AuthGate in main.dart will catch the session change.
      // We don't strictly need to emit success here because the app will reload.
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: "Google Sign-In failed: $e"));
    }
  }
}