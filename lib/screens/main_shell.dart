import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
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

  late final NotificationService _notificationService;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(Supabase.instance.client);
    _notificationService.addListener(_onNotificationsChanged);
    _screens = [
      const HomeScreen(),
      const FacilityIssuesScreen(),
      const ShopItemsScreen(),
      NotificationScreen(service: _notificationService),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    _notificationService.dispose();
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notificationService.unreadCount;

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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.construction),
            activeIcon: Icon(Icons.construction),
            label: 'Facility',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Honour Shop',
          ),
          BottomNavigationBarItem(
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_none),
            ),
            activeIcon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}