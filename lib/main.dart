import 'package:flutter/material.dart';
import 'package:mykerawang/screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

// --- IMPORT YOUR NEW SERVICE ---
import 'services/notification_service.dart';

import 'screens/marketplace_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart'; 
import 'screens/item_detail_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart'; // Import if you have it

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  await Supabase.initialize(
    // REPLACE WITH YOUR URL AND KEY IF THEY ARE DIFFERENT
    url: 'https://zxjuqpqzyzmegdjttzyz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4anVxcHF6eXptZWdkanR0enl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MzAxNzIsImV4cCI6MjA4MDAwNjE3Mn0.UD_aL16G55CFD6TAOutU4oiGsJCaU5wq-wqFf6OnW5c',
  );

  // 2. Initialize the Notification System (NEW)
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MYKerawang',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B3E96)), 
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      // We start at AuthGate to decide where to go
      home: const AuthGate(),
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
  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  // THE MAGIC LISTENER
  void _setupNotificationListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      // When User Logs In...
      if (event == AuthChangeEvent.signedIn && session != null) {
        
        // 1. Ask for Android Permission immediately
        NotificationService.requestPermission();

        // 2. Watch the 'notifications' table for new rows
        Supabase.instance.client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', session.user.id)
            .listen((List<Map<String, dynamic>> data) {
              
              if (data.isNotEmpty) {
                // Get the newest notification
                final latest = data.last; 
                
                // Only show popup if it was created < 10 seconds ago
                // (This prevents 50 popups from appearing when you first open the app)
                final created = DateTime.parse(latest['created_at']);
                final now = DateTime.now();
                
                if (now.difference(created).inSeconds < 10) {
                   NotificationService.showNotification(
                     latest['title'], 
                     latest['message']
                   );
                }
              }
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Standard Session Check
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const LoginScreen() : const MainScaffold();
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  final _pages = [
    const HomeScreen(),
    const MarketplaceScreen(), 
    const EventsScreen(),     
    const ProfileScreen(),    
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.store_mall_directory_rounded), label: 'Market'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ... Rest of your HomeScreen code (copy it back if it got deleted, or ask me to paste it) ...
// Since HomeScreen is usually large, make sure you keep the code you had for it!
// If you need the HomeScreen code again, let me know.