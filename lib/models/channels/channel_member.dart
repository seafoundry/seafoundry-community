// @tier: community

import 'package:equatable/equatable.dart';

/// Represents a member's relationship to a channel in the SeaFoundry system.
///
/// This model tracks membership metadata including role, notifications,
/// and read status for each user in a channel.
class ChannelMember extends Equatable {
  const ChannelMember({
    required this.userId,
    required this.channelId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.notificationPreference = ChannelNotificationPreference.all,
    this.isMuted = false,
    this.isStarred = false,
    this.lastReadAt,
  });

  /// Create a ChannelMember from JSON.
  factory ChannelMember.fromJson(Map<String, dynamic> json) {
    return ChannelMember(
      userId: json['userId'] as String,
      channelId: json['channelId'] as String,
      role: ChannelMemberRole.fromString(json['role'] as String? ?? 'member'),
      joinedAt: json['joinedAt'] as String,
      displayName: json['displayName'] as String?,
      notificationPreference: ChannelNotificationPreference.fromString(
        (json['notificationPreference'] ?? json['notificationLevel'])
                as String? ??
            'all',
      ),
      isMuted: json['isMuted'] as bool? ?? false,
      isStarred: json['isStarred'] as bool? ?? false,
      lastReadAt: json['lastReadAt'] as String?,
    );
  }

  /// User ID of the member.
  final String userId;

  /// Channel ID this membership belongs to.
  final String channelId;

  /// Role of the member in this channel.
  final ChannelMemberRole role;

  /// ISO 8601 timestamp when the user joined the channel.
  final String joinedAt;

  /// Display name of the member (optional, can be fetched separately).
  final String? displayName;

  /// Notification preference for this channel.
  final ChannelNotificationPreference notificationPreference;

  /// Whether the member has muted this channel.
  final bool isMuted;

  /// Whether the member has starred/favorited this channel.
  final bool isStarred;

  /// ISO 8601 timestamp of when the member last read messages.
  final String? lastReadAt;

  /// Whether this member is an admin of the channel.
  bool get isAdmin => role == ChannelMemberRole.admin;

  /// Whether this member is the owner of the channel.
  bool get isOwner => role == ChannelMemberRole.owner;

  /// Whether this member can manage the channel (admin or owner).
  bool get canManageChannel =>
      role == ChannelMemberRole.admin || role == ChannelMemberRole.owner;

  /// Parse joinedAt timestamp to DateTime.
  DateTime get joinedAtDateTime => DateTime.parse(joinedAt);

  /// Parse lastReadAt timestamp to DateTime.
  DateTime? get lastReadAtDateTime =>
      lastReadAt != null ? DateTime.parse(lastReadAt!) : null;

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'channelId': channelId,
      'role': role.value,
      'joinedAt': joinedAt,
      if (displayName != null) 'displayName': displayName,
      'notificationPreference': notificationPreference.value,
      'isMuted': isMuted,
      'isStarred': isStarred,
      if (lastReadAt != null) 'lastReadAt': lastReadAt,
    };
  }

  /// Create a copy with optional new values.
  ChannelMember copyWith({
    String? userId,
    String? channelId,
    ChannelMemberRole? role,
    String? joinedAt,
    String? displayName,
    ChannelNotificationPreference? notificationPreference,
    bool? isMuted,
    bool? isStarred,
    String? lastReadAt,
  }) {
    return ChannelMember(
      userId: userId ?? this.userId,
      channelId: channelId ?? this.channelId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      displayName: displayName ?? this.displayName,
      notificationPreference:
          notificationPreference ?? this.notificationPreference,
      isMuted: isMuted ?? this.isMuted,
      isStarred: isStarred ?? this.isStarred,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        channelId,
        role,
        joinedAt,
        displayName,
        notificationPreference,
        isMuted,
        isStarred,
        lastReadAt,
      ];
}

/// Role of a member within a channel.
enum ChannelMemberRole {
  /// Regular member with basic permissions.
  member('member'),

  /// Admin with management permissions.
  admin('admin'),

  /// Owner with full control over the channel.
  owner('owner');

  const ChannelMemberRole(this.value);

  final String value;

  static ChannelMemberRole fromString(String value) {
    return ChannelMemberRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ChannelMemberRole.member,
    );
  }
}

/// Notification preference for a channel.
enum ChannelNotificationPreference {
  /// Receive all notifications.
  all('all'),

  /// Only receive notifications for mentions.
  mentionsOnly('mentions_only'),

  /// No notifications.
  none('none');

  const ChannelNotificationPreference(this.value);

  final String value;

  static ChannelNotificationPreference fromString(String value) {
    return ChannelNotificationPreference.values.firstWhere(
      (pref) => pref.value == value,
      orElse: () => ChannelNotificationPreference.all,
    );
  }
}
