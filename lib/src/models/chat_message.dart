class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.senderAvatar,
    this.status = 'ACTIVE',
  });

  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String status;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['createdAt'] ?? json['timestamp'] ?? '').toString();
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['userId'] ?? '').toString(),
      senderName: (json['senderName'] ?? json['sender'] ?? 'Member').toString(),
      senderAvatar:
          (json['senderAvatar'] ?? json['avatar'] ?? json['avatarUrl'])
              ?.toString(),
      content: (json['content'] ?? json['text'] ?? '').toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      createdAt: DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now(),
    );
  }
}

class ChatMessagePage {
  const ChatMessagePage({required this.messages, required this.hasMore});

  final List<ChatMessage> messages;
  final bool hasMore;
}
