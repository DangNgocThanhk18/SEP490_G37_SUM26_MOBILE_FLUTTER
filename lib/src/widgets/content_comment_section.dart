import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/content_comment.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'in_app_notification.dart';

class ContentCommentSection extends StatefulWidget {
  const ContentCommentSection({
    super.key,
    required this.apiClient,
    required this.target,
    required this.targetId,
  });

  final ApiClient apiClient;
  final ContentCommentTarget target;
  final String targetId;

  @override
  State<ContentCommentSection> createState() => _ContentCommentSectionState();
}

class _ContentCommentSectionState extends State<ContentCommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final Map<String, List<ContentComment>> _replies = {};
  final Set<String> _expandedRoots = {};
  final Set<String> _loadingReplies = {};
  List<ContentComment> _comments = const [];
  ContentComment? _replyingTo;
  String? _replyRootId;
  Object? _error;
  int _page = 1;
  int _totalPages = 0;
  int _totalElements = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.apiClient.hasToken) {
      unawaited(_loadComments());
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant ContentCommentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target ||
        oldWidget.targetId != widget.targetId) {
      _comments = const [];
      _replies.clear();
      _expandedRoots.clear();
      _page = 1;
      _totalPages = 0;
      _totalElements = 0;
      _error = null;
      unawaited(_loadComments());
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments({int page = 1, bool append = false}) async {
    if (!widget.apiClient.hasToken) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await widget.apiClient.getContentComments(
        target: widget.target,
        targetId: widget.targetId,
        page: page,
        size: 10,
      );
      if (!mounted) return;
      setState(() {
        _comments = append
            ? _mergeComments(_comments, result.items)
            : result.items;
        _page = result.page;
        _totalPages = result.totalPages;
        _totalElements = result.totalElements;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<ContentComment> _mergeComments(
    List<ContentComment> current,
    List<ContentComment> incoming,
  ) {
    final ids = current.map((comment) => comment.id).toSet();
    return [...current, ...incoming.where((comment) => ids.add(comment.id))];
  }

  Future<void> _loadReplies(ContentComment root) async {
    if (_loadingReplies.contains(root.id)) return;
    setState(() => _loadingReplies.add(root.id));
    try {
      final result = await widget.apiClient.getContentComments(
        target: widget.target,
        targetId: widget.targetId,
        parentId: root.id,
        page: 1,
        size: 100,
      );
      if (mounted) setState(() => _replies[root.id] = result.items);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loadingReplies.remove(root.id));
    }
  }

  Future<void> _toggleReplies(ContentComment root) async {
    final shouldExpand = !_expandedRoots.contains(root.id);
    setState(() {
      if (shouldExpand) {
        _expandedRoots.add(root.id);
      } else {
        _expandedRoots.remove(root.id);
      }
    });
    if (shouldExpand && !_replies.containsKey(root.id)) {
      await _loadReplies(root);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _submitting) return;
    if (!widget.apiClient.hasToken) {
      _showSignInRequired();
      return;
    }
    setState(() => _submitting = true);
    try {
      final created = await widget.apiClient.createContentComment(
        target: widget.target,
        targetId: widget.targetId,
        content: content,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _comments = [created, ..._comments];
        _totalElements++;
      });
      InAppNotifications.success(
        context,
        title: context.tr('Success'),
        message: context.tr('Comment posted.'),
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startReply(ContentComment comment, String rootId) {
    if (!widget.apiClient.hasToken) {
      _showSignInRequired();
      return;
    }
    setState(() {
      _replyingTo = comment;
      _replyRootId = rootId;
      _replyController.clear();
      _expandedRoots.add(rootId);
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyRootId = null;
      _replyController.clear();
    });
  }

  Future<void> _postReply() async {
    final targetComment = _replyingTo;
    final rootId = _replyRootId;
    final content = _replyController.text.trim();
    if (targetComment == null ||
        rootId == null ||
        content.isEmpty ||
        _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final created = await widget.apiClient.createContentComment(
        target: widget.target,
        targetId: widget.targetId,
        content: content,
        parentId: targetComment.id,
        mentionId: targetComment.userId,
      );
      if (!mounted) return;
      setState(() {
        final current = _replies[rootId] ?? const <ContentComment>[];
        _replies[rootId] = _mergeComments(current, [created]);
        _expandedRoots.add(rootId);
        _replyingTo = null;
        _replyRootId = null;
        _replyController.clear();
      });
      InAppNotifications.success(
        context,
        title: context.tr('Success'),
        message: context.tr('Reply posted.'),
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteComment(ContentComment comment, {String? rootId}) async {
    final confirmed = await InAppModal.confirm(
      context,
      title: context.tr('Delete comment?'),
      message: context.tr('This action cannot be undone.'),
      confirmLabel: context.tr('Delete'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.apiClient.deleteContentComment(
        target: widget.target,
        commentId: comment.id,
      );
      if (!mounted) return;
      setState(() {
        if (rootId == null) {
          _comments = _comments.where((item) => item.id != comment.id).toList();
          _replies.remove(comment.id);
          _expandedRoots.remove(comment.id);
          if (_totalElements > 0) _totalElements--;
        } else {
          _replies[rootId] = (_replies[rootId] ?? const <ContentComment>[])
              .where((item) => item.id != comment.id)
              .toList();
        }
      });
      InAppNotifications.success(
        context,
        title: context.tr('Success'),
        message: context.tr('Comment deleted.'),
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  bool _canDelete(ContentComment comment) {
    final user = widget.apiClient.currentUser;
    if (user == null) return false;
    if (user.userId?.isNotEmpty == true && user.userId == comment.userId) {
      return true;
    }
    return const {'ADMIN', 'STAFF'}.contains(user.role?.toUpperCase());
  }

  void _showSignInRequired() {
    InAppNotifications.show(
      context,
      type: InAppNotificationType.information,
      title: context.tr('Information'),
      message: context.tr('Sign in to join the discussion.'),
    );
  }

  void _showError(Object error) {
    InAppNotifications.error(
      context,
      title: context.tr('Error'),
      message: context.localizedError(error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('Comments'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$_totalElements',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.apiClient.hasToken)
          _CommentComposer(
            controller: _commentController,
            submitting: _submitting,
            onSubmit: _postComment,
          )
        else
          _SignInPrompt(onTap: _showSignInRequired),
        const SizedBox(height: 18),
        if (_loading && _comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _comments.isEmpty)
          _InlineCommentError(
            message: context.localizedError(_error!),
            onRetry: _loadComments,
          )
        else if (!widget.apiClient.hasToken)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              context.tr('Sign in to view and join the discussion.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 38,
                  color: scheme.outline,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('No comments yet. Start the conversation.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return _buildCommentThread(comment);
            },
          ),
        if (_page < _totalPages) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadingMore
                  ? null
                  : () => _loadComments(page: _page + 1, append: true),
              icon: _loadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(context.tr('Load more comments')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentThread(ContentComment root) {
    final expanded = _expandedRoots.contains(root.id);
    final replies = _replies[root.id] ?? const <ContentComment>[];
    final loadingReplies = _loadingReplies.contains(root.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommentCard(
          comment: root,
          canDelete: _canDelete(root),
          onReply: () => _startReply(root, root.id),
          onDelete: () => _deleteComment(root),
          onToggleReplies: () => _toggleReplies(root),
          repliesExpanded: expanded,
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.only(left: 18, top: 8),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Column(
              children: [
                if (loadingReplies)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (replies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.tr('No replies yet.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  for (final reply in replies) ...[
                    _CommentCard(
                      comment: reply,
                      compact: true,
                      canDelete: _canDelete(reply),
                      onReply: () => _startReply(reply, root.id),
                      onDelete: () => _deleteComment(reply, rootId: root.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                if (_replyRootId == root.id && _replyingTo != null)
                  _ReplyComposer(
                    controller: _replyController,
                    replyingTo: _replyingTo!.userName,
                    submitting: _submitting,
                    onCancel: _cancelReply,
                    onSubmit: _postReply,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      maxLength: 2000,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: context.tr('Share your thoughts…'),
        alignLabelWithHint: true,
        suffixIcon: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filled(
            tooltip: context.tr('Post comment'),
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.replyingTo,
    required this.submitting,
    required this.onCancel,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String replyingTo;
  final bool submitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(
                    'Replying to {name}',
                    values: {'name': replyingTo},
                  ),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: Text(context.tr('Cancel')),
              ),
            ],
          ),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            maxLength: 2000,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: context.tr('Write a reply…'),
              suffixIcon: IconButton(
                tooltip: context.tr('Post reply'),
                onPressed: submitting ? null : onSubmit,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.canDelete,
    required this.onReply,
    required this.onDelete,
    this.onToggleReplies,
    this.repliesExpanded = false,
    this.compact = false,
  });

  final ContentComment comment;
  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback? onToggleReplies;
  final bool repliesExpanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.cvColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: compact
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
            : tokens.surfaceRaised,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CommentAvatar(
                  name: comment.userName,
                  imageUrl: comment.userAvatar,
                  size: compact ? 30 : 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatCommentDate(context, comment.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: context.tr('Delete'),
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: scheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (comment.mentionName != null)
              Text(
                '@${comment.mentionName}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            SelectableText(
              comment.content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded, size: 17),
                  label: Text(context.tr('Reply')),
                ),
                if (onToggleReplies != null)
                  TextButton.icon(
                    onPressed: onToggleReplies,
                    icon: Icon(
                      repliesExpanded
                          ? Icons.expand_less_rounded
                          : Icons.forum_outlined,
                      size: 17,
                    ),
                    label: Text(
                      context.tr(
                        repliesExpanded ? 'Hide replies' : 'View replies',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.name,
    required this.imageUrl,
    required this.size,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
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
    final value = name.trim();
    return Center(
      child: Text(
        value.isEmpty ? '?' : value.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(context.tr('Sign in to join the discussion.')),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineCommentError extends StatelessWidget {
  const _InlineCommentError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('Retry')),
          ),
        ],
      ),
    );
  }
}

String _formatCommentDate(BuildContext context, DateTime? value) {
  if (value == null) return '';
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
