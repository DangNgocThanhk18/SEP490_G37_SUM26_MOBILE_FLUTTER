import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/app_notification.dart';
import '../models/chapter.dart';
import '../models/comic.dart';
import '../models/notification_destination.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/app_preferences.dart';
import '../services/push_notifications.dart';
import '../theme/app_theme.dart';
import '../widgets/in_app_notification.dart';
import 'comic_detail_screen.dart';
import 'explore_screen.dart';
import 'forum_screen.dart';
import 'forum_thread_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'notifications_screen.dart';
import 'premium_screen.dart';
import 'profile_screen.dart';
import 'reader_screen.dart';

enum _ShellSection { home, explore, forum, library, notifications, profile }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.apiClient,
    required this.user,
    required this.onSignOut,
    required this.onToggleTheme,
    required this.isDarkMode,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.locale = const Locale('en'),
    this.onLocaleChanged,
    this.onUserChanged,
    this.preferences,
    this.pushNotifications,
    this.screenCaptureProtectionEnabled = true,
    this.onScreenCaptureProtectionChanged,
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final VoidCallback onSignOut;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final Locale locale;
  final ValueChanged<Locale>? onLocaleChanged;
  final ValueChanged<UserProfile>? onUserChanged;
  final AppPreferences? preferences;
  final PushNotificationCoordinator? pushNotifications;
  final bool screenCaptureProtectionEnabled;
  final ValueChanged<bool>? onScreenCaptureProtectionChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  _ShellSection _section = _ShellSection.home;
  final Set<_ShellSection> _visitedTabs = {_ShellSection.home};
  int _unreadCount = 0;
  int _notificationRefreshSignal = 0;
  Timer? _notificationTimer;
  StreamSubscription<AppNotification>? _foregroundPushSubscription;
  StreamSubscription<AppNotification>? _openedPushSubscription;

  String? get _readerViewerIdentifier {
    final email = widget.user?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    final username = widget.user?.username.trim();
    return username == null || username.isEmpty ? null : username;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _startNotificationPolling();
    _foregroundPushSubscription = widget
        .pushNotifications
        ?.foregroundNotifications
        .listen(_handleForegroundPush);
    _openedPushSubscription = widget.pushNotifications?.openedNotifications
        .listen(_handleOpenedPush);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = widget.pushNotifications?.takePendingOpenedNotification();
      if (pending != null) unawaited(_handleOpenedPush(pending));
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    unawaited(_foregroundPushSubscription?.cancel());
    unawaited(_openedPushSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startNotificationPolling();
      _refreshNotifications(
        refreshList: _section == _ShellSection.notifications,
      );
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _notificationTimer?.cancel();
      _notificationTimer = null;
    }
  }

  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    if (!widget.apiClient.hasToken) return;
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUnreadCount(),
    );
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

  void _goTo(_ShellSection section) {
    setState(() {
      _section = section;
      _visitedTabs.add(section);
      if (section == _ShellSection.notifications) {
        _notificationRefreshSignal++;
      }
    });
    if (section == _ShellSection.notifications) _loadUnreadCount();
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

  Future<void> _handleForegroundPush(AppNotification notification) async {
    if (!mounted || !widget.apiClient.hasToken) return;
    await _refreshNotifications(
      refreshList: _section == _ShellSection.notifications,
    );
    if (!mounted) return;
    InAppNotifications.show(
      context,
      type: InAppNotificationType.information,
      title: notification.title,
      message: notification.message,
      duration: const Duration(seconds: 5),
      action: notification.actionUrl == null
          ? null
          : InAppNotificationAction(
              label: context.tr('Open'),
              onPressed: () => _handleOpenedPush(notification),
            ),
    );
  }

  Future<void> _handleOpenedPush(AppNotification notification) async {
    if (!mounted || !widget.apiClient.hasToken) return;
    var opened = notification;
    if (_isUuid(notification.id)) {
      try {
        await widget.apiClient.markNotificationRead(notification.id);
        opened = notification.copyWith(isRead: true);
      } catch (_) {
        // The action is still useful if the read receipt races a revoked or
        // already-deleted notification.
      }
    }
    await _refreshNotifications(
      refreshList: _section == _ShellSection.notifications,
    );
    if (mounted) await _openNotification(opened);
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  Future<void> _openNotification(AppNotification notification) async {
    final destination = NotificationDestination.parse(notification.actionUrl);
    switch (destination.type) {
      case NotificationDestinationType.none:
        return;
      case NotificationDestinationType.home:
        _goTo(_ShellSection.home);
        return;
      case NotificationDestinationType.explore:
        _goTo(_ShellSection.explore);
        return;
      case NotificationDestinationType.library:
        _goTo(_ShellSection.library);
        return;
      case NotificationDestinationType.profile:
        _goTo(_ShellSection.profile);
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
      case NotificationDestinationType.legacyChapter:
        await _openLegacyChapter(destination.chapterId!);
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
        _showMessage(
          context.tr('This notification is available in the web workspace.'),
          type: InAppNotificationType.information,
        );
        return;
    }
  }

  Future<void> _openComic(String comicId) async {
    try {
      final comic = await _withLoading(
        widget.apiClient.getComicDetail(comicId),
      );
      if (!mounted) return;
      await _push(
        ComicDetailScreen(
          apiClient: widget.apiClient,
          comic: comic,
          preferences: widget.preferences,
          viewerIdentifier: _readerViewerIdentifier,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.localizedError(error));
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
      if (!mounted) return;
      final comic = values[0] as Comic;
      final chapters = values[1] as List<ChapterLite>;
      final index = chapters.indexWhere((chapter) => chapter.id == chapterId);
      if (index < 0) {
        throw ApiException(context.tr('This chapter is no longer available.'));
      }
      await _push(
        ReaderScreen(
          apiClient: widget.apiClient,
          chapters: chapters,
          initialIndex: index,
          comicTitle: comic.title,
          viewerIdentifier: _readerViewerIdentifier,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.localizedError(error));
    }
  }

  Future<void> _openLegacyChapter(String chapterId) async {
    try {
      final chapter = await _withLoading(
        widget.apiClient.getChapterDetail(chapterId),
      );
      if (!mounted) return;
      final comicId = chapter.comicId;
      if (comicId == null || comicId.isEmpty) {
        throw ApiException(
          context.tr('This notification is available in the web workspace.'),
        );
      }
      await _openChapter(comicId, chapterId);
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.localizedError(error));
    }
  }

  Future<T> _withLoading<T>(Future<T> operation) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final loadingRoute = InAppModal.showLoading(
      context,
      message: context.tr('Loading…'),
    );
    try {
      return await operation;
    } finally {
      if (navigator.mounted) navigator.pop();
      await loadingRoute;
    }
  }

  Future<void> _push(Widget screen) async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _showMessage(
    String message, {
    InAppNotificationType type = InAppNotificationType.error,
  }) {
    if (!mounted) return;
    InAppNotifications.show(
      context,
      type: type,
      title: context.tr(switch (type) {
        InAppNotificationType.success => 'Success',
        InAppNotificationType.error => 'Error',
        InAppNotificationType.warning => 'Warning',
        InAppNotificationType.information => 'Information',
      }),
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        apiClient: widget.apiClient,
        onOpenExplore: () => _goTo(_ShellSection.explore),
        onOpenNotifications: () => _goTo(_ShellSection.notifications),
        unreadCount: _unreadCount,
      ),
      if (_visitedTabs.contains(_ShellSection.explore))
        ExploreScreen(apiClient: widget.apiClient)
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(_ShellSection.forum))
        ForumScreen(apiClient: widget.apiClient, onSignIn: widget.onSignOut)
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(_ShellSection.library))
        LibraryScreen(
          apiClient: widget.apiClient,
          isGuest: !widget.apiClient.hasToken,
          onSignIn: widget.onSignOut,
          onExplore: () => _goTo(_ShellSection.explore),
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(_ShellSection.notifications))
        NotificationsScreen(
          apiClient: widget.apiClient,
          isGuest: !widget.apiClient.hasToken,
          onSignIn: widget.onSignOut,
          onUnreadChanged: _setUnreadCount,
          onOpenNotification: _openNotification,
          refreshSignal: _notificationRefreshSignal,
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(_ShellSection.profile))
        ProfileScreen(
          apiClient: widget.apiClient,
          user: widget.user,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          onOpenHistory: () => _goTo(_ShellSection.library),
          onSignOut: widget.onSignOut,
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onUserChanged: widget.onUserChanged,
          screenCaptureProtectionEnabled: widget.screenCaptureProtectionEnabled,
          onScreenCaptureProtectionChanged:
              widget.onScreenCaptureProtectionChanged,
        )
      else
        const SizedBox.shrink(),
    ];

    return PopScope(
      canPop: _section == _ShellSection.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _section != _ShellSection.home) {
          _goTo(_ShellSection.home);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _section.index, children: pages),
        floatingActionButtonLocation: const _IntegratedHomeFabLocation(),
        floatingActionButton: _HomeNavigationButton(
          key: const Key('main-nav-home'),
          label: context.tr('Home'),
          selected:
              _section == _ShellSection.home ||
              _section == _ShellSection.notifications,
          onPressed: () => _goTo(_ShellSection.home),
        ),
        bottomNavigationBar: _ComiVerseBottomBar(
          selectedSection: _section,
          onSelected: _goTo,
        ),
      ),
    );
  }
}

