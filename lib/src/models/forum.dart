class ForumThread {
  const ForumThread({
    required this.id,
    required this.title,
    required this.author,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.isLocked,
    required this.views,
    required this.replies,
  });

  final String id;
  final String title;
  final String author;
  final String content;
  final String category;
  final DateTime? createdAt;
  final bool isLocked;
  final int views;
  final int replies;

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    return ForumThread(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Discussion').toString(),
      author: (json['author'] ?? 'ComiVerse member').toString(),
      content: (json['content'] ?? '').toString(),
      category: (json['category'] ?? 'General').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      isLocked: json['isLocked'] == true,
      views: _asInt(json['views']),
      replies: _asInt(json['replies']),
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.userId,
    required this.author,
    required this.content,
    required this.parentId,
    required this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String author;
  final String content;
  final String? parentId;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory ForumComment.fromJson(Map<String, dynamic> json) {
    return ForumComment(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      author: (json['author'] ?? 'ComiVerse member').toString(),
      content: (json['content'] ?? '').toString(),
      parentId: _optionalString(json['parentId']),
      avatarUrl: _optionalString(json['avatarUrl']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
