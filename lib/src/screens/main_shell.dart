import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/notification_destination.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import 'comic_detail_screen.dart';
import 'explore_screen.dart';
import 'forum_thread_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'notifications_screen.dart';
import 'premium_screen.dart';
import 'profile_screen.dart';
import 'reader_screen.dart';

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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  int _unreadCount = 0;
  int _notificationRefreshSignal = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    if (widget.apiClient.hasToken) {
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _loadUnreadCount(),
      );
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotifications(refreshList: _index == 3);
    }
  }

  Future<void> _loadUnreadCount() async {
    if (!widget.apiClient.hasToken) {
      if (mounted && _unreadCount != 0) {
        setState(() => _unreadCount = 0);
      }
      return;
    }
    try {
      final count = await widget.apiClient.getUnreadNotificationCount();
      if (mounted && count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {
      // The destination remains usable and exposes its own retry state.
    }
  }

  void _goTo(int index) {
    setState(() {
      _index = index;
      if (index == 3) _notificationRefreshSignal++;
    });
    if (index == 3) _loadUnreadCount();
  }

  Future<void> _refreshNotifications({required bool refreshList}) async {
    if (refreshList && mounted) {
      setState(() => _notificationRefreshSignal++);
    }
    await _loadUnreadCount();
  }

  void _setUnreadCount(int count) {
    if (mounted && count != _unreadCount) {
      setState(() => _unreadCount = count);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    final destination = NotificationDestination.parse(notification.actionUrl);
    switch (destination.type) {
      case NotificationDestinationType.none:
        return;
      case NotificationDestinationType.home:
        _goTo(0);
        return;
      case NotificationDestinationType.explore:
        _goTo(1);
        return;
      case NotificationDestinationType.library:
        _goTo(2);
        return;
      case NotificationDestinationType.profile:
        _goTo(4);
        return;
      case NotificationDestinationType.premium:
        final user = widget.user;
        if (user == null) return;
        await _push(PremiumScreen(apiClient: widget.apiClient, user: user));
        return;
      case NotificationDestinationType.comic:
        await _openComic(destination.comicId!);
        return;
      case NotificationDestinationType.chapter:
        await _openChapter(destination.comicId!, destination.chapterId!);
        return;
      case NotificationDestinationType.forumThread:
        await _push(
          ForumThreadScreen(
            apiClient: widget.apiClient,
            threadId: destination.threadId!,
            highlightCommentId: destination.commentId,
          ),
        );
        return;
      case NotificationDestinationType.unsupported:
        _showMessage('This notification is available in the web workspace.');
        return;
    }
  }

  Future<void> _openComic(String comicId) async {
    try {
      final comic = await _withLoading(
        widget.apiClient.getComicDetail(comicId),
      );
      if (!mounted) return;
      await _push(ComicDetailScreen(apiClient: widget.apiClient, comic: comic));
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _openChapter(String comicId, String chapterId) async {
    try {
      final values = await _withLoading(
        Future.wait([
          widget.apiClient.getComicDetail(comicId),
          widget.apiClient.getChapters(comicId),
        ]),
      );
      final comic = values[0] as Comic;
      final chapters = values[1] as List<ChapterLite>;
      final index = chapters.indexWhere((chapter) => chapter.id == chapterId);
      if (index < 0) {
        throw const ApiException('This chapter is no longer available.');
      }
      if (!mounted) return;
      await _push(
        ReaderScreen(
          apiClient: widget.apiClient,
          chapters: chapters,
          initialIndex: index,
          comicTitle: comic.title,
        ),
      );
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<T> _withLoading<T>(Future<T> operation) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      return await operation;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _push(Widget screen) async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        onUnreadChanged: _setUnreadCount,
        onOpenNotification: _openNotification,
        refreshSignal: _notificationRefreshSignal,
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
