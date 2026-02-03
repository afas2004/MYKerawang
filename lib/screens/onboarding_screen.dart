import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mykerawang/screens/main_scaffold.dart'; // Ensure this points to your MainScaffold

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  // FIX: Page Controller to handle sliding
  final PageController _pageController = PageController();

  // Controllers
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(); // <--- NEW: Phone
  final _clubReasonCtrl = TextEditingController(); // <--- NEW: For Club verification
  
  // State
  int _step = 0; // 0 = Identity, 1 = Contact & Role
  bool _isLoading = false;
  bool _isClub = false; 

  // Username Logic
  String? _usernameError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile(); // <--- NEW: Check for existing data
  }

  Future<void> _loadExistingProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    // Fetch what we already know about the user
    final data = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    
    if (data != null && mounted) {
      setState(() {
        // Pre-fill fields so they don't have to type it again
        _nameCtrl.text = data['display_name'] ?? ''; 
        _phoneCtrl.text = data['phone_number'] ?? '';
        
        // If they managed to set a username before but got stuck, load it too
        if (data['username'] != null) {
          _usernameCtrl.text = data['username'];
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _clubReasonCtrl.dispose();
    super.dispose();
  }

  // --- VALIDATION LOGIC ---
  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (value.length < 3) return;
      
      final res = await _supabase.from('profiles').select('id').eq('username', value).maybeSingle();
      if (mounted) {
        setState(() {
          _usernameError = res != null ? "Username already taken" : null;
        });
      }
    });
  }

  Future<void> _finishOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameError != null) return;
    
    // Club Verification Check
    if (_isClub && _clubReasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide club details/ID for verification.")));
      return;
    }

    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;

    try {
      // Update Profile with CRITICAL INFO
      await _supabase.from('profiles').upsert({
        'id': user!.id,
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'display_name': _nameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(), // <--- SAVING PHONE
        'role': _isClub ? 'club_pending' : 'student',
        // We save the club justification in 'bio' or a separate column for admin review
        'bio': _isClub ? "Club Verification: ${_clubReasonCtrl.text}" : null,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Go to Home and remove history
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScaffold()), 
          (route) => false
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    // Validate Step 1 before moving
    if (_step == 0) {
      if (_usernameCtrl.text.isEmpty || _nameCtrl.text.isEmpty || _usernameError != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fix errors first.")));
        return;
      }
    }

    setState(() => _step++);
    _pageController.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _prevPage() {
    setState(() => _step--);
    _pageController.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text("Welcome!"), automaticallyImplyLeading: false),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // PROGRESS BAR
            LinearProgressIndicator(
              value: _step == 0 ? 0.5 : 1.0, 
              backgroundColor: theme.colorScheme.surfaceContainer,
            ),
            
            Expanded(
              child: PageView(
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                controller: _pageController, // FIX: Controller attached
                children: [
                  // --- STEP 1: IDENTITY ---
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Let's get you set up.", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text("Create a unique ID so friends can find you."),
                          const SizedBox(height: 32),
                          
                          // Username
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: InputDecoration(
                              labelText: "Username",
                              prefixText: "@",
                              errorText: _usernameError,
                              border: const OutlineInputBorder(),
                              helperText: "Unique ID (e.g. fahmi_99)",
                            ),
                            onChanged: _onUsernameChanged,
                            validator: (v) => (v!.length < 3) ? "Too short" : null,
                          ),
                          const SizedBox(height: 24),
                          
                          // Display Name
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: "Display Name",
                              border: OutlineInputBorder(),
                              helperText: "Your real name or club name",
                            ),
                            validator: (v) => v!.isEmpty ? "Required" : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- STEP 2: CONTACT & ROLE ---
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Contact Details", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text("How should people contact you regarding events or items?"),
                          const SizedBox(height: 24),
                          
                          // PHONE NUMBER (Crucial)
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: "WhatsApp Number",
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                              helperText: "Required for Marketplace & Events",
                            ),
                            validator: (v) => v!.isEmpty ? "Phone number is required" : null,
                          ),
                          
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),

                          // CLUB TOGGLE
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: _isClub ? theme.primaryColor : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: _isClub ? theme.primaryColor.withOpacity(0.05) : null,
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text("I am registering a Club"),
                                  subtitle: const Text("Switch to Club Account (Requires Approval)"),
                                  value: _isClub,
                                  onChanged: (val) => setState(() => _isClub = val),
                                  secondary: const Icon(Icons.groups),
                                ),
                                
                                // Verification Field (Only if Club is ON)
                                if (_isClub) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _clubReasonCtrl,
                                    decoration: const InputDecoration(
                                      labelText: "Club ID / Reference",
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(),
                                      helperText: "Provide ID for admin verification",
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // BOTTOM BUTTONS
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(onPressed: _prevPage, child: const Text("Back")),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isLoading ? null : () {
                      if (_step == 0) {
                        _nextPage();
                      } else {
                        _finishOnboarding();
                      }
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size(120, 50)),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : Text(_step == 0 ? "Next" : "Finish"),
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