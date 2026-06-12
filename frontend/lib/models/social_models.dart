int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class FriendUser {
  final int id;
  final String fullName;
  final String email;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  const FriendUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: _asInt(json['id']),
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      unreadCount: _asInt(json['unread_count']),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: DateTime.tryParse(
        json['last_message_at']?.toString() ?? '',
      ),
    );
  }
}

class FriendRequest {
  final int id;
  final int senderId;
  final String fullName;
  final String email;
  final DateTime? createdAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.fullName,
    required this.email,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: _asInt(json['id']),
      senderId: _asInt(json['sender_id']),
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class UserSearchResult {
  final int id;
  final String fullName;
  final String email;
  final String relationshipStatus;

  const UserSearchResult({
    required this.id,
    required this.fullName,
    required this.email,
    required this.relationshipStatus,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: _asInt(json['id']),
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      relationshipStatus: json['relationship_status']?.toString() ?? 'NONE',
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime? readAt;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.readAt,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _asInt(json['id']),
      senderId: _asInt(json['sender_id']),
      receiverId: _asInt(json['receiver_id']),
      content: json['content']?.toString() ?? '',
      readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
