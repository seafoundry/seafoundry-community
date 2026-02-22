// @tier: community
import 'package:equatable/equatable.dart';

/// Denormalized author information for efficient display.
///
/// Contains point-in-time snapshots of user and organization data at the time
/// the post was created. This preserves the historical record even if the
/// user or organization is later renamed or deleted.
class PostAuthor extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String organizationId;

  /// Point-in-time snapshot of organization name when post was created.
  /// Intentionally denormalized for historical audit purposes.
  final String? organizationNameSnapshot;

  const PostAuthor({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.organizationId,
    this.organizationNameSnapshot,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
      organizationId: json['organizationId'] ?? '',
      // Support both old 'organizationName' and new 'organizationNameSnapshot' keys
      organizationNameSnapshot: json['organizationNameSnapshot'] ?? json['organizationName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'organizationId': organizationId,
      if (organizationNameSnapshot != null) 'organizationNameSnapshot': organizationNameSnapshot,
    };
  }

  PostAuthor copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? organizationId,
    String? organizationNameSnapshot,
  }) {
    return PostAuthor(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      organizationId: organizationId ?? this.organizationId,
      organizationNameSnapshot: organizationNameSnapshot ?? this.organizationNameSnapshot,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        avatarUrl,
        organizationId,
        organizationNameSnapshot,
      ];

  @override
  bool get stringify => true;
}
