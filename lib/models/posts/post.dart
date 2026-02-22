// @tier: community
import 'package:seafoundry_app/models/posts/post_author.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/post_scope.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// A social post/announcement - can be scoped to organization or community
class Post extends Record {
  static const Object _unset = Object();

  final String? title;
  final String content;
  final PostScope scope;
  final PostAuthor author;
  final bool isPinned;
  final String? pinnedAt;
  final bool isEdited;
  final int commentCount;

  /// Map of emoji reactions to lists of user IDs who reacted.
  /// Example: {'👍': ['user1', 'user2'], '❤️': ['user3']}
  final Map<String, List<String>> reactions;
  final Map<String, dynamic>? extraMetadata;

  const Post({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    this.title,
    required this.content,
    required this.scope,
    required this.author,
    this.isPinned = false,
    this.pinnedAt,
    this.isEdited = false,
    this.commentCount = 0,
    this.reactions = const {},
    this.extraMetadata,
    super.metadata,
  });

  Post.fromJson(super.json)
      : title = json['title'],
        content = json['content'] ?? '',
        scope = PostScopeX.tryParse(json['scope']) ?? PostScope.organization,
        author = PostAuthor.fromJson(
          json['author'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(json['author'])
              : {},
        ),
        isPinned = json['isPinned'] ?? false,
        pinnedAt = json['pinnedAt'],
        isEdited = json['isEdited'] ?? false,
        commentCount = safeInt(json['commentCount']) ?? 0,
        reactions = (json['reactions'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, List<String>.from(value as List)),
            ) ??
            const {},
        extraMetadata = json['extraMetadata'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['extraMetadata'])
            : null,
        super.fromJson();

  Post.partial({
    super.json,
    super.id,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.metadata,
    String? title,
    String? content,
    PostScope? scope,
    PostAuthor? author,
    bool? isPinned,
    String? pinnedAt,
    bool? isEdited,
    int? commentCount,
    Map<String, List<String>>? reactions,
    Map<String, dynamic>? extraMetadata,
  })  : title = title ?? json?['title'],
        content = content ?? json?['content'] ?? '',
        scope = scope ??
            PostScopeX.tryParse(json?['scope']) ??
            PostScope.organization,
        author = author ??
            PostAuthor.fromJson(
              json?['author'] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(json!['author'])
                  : {},
            ),
        isPinned = isPinned ?? json?['isPinned'] ?? false,
        pinnedAt = pinnedAt ?? json?['pinnedAt'],
        isEdited = isEdited ?? json?['isEdited'] ?? false,
        commentCount =
            commentCount ?? safeInt(json?['commentCount']) ?? 0,
        reactions = reactions ??
            (json?['reactions'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, List<String>.from(value as List)),
            ) ??
            const {},
        extraMetadata = extraMetadata ??
            (json?['extraMetadata'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(json!['extraMetadata'])
                : null),
        super.partial();

  @override
  ModelType get modelType => ModelType.post;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      'content': content,
      'scope': scope.name,
      'author': author.toJson(),
      'isPinned': isPinned,
      if (pinnedAt != null) 'pinnedAt': pinnedAt,
      'isEdited': isEdited,
      'commentCount': commentCount,
      'reactions': reactions,
      if (extraMetadata != null) 'extraMetadata': extraMetadata,
      ...super.toJson(),
    };
  }

  @override
  Post copyWith({
    Object? id = _unset,
    Object? createdAt = _unset,
    Object? createdById = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? organizationId = _unset,
    Object? title = _unset,
    Object? content = _unset,
    Object? scope = _unset,
    Object? author = _unset,
    Object? isPinned = _unset,
    Object? pinnedAt = _unset,
    Object? isEdited = _unset,
    Object? commentCount = _unset,
    Object? reactions = _unset,
    Object? extraMetadata = _unset,
    Map<String, dynamic>? metadata,
  }) {
    return Post(
      id: identical(id, _unset) ? this.id : id as String,
      createdAt:
          identical(createdAt, _unset) ? this.createdAt : createdAt as String,
      createdById: identical(createdById, _unset)
          ? this.createdById
          : createdById as String,
      updatedAt:
          identical(updatedAt, _unset) ? this.updatedAt : updatedAt as String,
      updatedById: identical(updatedById, _unset)
          ? this.updatedById
          : updatedById as String,
      organizationId: identical(organizationId, _unset)
          ? this.organizationId
          : organizationId as String,
      title: identical(title, _unset) ? this.title : title as String?,
      content: identical(content, _unset) ? this.content : content as String,
      scope: identical(scope, _unset) ? this.scope : scope as PostScope,
      author: identical(author, _unset) ? this.author : author as PostAuthor,
      isPinned: identical(isPinned, _unset) ? this.isPinned : isPinned as bool,
      pinnedAt:
          identical(pinnedAt, _unset) ? this.pinnedAt : pinnedAt as String?,
      isEdited: identical(isEdited, _unset) ? this.isEdited : isEdited as bool,
      commentCount: identical(commentCount, _unset)
          ? this.commentCount
          : commentCount as int,
      reactions: identical(reactions, _unset)
          ? this.reactions
          : reactions as Map<String, List<String>>,
      extraMetadata: identical(extraMetadata, _unset)
          ? this.extraMetadata
          : extraMetadata as Map<String, dynamic>?,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    return super.validate() && content.trim().isNotEmpty && author.id.isNotEmpty;
  }

  @override
  List<Object?> get props => super.props +
      [
        title,
        content,
        scope,
        author,
        isPinned,
        pinnedAt,
        isEdited,
        commentCount,
        reactions,
        extraMetadata,
      ];

  bool get hasTitle => title != null && title!.isNotEmpty;
  bool get isOrganizationScoped => scope == PostScope.organization;
  bool get isCommunityScoped => scope == PostScope.community;

  /// Whether this post has any reactions
  bool get hasReactions => reactions.isNotEmpty;

  /// Get total count of reactions for a specific emoji
  int getReactionCount(String emoji) {
    return reactions[emoji]?.length ?? 0;
  }

  /// Check if a specific user has reacted with a specific emoji
  bool userHasReacted(String userId, String emoji) {
    return reactions[emoji]?.contains(userId) ?? false;
  }

  /// Get total count of all reactions
  int get totalReactionCount {
    return reactions.values.fold<int>(
      0,
      (sum, userList) => sum + userList.length,
    );
  }

  /// Mark post as pinned
  Post pin() {
    return copyWith(
      isPinned: true,
      pinnedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Unpin post
  Post unpin() {
    return copyWith(isPinned: false, pinnedAt: null);
  }

  /// Mark post as edited
  Post markEdited() {
    return copyWith(isEdited: true);
  }

  /// Update comment count
  Post updateCommentCount(int count) {
    return copyWith(commentCount: count);
  }

  /// Increment comment count
  Post incrementCommentCount() {
    return copyWith(commentCount: commentCount + 1);
  }

  /// Decrement comment count
  Post decrementCommentCount() {
    return copyWith(commentCount: commentCount > 0 ? commentCount - 1 : 0);
  }

  @override
  String toString() {
    return 'Post(${title ?? 'Untitled'}, ${scope.displayName}, $createdAt)';
  }
}
