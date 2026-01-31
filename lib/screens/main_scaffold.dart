import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'marketplace_screen.dart';
import 'create_listing_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // This function allows children (like Home) to switch tabs
  void _switchTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> get _pages => [
    HomeScreen(onTabChange: _switchTab),
    const SearchScreen(), // Search Tab
    const MarketplaceScreen(), // The full list
    const EventsScreen(), // Events Tab
    const ProfileScreen(), // Profile Tab
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          // Adapts background color based on current theme brightness
          color: Theme.of(context).colorScheme.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),

          // THE CRITICAL PART:
          // This ensures the "pill" highlight matches your custom seed color
          // secondaryContainer is the standard Material 3 token for selected indicators
          indicatorColor: Theme.of(context).colorScheme.secondaryContainer,

          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.home_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.home,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: 'Home',
            ),
            // 2. NEW SEARCH TAB
            NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.search, weight: 700), // Thicker icon when selected
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.storefront,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.store,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: 'Market',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.calendar_today_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.calendar_month,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: 'Events',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              selectedIcon: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}