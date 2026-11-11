import 'package:flutter/material.dart';

import 'facility_issues_screen.dart';
import 'home_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'shop_items_screen.dart';

/// Root shell shown after sign-in.
///
/// Hosts the five main tabs in a [BottomNavigationBar]:
/// Home, Facility Issues, Honour Shop, Notifications and Profile.
///
/// An [IndexedStack] keeps every tab alive, so scroll position and any
/// in-flight state are preserved while switching between tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Default to the Home tab (first position in the bar) so users land on
  // Home immediately after sign-in.
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    FacilityIssuesScreen(),
    ShopItemsScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  static const List<BottomNavigationBarItem> _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.construction),
      activeIcon: Icon(Icons.construction),
      label: 'Facility',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.storefront_outlined),
      activeIcon: Icon(Icons.storefront),
      label: 'Honour Shop',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications_none),
      activeIcon: Icon(Icons.notifications),
      label: 'Notifications',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No Scaffold-level AppBar here: each tab manages its own AppBar or
      // custom header so we never render a double bar.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: _items,
      ),
    );
  }
}