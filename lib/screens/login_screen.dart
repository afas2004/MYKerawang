import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      } else {
        await supabase.auth.signUp(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account created! Logging in...")));
      }
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScaffold()));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error occurred"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 80, color: Color(0xFF4d1d5a)),
            const SizedBox(height: 24),
            Text(_isLogin ? "Welcome Back" : "Join MYKerawang", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 16),
            TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4d1d5a), foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isLogin ? "Login" : "Sign Up"),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? "New user? Create account" : "Have an account? Login"),
            )
          ],
        ),
      ),
    );
  }
}