class _ComiVerseBottomBar extends StatelessWidget {
  const _ComiVerseBottomBar({
    required this.selectedSection,
    required this.onSelected,
  });

  final _ShellSection selectedSection;
  final ValueChanged<_ShellSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BottomAppBar(
      height: 68,
      padding: EdgeInsets.zero,
      color: theme.navigationBarTheme.backgroundColor ?? scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      elevation: 12,
      shape: const CircularNotchedRectangle(),
      notchMargin: 4,
      child: Row(
        children: [
          _BottomNavigationItem(
            key: const Key('main-nav-explore'),
            sortOrder: 1,
            label: context.tr('Explore'),
            icon: Icons.explore_outlined,
            selectedIcon: Icons.explore_rounded,
            selected: selectedSection == _ShellSection.explore,
            onPressed: () => onSelected(_ShellSection.explore),
          ),
          _BottomNavigationItem(
            key: const Key('main-nav-forum'),
            sortOrder: 2,
            label: context.tr('Forum'),
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum_rounded,
            selected: selectedSection == _ShellSection.forum,
            onPressed: () => onSelected(_ShellSection.forum),
          ),
          const SizedBox(width: 66),
          _BottomNavigationItem(
            key: const Key('main-nav-library'),
            sortOrder: 4,
            label: context.tr('Library'),
            icon: Icons.library_books_outlined,
            selectedIcon: Icons.library_books_rounded,
            selected: selectedSection == _ShellSection.library,
            onPressed: () => onSelected(_ShellSection.library),
          ),
          _BottomNavigationItem(
            key: const Key('main-nav-profile'),
            sortOrder: 5,
            label: context.tr('Profile'),
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            selected: selectedSection == _ShellSection.profile,
            onPressed: () => onSelected(_ShellSection.profile),
          ),
        ],
      ),
    );
  }
}

