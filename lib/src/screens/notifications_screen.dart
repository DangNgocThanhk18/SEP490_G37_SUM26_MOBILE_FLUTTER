import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiClient,
    required this.isGuest,
    required this.onSignIn,
    required this.onUnreadChanged,
  });

  final ApiClient apiClient;
  final bool isGuest;
  final VoidCallback onSignIn;
  final ValueChanged<int> onUnreadChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<List<AppNotification>> _future;
  String _filter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() async {
    if (widget.isGuest) return const [];
    final items = await widget.apiClient.getNotifications();
    widget.onUnreadChanged(items.where((item) => !item.isRead).length);
    return items;
  }

  void _reload() => setState(() => _future = _load());

  List<AppNotification> _filtered(List<AppNotification> items) {
    if (_filter == 'all') return items;
    return items.where((item) {
      final type = item.type;
      return switch (_filter) {
        'chapter' => type.contains('CHAPTER') || type.contains('LIBRARY'),
        'interaction' =>
          type.contains('COMMENT') ||
              type.contains('REPLY') ||
              type.contains('INTERACTION'),
        'system' =>
          type.contains('SYSTEM') ||
              type.contains('BROADCAST') ||
              type.contains('SECURITY') ||
              type.contains('PREMIUM'),
        _ => true,
      };
    }).toList();
  }

  Future<void> _markAll() async {
    try {
      await widget.apiClient.markAllNotificationsRead();
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _markRead(AppNotification item) async {
    if (item.isRead) return;
    try {
      await widget.apiClient.markNotificationRead(item.id);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: EmptyState(
          icon: Icons.notifications_off_outlined,
          message:
              'Sign in to receive chapter updates and account notifications.',
          actionLabel: 'Sign in',
          onAction: widget.onSignIn,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: _markAll,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final all = snapshot.data ?? const [];
          final items = _filtered(all);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              key: const PageStorageKey('notifications-scroll'),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 64,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final option in const [
                          ('all', 'All'),
                          ('chapter', 'New chapters'),
                          ('interaction', 'Interaction'),
                          ('system', 'System'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(option.$2),
                              selected: _filter == option.$1,
                              onSelected: (_) =>
                                  setState(() => _filter = option.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      message: 'No notifications in this category.',
                    ),
                  )
                else
                  ..._buildGroups(items),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroups(List<AppNotification> items) {
    final now = DateTime.now();
    final today = <AppNotification>[];
    final week = <AppNotification>[];
    final older = <AppNotification>[];
    for (final item in items) {
      final date = item.createdAt?.toLocal();
      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        today.add(item);
      } else if (date != null && now.difference(date).inDays < 7) {
        week.add(item);
      } else {
        older.add(item);
      }
    }
    return [
      if (today.isNotEmpty) ..._group('Today', today),
      if (week.isNotEmpty) ..._group('Earlier This Week', week),
      if (older.isNotEmpty) ..._group('Older', older),
    ];
  }

  List<Widget> _group(String title, List<AppNotification> items) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return _NotificationRow(item: item, onTap: () => _markRead(item));
          },
        ),
      ),
    ];
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = _visual(context, item.type);
    return Card(
      color: item.isRead
          ? context.cvColors.surfaceRaised
          : scheme.primaryContainer.withValues(alpha: 0.18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: visual.$2.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(visual.$1, color: visual.$2),
                  ),
                  if (!item.isRead)
                    Positioned(
                      left: -4,
                      top: -4,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(color: visual.$2),
                          ),
                        ),
                        Text(
                          _timeAgo(item.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _visual(BuildContext context, String type) {
    if (type.contains('CHAPTER') || type.contains('LIBRARY')) {
      return (Icons.auto_stories_rounded, context.cvColors.info);
    }
    if (type.contains('COMMENT') || type.contains('REPLY')) {
      return (Icons.chat_bubble_outline_rounded, context.cvColors.brandPink);
    }
    if (type.contains('PREMIUM') || type.contains('PAYMENT')) {
      return (Icons.workspace_premium_rounded, context.cvColors.rating);
    }
    if (type.contains('SECURITY')) {
      return (Icons.security_rounded, Theme.of(context).colorScheme.error);
    }
    return (Icons.campaign_outlined, Theme.of(context).colorScheme.primary);
  }

  String _timeAgo(DateTime? value) {
    if (value == null) return '';
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${value.day}/${value.month}';
  }
}
