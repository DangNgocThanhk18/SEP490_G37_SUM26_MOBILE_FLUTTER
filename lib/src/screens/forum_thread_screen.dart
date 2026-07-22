import 'dart:async';

import 'package:flutter/material.dart';

import '../models/forum.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ForumThreadScreen extends StatefulWidget {
  const ForumThreadScreen({
    super.key,
    required this.apiClient,
    required this.threadId,
    this.highlightCommentId,
  });

  final ApiClient apiClient;
  final String threadId;
  final String? highlightCommentId;

  @override
  State<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends State<ForumThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _commentKeys = {};
  late Future<_ForumThreadData> _future = _load();
  Timer? _highlightTimer;
  bool _scrollScheduled = false;
  bool _showHighlight = true;

  Future<_ForumThreadData> _load() async {
    final values = await Future.wait([
      widget.apiClient.getForumThread(widget.threadId),
      widget.apiClient.getForumComments(widget.threadId),
    ]);
    return _ForumThreadData(
      thread: values[0] as ForumThread,
      comments: _threadComments(values[1] as List<ForumComment>),
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _scrollScheduled = false;
      _showHighlight = true;
      _future = _load();
    });
  }

  void _scheduleTargetScroll(List<_ThreadedForumComment> comments) {
    final targetId = widget.highlightCommentId;
    if (_scrollScheduled || targetId == null || targetId.isEmpty) return;
    _scrollScheduled = true;

    final targetExists = comments.any((item) => item.comment.id == targetId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!targetExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The referenced comment is unavailable.'),
          ),
        );
        return;
      }
      final targetContext = _commentKeys[targetId]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.3,
        );
      }
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showHighlight = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discussion')),
      body: FutureBuilder<_ForumThreadData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(error: snapshot.error!, onRetry: _retry);
          }

          final data = snapshot.data!;
          _scheduleTargetScroll(data.comments);
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _ThreadHeader(thread: data.thread),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          'Comments',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${data.comments.length}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (data.comments.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.forum_outlined,
                      message: 'No comments in this discussion yet.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: data.comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = data.comments[index];
                        final isTarget =
                            _showHighlight &&
                            item.comment.id == widget.highlightCommentId;
                        return Padding(
                          key: _commentKeys.putIfAbsent(
                            item.comment.id,
                            GlobalKey.new,
                          ),
                          padding: EdgeInsets.only(
                            left: (item.depth * 18).clamp(0, 54).toDouble(),
                          ),
                          child: _CommentCard(
                            comment: item.comment,
                            isReply: item.depth > 0,
                            isHighlighted: isTarget,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_ThreadedForumComment> _threadComments(List<ForumComment> comments) {
    final children = <String, List<ForumComment>>{};
    final roots = <ForumComment>[];
    final ids = comments.map((comment) => comment.id).toSet();
    for (final comment in comments) {
      final parentId = comment.parentId;
      if (parentId == null || !ids.contains(parentId)) {
        roots.add(comment);
      } else {
        children.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    final result = <_ThreadedForumComment>[];
    final visited = <String>{};
    void visit(ForumComment comment, int depth) {
      if (!visited.add(comment.id)) return;
      result.add(_ThreadedForumComment(comment: comment, depth: depth));
      for (final reply in children[comment.id] ?? const <ForumComment>[]) {
        visit(reply, depth + 1);
      }
    }

    for (final root in roots) {
      visit(root, 0);
    }
    for (final comment in comments) {
      visit(comment, comment.parentId == null ? 0 : 1);
    }
    return result;
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.thread});

  final ForumThread thread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(thread.category)),
                if (thread.isLocked)
                  const Chip(
                    avatar: Icon(Icons.lock_outline_rounded, size: 16),
                    label: Text('Locked'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              thread.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Avatar(name: thread.author),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.author,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        _formatDate(thread.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.visibility_outlined,
                  size: 17,
                  color: scheme.outline,
                ),
                const SizedBox(width: 4),
                Text('${thread.views}'),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              _plainText(thread.content),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.isReply,
    required this.isHighlighted,
  });

  final ForumComment comment;
  final bool isReply;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.cvColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: isHighlighted
            ? scheme.primaryContainer.withValues(alpha: 0.42)
            : tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? scheme.primary : tokens.border,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: comment.author, avatarUrl: comment.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  comment.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (isReply) ...[
                Icon(Icons.reply_rounded, size: 16, color: scheme.outline),
                const SizedBox(width: 4),
              ],
              Text(
                _formatDate(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            _plainText(comment.content),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl?.trim();
    return Container(
      width: 34,
      height: 34,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AvatarInitial(name: name),
            )
          : _AvatarInitial(name: name),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Center(
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ForumThreadData {
  const _ForumThreadData({required this.thread, required this.comments});

  final ForumThread thread;
  final List<_ThreadedForumComment> comments;
}

class _ThreadedForumComment {
  const _ThreadedForumComment({required this.comment, required this.depth});

  final ForumComment comment;
  final int depth;
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  final difference = now.difference(local);
  if (!difference.isNegative && difference.inMinutes < 1) return 'Now';
  if (!difference.isNegative && difference.inHours < 1) {
    return '${difference.inMinutes}m';
  }
  if (!difference.isNegative && difference.inDays < 1) {
    return '${difference.inHours}h';
  }
  if (!difference.isNegative && difference.inDays < 7) {
    return '${difference.inDays}d';
  }
  return '${local.day}/${local.month}/${local.year}';
}

String _plainText(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}
