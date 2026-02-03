import 'package:flutter/material.dart';
import 'package:mykerawang/screens/main_scaffold.dart';
import 'package:mykerawang/screens/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'theme_cubit.dart';
// --- IMPORT YOUR SERVICES ---
import 'services/notification_service.dart';
import 'database_helper.dart';

// --- IMPORT YOUR SCREENS ---
import 'screens/home_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart'; 
import 'screens/login_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/events_cubit.dart';
import 'screens/marketplace_cubit.dart';
import 'screens/profile_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  await Supabase.initialize(
    url: 'https://zxjuqpqzyzmegdjttzyz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4anVxcHF6eXptZWdkanR0enl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MzAxNzIsImV4cCI6MjA4MDAwNjE3Mn0.UD_aL16G55CFD6TAOutU4oiGsJCaU5wq-wqFf6OnW5c',
  );

  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Initialize ALL Cubits here (Global State)
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => EventsCubit()),
        BlocProvider(create: (context) => MarketplaceCubit()),
        BlocProvider(create: (context) => ProfileCubit()),
        BlocProvider(create: (context) => ThemeCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'MYKerawang',
            
            // 3. DEFINE LIGHT THEME
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeState.seedColor, // Your Purple
                brightness: Brightness.light,
              ),
              // Fix Navbar Background automatically
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: ColorScheme.fromSeed(seedColor: themeState.seedColor, brightness: Brightness.light).surfaceContainer,
              ),
            ),

            // 4. DEFINE DARK THEME (Flutter does the magic automatically)
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeState.seedColor, // Same Purple
                brightness: Brightness.dark, // <--- This flips all colors
              ),
              // Fix Navbar Background automatically
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: ColorScheme.fromSeed(seedColor: themeState.seedColor, brightness: Brightness.light).surfaceContainer,
              ),
            ),

            // 5. CONNECT THE MODE
            themeMode: themeState.themeMode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

// --- UPDATED AUTH GATE ---
// This widget watches for Login/Logout AND listens for new Notifications
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    _setupNotificationListener(); // Keep your existing notification logic!
  }

  // 1. CHECK IF USER EXISTS IN DB
  Future<void> _checkUserStatus() async {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      // Not logged in
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Check if they have a username in 'profiles'
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', session.user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _hasProfile = (data != null && data['username'] != null);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("AuthGate Error: $e");
      // FAIL OPEN: If database fails (offline), assume they HAVE a profile 
      // so they can at least see the Home Screen (cached) instead of getting stuck.
      if (mounted) {
        setState(() {
          _hasProfile = true; // <--- CHANGED from false to true
          _isLoading = false;
        });
      }
    }
  }

  // THE MAGIC LISTENER (Timezone Fixed)
  void _setupNotificationListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      // When User Logs In...
      if (event == AuthChangeEvent.signedIn && session != null) {
        
        // 1. Ask for Android Permission immediately
        NotificationService.requestPermission();
        debugPrint("🔔 Notification Listener STARTED for ${session.user.email}");

        // 2. Watch the 'notifications' table for new rows
        Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', session.user.id)
            .listen((List<Map<String, dynamic>> data) {
              
              if (data.isNotEmpty) {
                // Get the newest notification
                final latest = data.last; 
                
                // --- TIMEZONE FIX ---
                // Convert everything to UTC to ensure correct comparison
                final created = DateTime.parse(latest['created_at']).toUtc(); 
                final now = DateTime.now().toUtc(); 
                
                final difference = now.difference(created).inSeconds.abs();

                debugPrint("🔔 New Data! Title: ${latest['title']}");
                debugPrint("   Created (UTC): $created");
                debugPrint("   Now (UTC):     $now");
                debugPrint("   Difference:    $difference seconds");

                // Check if it is recent (less than 30 seconds to be safe)
                if (difference < 30) {
                   debugPrint("✅ TRIGGERING POPUP NOW!");
                   NotificationService.showNotification(
                     latest['title'], 
                     latest['message']
                   );
                } else {
                   debugPrint("❌ Too old, skipping popup.");
                }
              }
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // 1. Loading State
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. Not Logged In -> Login Screen
    if (session == null) {
      return const LoginScreen();
    }

    // 3. Logged In BUT No Profile -> Onboarding
    if (!_hasProfile) {
      // Import your onboarding screen at the top of main.dart:
      // import 'screens/onboarding_screen.dart';
      return const OnboardingScreen(); 
    }

    // 4. Fully Ready -> Main App
    return const MainScaffold();
  }
  
}
