import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/global_chat_realtime.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({
    super.key,
    required this.apiClient,
    required this.user,
    required this.onSignIn,
    this.realtime,
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final VoidCallback onSignIn;
  final GlobalChatRealtime? realtime;

  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  static const _pageSize = 30;

  final _messages = <ChatMessage>[];
  final _scrollController = ScrollController();
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<ChatConnectionStatus>? _statusSubscription;
  GlobalChatRealtime? _realtime;
  ChatConnectionStatus _connectionStatus = ChatConnectionStatus.disconnected;
  Object? _loadError;
  String? _sendError;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingInitial = false;
  bool _loadingOlder = false;
  bool _sending = false;

  bool get _authenticated => widget.apiClient.hasToken;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    if (_authenticated) {
      _realtime =
          widget.realtime ??
          StompGlobalChatRealtime(apiClient: widget.apiClient);
      _messageSubscription = _realtime!.messages.listen(_receiveMessage);
      _statusSubscription = _realtime!.statuses.listen((status) {
        if (mounted) setState(() => _connectionStatus = status);
      });
      _realtime!.connect();
      unawaited(_loadInitial());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    unawaited(_messageSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    _realtime?.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _loadError = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final result = await widget.apiClient.getGlobalChatMessages(
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _mergeMessages(result.messages);
        _hasMore = result.hasMore;
      });
      _scrollToBottom(jump: true);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingInitial || _loadingOlder || !_hasMore) return;
    final previousExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    setState(() => _loadingOlder = true);
    try {
      final nextPage = _page + 1;
      final result = await widget.apiClient.getGlobalChatMessages(
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _mergeMessages(result.messages);
        _page = nextPage;
        _hasMore = result.hasMore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - previousExtent;
        _scrollController.jumpTo(
          (_scrollController.offset + addedExtent).clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      });
    } catch (_) {
      // Keep the current conversation visible when older history is unavailable.
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _handleScroll() {
    if (_scrollController.hasClients && _scrollController.offset < 96) {
      unawaited(_loadOlder());
    }
  }

  void _receiveMessage(ChatMessage message) {
    if (!mounted) return;
    final shouldFollow = _isNearBottom;
    setState(() => _mergeMessages([message]));
    if (shouldFollow || _isMine(message)) _scrollToBottom();
  }

  void _mergeMessages(Iterable<ChatMessage> incoming) {
    final byId = <String, ChatMessage>{
      for (final message in _messages) message.id: message,
    };
    for (final message in incoming) {
      if (message.id.isNotEmpty) byId[message.id] = message;
    }
    _messages
      ..clear()
      ..addAll(byId.values)
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.maxScrollExtent -
            _scrollController.offset <
        140;
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _composerController.text.trim();
    if (_sending || content.isEmpty) return;
    if (content.length > 2000) {
      setState(() => _sendError = context.tr('Message is too long.'));
      return;
    }

    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final sent = await widget.apiClient.sendGlobalChatMessage(content);
      if (!mounted) return;
      _composerController.clear();
      setState(() => _mergeMessages([sent]));
      _scrollToBottom();
    } catch (error) {
      if (mounted) setState(() => _sendError = context.localizedError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isMine(ChatMessage message) {
    final user = widget.user ?? widget.apiClient.currentUser;
    final userId = user?.userId;
    if (userId != null && userId.isNotEmpty) {
      return message.senderId == userId;
    }
    return message.senderName == user?.displayName;
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete message?')),
        content: Text(
          context.tr('This message will be removed from Global Chat.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiClient.deleteChatMessage(message.id);
      if (mounted) {
        setState(() => _messages.removeWhere((item) => item.id == message.id));
      }
    } catch (error) {
      if (mounted) setState(() => _sendError = context.localizedError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Global Chat')),
            if (_authenticated) _ConnectionLabel(status: _connectionStatus),
          ],
        ),
      ),
      body: !_authenticated ? _buildGuestState() : _buildConversation(),
    );
  }

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('Join the ComiVerse conversation'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Sign in to read and send messages in Global Chat.'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: widget.onSignIn,
              icon: const Icon(Icons.login_rounded),
              label: Text(context.tr('Sign In')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    if (_loadingInitial && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _messages.isEmpty) {
      return ApiErrorState(error: _loadError!, onRetry: _loadInitial);
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadInitial,
            child: _messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.58,
                        child: EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          message: context.tr(
                            'No messages yet. Start the conversation.',
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    key: const Key('global-chat-message-list'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                    itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_loadingOlder && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final offset = _loadingOlder ? 1 : 0;
                      final message = _messages[index - offset];
                      return _MessageBubble(
                        message: message,
                        isMine: _isMine(message),
                        avatarUrl: _resolveImageUrl(message.senderAvatar),
                        onLongPress: _isMine(message)
                            ? () => _confirmDelete(message)
                            : null,
                      );
                    },
                  ),
          ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildComposer() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_sendError != null) ...[
                Text(
                  _sendError!,
                  key: const Key('global-chat-send-error'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('global-chat-composer'),
                      controller: _composerController,
                      focusNode: _composerFocus,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: context.tr('Write a message...'),
                        prefixIcon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton.filled(
                      key: const Key('global-chat-send'),
                      tooltip: context.tr('Send message'),
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveImageUrl(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    final uri = Uri.tryParse(clean);
    if (uri?.hasScheme == true) return clean;
    final base = Uri.parse(widget.apiClient.baseUrl);
    return '${base.origin}${clean.startsWith('/') ? '' : '/'}$clean';
  }
}

class _ConnectionLabel extends StatelessWidget {
  const _ConnectionLabel({required this.status});

  final ChatConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ChatConnectionStatus.connected => (
        context.tr('Live'),
        context.cvColors.success,
      ),
      ChatConnectionStatus.connecting => (
        context.tr('Connecting...'),
        context.cvColors.warning,
      ),
      ChatConnectionStatus.disconnected => (
        context.tr('Reconnecting...'),
        Theme.of(context).colorScheme.error,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.avatarUrl,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final String? avatarUrl;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isMine
        ? scheme.primary
        : context.cvColors.surfaceSubtle;
    final foreground = isMine ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      label: '${message.senderName}: ${message.content}',
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[
                _ChatAvatar(name: message.senderName, imageUrl: avatarUrl),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMine)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 3),
                        child: Text(
                          message.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    GestureDetector(
                      onLongPress: onLongPress,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(8),
                            topRight: const Radius.circular(8),
                            bottomLeft: Radius.circular(isMine ? 8 : 2),
                            bottomRight: Radius.circular(isMine ? 2 : 8),
                          ),
                          border: isMine
                              ? null
                              : Border.all(color: context.cvColors.border),
                        ),
                        child: Text(
                          message.content,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: foreground),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                      child: Text(
                        _formatTime(message.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return time;
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} $time';
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 17,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      child: Text(initial, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
