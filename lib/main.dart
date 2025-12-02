import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://zxjuqpqzyzmegdjttzyz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4anVxcHF6eXptZWdkanR0enl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MzAxNzIsImV4cCI6MjA4MDAwNjE3Mn0.UD_aL16G55CFD6TAOutU4oiGsJCaU5wq-wqFf6OnW5c',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MYKerawang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // background-light
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4d1d5a), // Primary Purple
          primary: const Color(0xFF4d1d5a),
          secondary: const Color(0xFFec7f13), // Marketplace Orange
          tertiary: const Color(0xFFE02097), // Events Magenta
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            fontFamily: 'Plus Jakarta Sans'
          ),
          iconTheme: IconThemeData(color: Color(0xFF333333)),
        ),
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  
  // Mapping the HTML Bottom Nav
  final List<Widget> _pages = [
    const HomeScreen(),       // From home.html
    const MarketplaceScreen(), // From home.html grid & item_detail.html
    const EventsScreen(),      // From .event_list.html
    const ProfileScreen(),     // From profile.html
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 10,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Market'),
          NavigationDestination(icon: Icon(Icons.celebration_outlined), selectedIcon: Icon(Icons.celebration), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}