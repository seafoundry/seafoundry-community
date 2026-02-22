// @tier: community

import 'package:equatable/equatable.dart';

/// Represents a comment on an event or record in the SeaFoundry system.
///
/// Comments support threading (via [parentCommentId]), mentions (via [mentions]),
/// and reactions (via [reactions] map).
class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.organizationId,
    required this.targetType,
    required this.targetId,
    required this.authorUid,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.mentions = const [],
    this.reactions = const {},
    this.isEdited = false,
    this.isDeleted = false,
    this.metadata,
  });

  /// Create a Comment from JSON
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String,
      authorUid: json['authorUid'] as String,
      authorName: json['authorName'] as String,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
      parentCommentId: json['parentCommentId'] as String?,
      mentions: List<String>.from(json['mentions'] ?? []),
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          ) ??
          const {},
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Unique identifier for the comment
  final String id;

  /// Organization this comment belongs to
  final String organizationId;

  /// Type of target entity ('event', 'organism_record', 'site', 'group')
  final String targetType;

  /// ID of the target entity being commented on
  final String targetId;

  /// Firebase Auth UID of the comment author.
  final String authorUid;

  /// Display name of the comment author
  final String authorName;

  /// Comment text content
  final String content;

  /// ISO 8601 timestamp when the comment was created
  final String createdAt;

  /// ISO 8601 timestamp when the comment was last updated
  final String? updatedAt;

  /// ID of parent comment if this is a reply (for threading)
  final String? parentCommentId;

  /// List of mentioned user emails (extracted from @mentions in content)
  final List<String> mentions;

  /// Map of emoji reactions to lists of user emails who reacted
  /// Example: {'👍': ['user1@example.com', 'user2@example.com'], '❤️': ['user3@example.com']}
  final Map<String, List<String>> reactions;

  /// Whether this comment has been edited
  final bool isEdited;

  /// Whether this comment has been soft-deleted
  final bool isDeleted;

  /// Additional metadata for extensibility
  final Map<String, dynamic>? metadata;

  /// Whether this comment is a reply to another comment
  bool get isReply => parentCommentId != null;

  /// Parse createdAt timestamp to DateTime
  DateTime get createdAtDateTime => DateTime.parse(createdAt);

  /// Parse updatedAt timestamp to DateTime if available
  DateTime? get updatedAtDateTime =>
      updatedAt != null ? DateTime.parse(updatedAt!) : null;

  /// Get total count of reactions for a specific emoji
  int getReactionCount(String emoji) {
    return reactions[emoji]?.length ?? 0;
  }

  /// Check if a specific user has reacted with a specific emoji
  bool userHasReacted(String userEmail, String emoji) {
    return reactions[emoji]?.contains(userEmail) ?? false;
  }

  /// Get total count of all reactions
  int get totalReactionCount {
    return reactions.values.fold<int>(
      0,
      (sum, userList) => sum + userList.length,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'targetType': targetType,
      'targetId': targetId,
      'authorUid': authorUid,
      'authorName': authorName,
      'content': content,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      'mentions': mentions,
      'reactions': reactions,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create a copy with optional new values
  Comment copyWith({
    String? id,
    String? organizationId,
    String? targetType,
    String? targetId,
    String? authorUid,
    String? authorName,
    String? content,
    String? createdAt,
    String? updatedAt,
    String? parentCommentId,
    List<String>? mentions,
    Map<String, List<String>>? reactions,
    bool? isEdited,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return Comment(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      mentions: mentions ?? this.mentions,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        targetType,
        targetId,
        authorUid,
        authorName,
        content,
        createdAt,
        updatedAt,
        parentCommentId,
        mentions,
        reactions,
        isEdited,
        isDeleted,
        metadata,
      ];
}
