enum ContentCommentTarget { comic, chapter }

class ContentComment {
  const ContentComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.parentId,
    required this.mentionId,
    required this.mentionName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final String? parentId;
  final String? mentionId;
  final String? mentionName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ContentComment.fromJson(Map<String, dynamic> json) {
    return ContentComment(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userName: (json['userName'] ?? 'ComiVerse member').toString(),
      userAvatar: _optionalString(json['userAvatar']),
      content: (json['content'] ?? '').toString(),
      parentId: _optionalString(json['parentId']),
      mentionId: _optionalString(json['mentionId']),
      mentionName: _optionalString(json['mentionName']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class ContentCommentPage {
  const ContentCommentPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
  });

  final List<ContentComment> items;
  final int page;
  final int pageSize;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
