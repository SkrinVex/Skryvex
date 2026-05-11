class UserModel {
  final int id;
  final String email;
  final String name;
  final String? avatarUrl;

  const UserModel({required this.id, required this.email, required this.name, this.avatarUrl});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as int,
        email: j['email'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatar_url'] as String?,
      );
}

class ChatModel {
  final int id;
  final int partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatModel({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatModel.fromJson(Map<String, dynamic> j) => ChatModel(
        id: j['id'] as int,
        partnerId: j['partner_id'] as int,
        partnerName: j['partner_name'] as String,
        partnerAvatar: j['partner_avatar'] as String?,
        lastMessage: j['last_message'] as String?,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.parse(j['last_message_at'] as String)
            : null,
        unreadCount: int.tryParse(j['unread_count']?.toString() ?? '0') ?? 0,
      );
}

class MessageModel {
  final int id;
  final int chatId;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String? text;
  final DateTime createdAt;
  final int? replyToId;
  final String? replyText;
  final String? replySenderName;
  final String? replyMediaType;
  final bool replyMediaDeleted;
  final String? mediaType;   // 'image' | 'video' | null
  final String? mediaUrl;    // presigned URL
  final bool mediaDeleted;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.text,
    required this.createdAt,
    this.replyToId,
    this.replyText,
    this.replySenderName,
    this.replyMediaType,
    this.replyMediaDeleted = false,
    this.mediaType,
    this.mediaUrl,
    this.mediaDeleted = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'] as int,
        chatId: j['chat_id'] as int,
        senderId: j['sender_id'] as int,
        senderName: j['sender_name'] as String,
        senderAvatar: j['sender_avatar'] as String?,
        text: j['text'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        replyToId: j['reply_to_id'] as int?,
        replyText: j['reply_text'] as String?,
        replySenderName: j['reply_sender_name'] as String?,
        replyMediaType: j['reply_media_type'] as String?,
        replyMediaDeleted: j['reply_media_deleted'] as bool? ?? false,
        mediaType: j['media_type'] as String?,
        mediaUrl: j['media_url'] as String?,
        mediaDeleted: j['media_deleted'] as bool? ?? false,
      );
}
