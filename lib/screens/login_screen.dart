import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mykerawang/screens/main_scaffold.dart';
import '../main.dart'; // This goes up one level to find main.dart
import 'login_cubit.dart'; // This looks in the SAME folder

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Inject the Cubit
    return BlocProvider(
      create: (context) => LoginCubit(),
      child: Scaffold(
        backgroundColor: Colors.white,
        // 2. Listen to State Changes (Logic)
        body: BlocConsumer<LoginCubit, LoginState>(
          listener: (context, state) {
            // Handle Errors
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            }

            // Handle Navigation on Success
            if (state.isSuccess) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate()), // <--- Point to AuthGate
                (route) => false,
              );
            }
          },
          builder: (context, state) {
            // 3. Build UI based on State
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- ORIGINAL UI ELEMENTS START ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B3E96).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, size: 60, color: Color(0xFF5B3E96)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      state.isLoginMode ? "Welcome Back" : "Join MYKerawang",
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.isLoginMode ? "Login to continue" : "Create an account to get started",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        // Call Cubit Function instead of local _submit
                        onPressed: state.isLoading
                            ? null
                            : () {
                                context.read<LoginCubit>().submit(
                                      _emailCtrl.text,
                                      _passCtrl.text,
                                    );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B3E96),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: state.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                state.isLoginMode ? "Login" : "Sign Up",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // GOOGLE BUTTON
                    OutlinedButton.icon(
                      onPressed: state.isLoading 
                          ? null 
                          : () => context.read<LoginCubit>().signInWithGoogle(),
                      icon: const Icon(Icons.g_mobiledata, size: 28), // Or use a Google Logo asset
                      label: const Text("Continue with Google"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    TextButton(
                      // Call Cubit to toggle mode
                      onPressed: () => context.read<LoginCubit>().toggleLoginMode(),
                      child: RichText(
                        text: TextSpan(
                          text: state.isLoginMode ? "New user? " : "Have an account? ",
                          style: const TextStyle(color: Colors.grey),
                          children: [
                            TextSpan(
                              text: state.isLoginMode ? "Create account" : "Login",
                              style: const TextStyle(
                                color: Color(0xFF5B3E96),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                    // --- ORIGINAL UI ELEMENTS END ---
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}