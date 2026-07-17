import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.apiClient,
    required this.user,
    required this.onSignOut,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final VoidCallback onSignOut;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (!widget.apiClient.hasToken) return;
    try {
      final count = await widget.apiClient.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // The destination remains usable and exposes its own retry state.
    }
  }

  void _goTo(int index) {
    setState(() => _index = index);
    if (index == 3) _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        apiClient: widget.apiClient,
        user: widget.user,
        onOpenExplore: () => _goTo(1),
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      ExploreScreen(apiClient: widget.apiClient),
      LibraryScreen(
        apiClient: widget.apiClient,
        isGuest: !widget.apiClient.hasToken,
        onSignIn: widget.onSignOut,
        onExplore: () => _goTo(1),
      ),
      NotificationsScreen(
        apiClient: widget.apiClient,
        isGuest: !widget.apiClient.hasToken,
        onSignIn: widget.onSignOut,
        onUnreadChanged: (count) {
          if (mounted) setState(() => _unreadCount = count);
        },
      ),
      ProfileScreen(
        apiClient: widget.apiClient,
        user: widget.user,
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
        onOpenHistory: () => _goTo(2),
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          const NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