class _IntegratedHomeFabLocation extends FloatingActionButtonLocation {
  const _IntegratedHomeFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final docked = FloatingActionButtonLocation.centerDocked.getOffset(
      scaffoldGeometry,
    );
    // Keep the colored Home action only slightly raised so it still reads as
    // part of the navigation bar instead of a separate floating action.
    return docked + const Offset(0, 4);
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    super.key,
    required this.sortOrder,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onPressed,
  });

  final double sortOrder;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = selected ? {WidgetState.selected} : <WidgetState>{};
    final labelStyle =
        theme.navigationBarTheme.labelTextStyle?.resolve(states) ??
        TextStyle(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        );
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        sortKey: OrdinalSortKey(sortOrder),
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 38,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer.withValues(alpha: 0.55)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        selected ? selectedIcon : icon,
                        color: color,
                        size: 23,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeNavigationButton extends StatelessWidget {
  const _HomeNavigationButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      sortKey: OrdinalSortKey(3),
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: AnimatedScale(
          scale: selected ? 1.02 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox.square(
            dimension: 58,
            child: Material(
              color: Colors.transparent,
              elevation: selected ? 6 : 4,
              shadowColor: context.cvColors.brandPink.withValues(alpha: 0.32),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.brandPurple, context.cvColors.brandPink],
                  ),
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? Icons.home_rounded : Icons.home_outlined,
                          color: scheme.onPrimary,
                          size: 25,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 8.5,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
