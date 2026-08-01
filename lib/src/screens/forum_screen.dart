import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/forum.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/in_app_notification.dart';
import 'forum_thread_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key, required this.apiClient, this.onSignIn});

  final ApiClient apiClient;
  final VoidCallback? onSignIn;

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<ForumThread>> _future = _load();
  String _query = '';
  String _category = 'All';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ForumThread>> _load() async {
    final threads = [...await widget.apiClient.getForumThreads()];
    threads.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return threads;
  }

  Future<void> _refresh() async {
    widget.apiClient.invalidateForumCache();
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openThread(ForumThread thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ForumThreadScreen(apiClient: widget.apiClient, threadId: thread.id),
      ),
    );
  }

  Future<void> _createThread(List<String> categories) async {
    if (!widget.apiClient.hasToken) {
      InAppNotifications.information(
        context,
        title: context.tr('Sign in'),
        message: context.tr('Sign in to join the community discussion.'),
      );
      widget.onSignIn?.call();
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewThreadSheet(
        apiClient: widget.apiClient,
        categories: categories.where((item) => item != 'All').toList(),
      ),
    );
    if (created == true && mounted) {
      InAppNotifications.success(
        context,
        title: context.tr('Success'),
        message: context.tr('Discussion published.'),
      );
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Community')),
        actions: [
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ForumThread>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(error: snapshot.error!, onRetry: _refresh);
          }

          final threads = snapshot.data ?? const <ForumThread>[];
          final categories = <String>['All'];
          for (final thread in threads) {
            final category = _categoryOf(thread);
            if (!categories.contains(category)) categories.add(category);
          }
          final selectedCategory = categories.contains(_category)
              ? _category
              : 'All';

          final normalizedQuery = _query.trim().toLowerCase();
          final visible = threads.where((thread) {
            final matchesCategory =
                selectedCategory == 'All' ||
                _categoryOf(thread) == selectedCategory;
            final matchesQuery =
                normalizedQuery.isEmpty ||
                thread.title.toLowerCase().contains(normalizedQuery) ||
                thread.content.toLowerCase().contains(normalizedQuery) ||
                thread.author.toLowerCase().contains(normalizedQuery);
            return matchesCategory && matchesQuery;
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 720 ? 28.0 : 16.0;
              final contentWidth = math.min(constraints.maxWidth, 920.0);
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      key: const PageStorageKey('forum-scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        8,
                        horizontal,
                        96,
                      ),
                      children: [
                        _ForumHero(
                          threadCount: threads.length,
                          onCreate: () => _createThread(categories),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: context.tr('Search discussions...'),
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: context.tr('Clear'),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories.map((category) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  selected: selectedCategory == category,
                                  label: Text(context.tr(category)),
                                  onSelected: (_) {
                                    setState(() => _category = category);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr('Latest discussions'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              context.tr(
                                '{count} threads',
                                values: {'count': visible.length},
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (visible.isEmpty)
                          SizedBox(
                            height: 280,
                            child: EmptyState(
                              icon: Icons.forum_outlined,
                              message: context.tr(
                                normalizedQuery.isEmpty &&
                                        selectedCategory == 'All'
                                    ? 'No discussions yet.'
                                    : 'No discussions match your search.',
                              ),
                            ),
                          )
                        else
                          ...visible.map(
                            (thread) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ThreadCard(
                                thread: thread,
                                onTap: () => _openThread(thread),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          List<ForumThread> threads;
          try {
            threads = await _future;
          } catch (_) {
            threads = const [];
          }
          if (!mounted) return;
          final categories = <String>['All', 'General'];
          for (final thread in threads) {
            final category = _categoryOf(thread);
            if (!categories.contains(category)) {
              categories.add(category);
            }
          }
          await _createThread(categories);
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(context.tr('New post')),
      ),
    );
  }
}

class _ForumHero extends StatelessWidget {
  const _ForumHero({required this.threadCount, required this.onCreate});

  final int threadCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            AppTheme.brandPurple,
            context.cvColors.brandPink,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('ComiVerse Community'),
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Share ideas, ask questions, and meet other readers.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr(
                      '{count} community threads',
                      values: {'count': threadCount},
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: context.tr('Start a discussion'),
              onPressed: onCreate,
              icon: const Icon(Icons.edit_square, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onTap});

  final ForumThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.cvColors;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  _initial(thread.author),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (thread.isPinned)
                          Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: tokens.brandPink,
                          ),
                        Text(
                          thread.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (thread.isLocked)
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: scheme.outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _plainText(thread.content),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.48,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _categoryOf(thread),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        Text(
                          '${thread.author} · ${_formatDate(context, thread.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        _Stat(
                          icon: Icons.visibility_outlined,
                          value: '${thread.views}',
                        ),
                        _Stat(
                          icon: Icons.chat_bubble_outline_rounded,
                          value: '${thread.replies}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 3),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NewThreadSheet extends StatefulWidget {
  const _NewThreadSheet({required this.apiClient, required this.categories});

  final ApiClient apiClient;
  final List<String> categories;

  @override
  State<_NewThreadSheet> createState() => _NewThreadSheetState();
}

class _NewThreadSheetState extends State<_NewThreadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late String _category = widget.categories.isEmpty
      ? 'General'
      : widget.categories.first;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.apiClient.createForumThread(
        title: _titleController.text.trim(),
        category: _category,
        content: _contentController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      InAppNotifications.error(
        context,
        title: context.tr('Error'),
        message: context.localizedError(error),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories.isEmpty
        ? const ['General']
        : widget.categories;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('Start a discussion'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: 120,
                decoration: InputDecoration(labelText: context.tr('Title')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr('Please enter a thread title.')
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(labelText: context.tr('Category')),
                items: categories
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _category = value;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 5,
                maxLines: 10,
                maxLength: 4000,
                decoration: InputDecoration(
                  labelText: context.tr('What would you like to discuss?'),
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr('Please enter a thread description.')
                    : null,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(context.tr('Publish discussion')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

String _categoryOf(ForumThread thread) {
  final category = thread.category.trim();
  return category.isEmpty ? 'General' : category;
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) return context.tr('Recently');
  final difference = DateTime.now().difference(value.toLocal());
  if (!difference.isNegative && difference.inMinutes < 1) {
    return context.tr('Now');
  }
  if (!difference.isNegative && difference.inHours < 1) {
    return context.tr('{count}m', values: {'count': difference.inMinutes});
  }
  if (!difference.isNegative && difference.inDays < 1) {
    return context.tr('{count}h', values: {'count': difference.inHours});
  }
  if (!difference.isNegative && difference.inDays < 7) {
    return context.tr('{count}d', values: {'count': difference.inDays});
  }
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String _plainText(String value) {
  return value
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .trim();
}
