enum NotificationDestinationType {
  none,
  home,
  explore,
  library,
  profile,
  premium,
  comic,
  chapter,
  forumThread,
  unsupported,
}

class NotificationDestination {
  const NotificationDestination({
    required this.type,
    this.comicId,
    this.chapterId,
    this.threadId,
    this.commentId,
  });

  const NotificationDestination.none()
    : this(type: NotificationDestinationType.none);

  final NotificationDestinationType type;
  final String? comicId;
  final String? chapterId;
  final String? threadId;
  final String? commentId;

  factory NotificationDestination.parse(String? actionUrl) {
    final raw = actionUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return const NotificationDestination.none();
    }
    if (!raw.startsWith('/') || raw.startsWith('//')) {
      return const NotificationDestination(
        type: NotificationDestinationType.unsupported,
      );
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return const NotificationDestination(
        type: NotificationDestinationType.unsupported,
      );
    }

    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return const NotificationDestination(
        type: NotificationDestinationType.home,
      );
    }

    if (segments.length == 1) {
      return switch (segments.first.toLowerCase()) {
        'explore' => const NotificationDestination(
          type: NotificationDestinationType.explore,
        ),
        'library' => const NotificationDestination(
          type: NotificationDestinationType.library,
        ),
        'profile' => const NotificationDestination(
          type: NotificationDestinationType.profile,
        ),
        'premium' => const NotificationDestination(
          type: NotificationDestinationType.premium,
        ),
        _ => const NotificationDestination(
          type: NotificationDestinationType.unsupported,
        ),
      };
    }

    if (segments.length == 2 && segments.first == 'comic') {
      return NotificationDestination(
        type: NotificationDestinationType.comic,
        comicId: segments[1],
      );
    }

    if (segments.length == 4 &&
        segments.first == 'comic' &&
        segments[2] == 'chapter') {
      return NotificationDestination(
        type: NotificationDestinationType.chapter,
        comicId: segments[1],
        chapterId: segments[3],
      );
    }

    if (segments.length == 3 &&
        segments[0] == 'forum' &&
        segments[1] == 'thread') {
      return NotificationDestination(
        type: NotificationDestinationType.forumThread,
        threadId: segments[2],
        commentId:
            uri.queryParameters['comment'] ?? uri.queryParameters['highlight'],
      );
    }

    return const NotificationDestination(
      type: NotificationDestinationType.unsupported,
    );
  }
}
