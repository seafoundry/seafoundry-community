// @tier: community

import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Represents a message in a channel within the SeaFoundry system.
///
/// Messages support mentions (via [mentions]), attachments (via [attachments]),
/// reactions (via [reactions] map), and threading (via [replyToMessageId]).
class ChannelMessage extends Equatable {
  const ChannelMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.mentions = const [],
    this.attachments = const [],
    this.reactions = const {},
    this.readBy = const [],
    this.replyToMessageId,
    this.replyToPreview,
    this.isPinned = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.metadata,
  });

  /// Create a ChannelMessage from JSON.
  factory ChannelMessage.fromJson(Map<String, dynamic> json) {
    return ChannelMessage(
      id: json['id'] as String,
      channelId: json['channelId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
      senderName: json['senderName'] as String?,
      mentions: List<String>.from(json['mentions'] ?? []),
      attachments: (json['attachments'] as List?)
              ?.map((e) => ChannelAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          ) ??
          const {},
      readBy: List<String>.from(json['readBy'] ?? []),
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToPreview: json['replyToPreview'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Unique identifier for the message.
  final String id;

  /// ID of the channel this message belongs to.
  final String channelId;

  /// User ID of the message sender.
  final String senderId;

  /// Message text content.
  final String content;

  /// ISO 8601 timestamp when the message was created.
  final String createdAt;

  /// Display name of the message sender (optional, can be fetched separately).
  final String? senderName;

  /// List of mentioned user IDs (extracted from @mentions in content).
  final List<String> mentions;

  /// List of file/media attachments.
  final List<ChannelAttachment> attachments;

  /// Map of emoji reactions to lists of user IDs who reacted.
  /// Example: {'thumbsUp': ['user1', 'user2'], 'heart': ['user3']}
  final Map<String, List<String>> reactions;

  /// List of user IDs who have read this message.
  final List<String> readBy;

  /// ID of the message this is replying to (for threading).
  final String? replyToMessageId;

  /// Preview text of the message being replied to.
  final String? replyToPreview;

  /// Whether this message is pinned in the channel.
  final bool isPinned;

  /// Whether this message has been edited.
  final bool isEdited;

  /// Whether this message has been soft-deleted.
  final bool isDeleted;

  /// Additional metadata for extensibility.
  final Map<String, dynamic>? metadata;

  /// Whether this message is a reply to another message.
  bool get isReply => replyToMessageId != null;

  /// Whether this message has attachments.
  bool get hasAttachments => attachments.isNotEmpty;

  /// Whether this message has reactions.
  bool get hasReactions => reactions.isNotEmpty;

  /// Parse createdAt timestamp to DateTime.
  DateTime get createdAtDateTime => DateTime.parse(createdAt);

  /// Get total count of reactions for a specific emoji.
  int getReactionCount(String emoji) {
    return reactions[emoji]?.length ?? 0;
  }

  /// Check if a specific user has reacted with a specific emoji.
  bool userHasReacted(String userId, String emoji) {
    return reactions[emoji]?.contains(userId) ?? false;
  }

  /// Get total count of all reactions.
  int get totalReactionCount {
    return reactions.values.fold<int>(
      0,
      (sum, userList) => sum + userList.length,
    );
  }

  /// Check if a user has read this message.
  bool hasBeenReadBy(String userId) => readBy.contains(userId);

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelId': channelId,
      'senderId': senderId,
      'content': content,
      'createdAt': createdAt,
      if (senderName != null) 'senderName': senderName,
      'mentions': mentions,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'reactions': reactions,
      'readBy': readBy,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToPreview != null) 'replyToPreview': replyToPreview,
      'isPinned': isPinned,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create a copy with optional new values.
  ChannelMessage copyWith({
    String? id,
    String? channelId,
    String? senderId,
    String? content,
    String? createdAt,
    String? senderName,
    List<String>? mentions,
    List<ChannelAttachment>? attachments,
    Map<String, List<String>>? reactions,
    List<String>? readBy,
    String? replyToMessageId,
    String? replyToPreview,
    bool? isPinned,
    bool? isEdited,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return ChannelMessage(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      mentions: mentions ?? this.mentions,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      readBy: readBy ?? this.readBy,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      isPinned: isPinned ?? this.isPinned,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        channelId,
        senderId,
        content,
        createdAt,
        senderName,
        mentions,
        attachments,
        reactions,
        readBy,
        replyToMessageId,
        replyToPreview,
        isPinned,
        isEdited,
        isDeleted,
        metadata,
      ];
}

/// Represents an attachment in a channel message.
///
/// Supports various attachment types including images, files, and videos.
class ChannelAttachment extends Equatable {
  const ChannelAttachment({
    required this.id,
    required this.type,
    required this.url,
    required this.filename,
    this.mimeType,
    this.sizeBytes,
    this.thumbnailUrl,
  });

  /// Create a ChannelAttachment from JSON.
  factory ChannelAttachment.fromJson(Map<String, dynamic> json) {
    return ChannelAttachment(
      id: json['id'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String?,
      sizeBytes: safeInt(json['sizeBytes']),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  /// Unique identifier for the attachment.
  final String id;

  /// Type of attachment ('image', 'file', 'video').
  final String type;

  /// URL where the attachment can be accessed.
  final String url;

  /// Original filename of the attachment.
  final String filename;

  /// MIME type of the attachment (e.g., 'image/png', 'application/pdf').
  final String? mimeType;

  /// Size of the attachment in bytes.
  final int? sizeBytes;

  /// URL of a thumbnail preview (for images/videos).
  final String? thumbnailUrl;

  /// Whether this attachment is an image.
  bool get isImage => type == 'image';

  /// Whether this attachment is a video.
  bool get isVideo => type == 'video';

  /// Whether this attachment is a generic file.
  bool get isFile => type == 'file';

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'filename': filename,
      if (mimeType != null) 'mimeType': mimeType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }

  @override
  List<Object?> get props => [
        id,
        type,
        url,
        filename,
        mimeType,
        sizeBytes,
        thumbnailUrl,
      ];
}
