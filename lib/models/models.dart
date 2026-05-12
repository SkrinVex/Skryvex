class UserModel {
  final int id;
  final String email;
  final String name;
  final String? username;
  final String? avatarUrl;

  const UserModel({required this.id, required this.email, required this.name, this.username, this.avatarUrl});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as int,
        email: j['email'] as String,
        name: j['name'] as String,
        username: j['username'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'name': name, 'username': username, 'avatar_url': avatarUrl,
  };
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

class ChannelModel {
  final int id;
  final int ownerId;
  final String name;
  final String username;
  final String? description;
  final String? avatarUrl;
  final int subscriberCount;
  final bool subscribed;
  final int unreadCount;
  final String? lastPost;

  const ChannelModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.username,
    this.description,
    this.avatarUrl,
    required this.subscriberCount,
    required this.subscribed,
    required this.unreadCount,
    this.lastPost,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> j) => ChannelModel(
        id: j['id'] as int,
        ownerId: j['owner_id'] as int,
        name: j['name'] as String,
        username: j['username'] as String,
        description: j['description'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        subscriberCount: int.tryParse(j['subscriber_count']?.toString() ?? '0') ?? 0,
        subscribed: j['subscribed'] as bool? ?? false,
        unreadCount: int.tryParse(j['unread_count']?.toString() ?? '0') ?? 0,
        lastPost: j['last_post'] as String?,
      );

  ChannelModel copyWith({bool? subscribed, int? unreadCount, String? avatarUrl}) => ChannelModel(
        id: id, ownerId: ownerId, name: name, username: username,
        description: description, avatarUrl: avatarUrl ?? this.avatarUrl,
        subscriberCount: subscriberCount,
        subscribed: subscribed ?? this.subscribed,
        unreadCount: unreadCount ?? this.unreadCount,
        lastPost: lastPost,
      );
}

class ChannelPostModel {
  final int id;
  final int channelId;
  final String? text;
  final String? mediaType;
  final String? mediaUrl;
  final bool mediaDeleted;
  final DateTime createdAt;
  final String? channelName;
  final String? channelAvatar;
  final int? replyToId;
  final String? replyText;
  final String? replyMediaType;
  final bool replyMediaDeleted;

  const ChannelPostModel({
    required this.id,
    required this.channelId,
    this.text,
    this.mediaType,
    this.mediaUrl,
    required this.mediaDeleted,
    required this.createdAt,
    this.channelName,
    this.channelAvatar,
    this.replyToId,
    this.replyText,
    this.replyMediaType,
    this.replyMediaDeleted = false,
  });

  factory ChannelPostModel.fromJson(Map<String, dynamic> j) => ChannelPostModel(
        id: j['id'] as int,
        channelId: j['channel_id'] as int,
        text: j['text'] as String?,
        mediaType: j['media_type'] as String?,
        mediaUrl: j['media_url'] as String?,
        mediaDeleted: j['media_deleted'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        channelName: j['channel_name'] as String?,
        channelAvatar: j['channel_avatar'] as String?,
        replyToId: j['reply_to_id'] as int?,
        replyText: j['reply_text'] as String?,
        replyMediaType: j['reply_media_type'] as String?,
        replyMediaDeleted: j['reply_media_deleted'] as bool? ?? false,
      );
}
