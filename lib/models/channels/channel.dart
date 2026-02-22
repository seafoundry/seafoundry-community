// @tier: community

import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/channel_type.dart';
import 'package:seafoundry_app/models/types/channel_visibility.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Represents a channel in the SeaFoundry system.
///
/// Channels can be community-wide, organization-specific, or direct messages.
/// They support visibility settings, member management, and message tracking.
class Channel extends Equatable {
  const Channel({
    required this.id,
    required this.name,
    required this.channelType,
    required this.visibility,
    this.description,
    this.iconEmoji,
    this.siteId,
    this.organizationId,
    this.memberIds = const [],
    this.memberCount = 0,
    this.adminIds = const [],
    this.createdAt,
    this.createdById,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.isArchived = false,
  });

  /// Create a Channel from JSON.
  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      channelType: ChannelType.fromString(json['channelType'] as String? ?? 'community'),
      visibility: ChannelVisibility.fromString(json['visibility'] as String? ?? 'public'),
      description: json['description'] as String?,
      iconEmoji: json['iconEmoji'] as String?,
      siteId: json['siteId'] as String?,
      organizationId: json['organizationId'] as String?,
      memberIds: List<String>.from(json['memberIds'] ?? []),
      memberCount: safeInt(json['memberCount']) ?? 0,
      adminIds: List<String>.from(json['adminIds'] ?? []),
      createdAt: json['createdAt'] as String?,
      createdById: json['createdById'] as String?,
      lastMessageAt: json['lastMessageAt'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  /// Unique identifier for the channel.
  final String id;

  /// Display name of the channel.
  final String name;

  /// Type of channel (community, organization, directMessage).
  final ChannelType channelType;

  /// Visibility/access level of the channel.
  final ChannelVisibility visibility;

  /// Optional description of the channel.
  final String? description;

  /// Emoji icon for the channel (e.g., for display in channel list).
  final String? iconEmoji;

  /// Optional site ID for site-scoped organization channels.
  final String? siteId;

  /// Organization ID for organization-scoped channels (null for community channels).
  final String? organizationId;

  /// List of member user IDs in this channel.
  final List<String> memberIds;

  /// Total count of members in this channel.
  final int memberCount;

  /// List of admin user IDs who can manage this channel.
  final List<String> adminIds;

  /// ISO 8601 timestamp when the channel was created.
  final String? createdAt;

  /// User ID who created the channel.
  final String? createdById;

  /// ISO 8601 timestamp of the last message sent.
  final String? lastMessageAt;

  /// Preview text of the last message.
  final String? lastMessagePreview;

  /// User ID of the last message sender.
  final String? lastMessageSenderId;

  /// Whether this channel has been archived.
  final bool isArchived;

  /// Whether this is a direct message channel.
  bool get isDirectMessage => channelType == ChannelType.directMessage;

  /// Whether this is a community channel.
  bool get isCommunityChannel => channelType == ChannelType.community;

  /// Whether this is an organization channel.
  bool get isOrganizationChannel => channelType == ChannelType.organization;

  /// Whether this channel is public.
  bool get isPublic => visibility == ChannelVisibility.public_;

  /// Whether this channel is invite-only.
  bool get isInviteOnly => visibility == ChannelVisibility.inviteOnly;

  /// Whether this channel is tied to a site.
  bool get isSiteChannel => siteId != null && siteId!.isNotEmpty;

  /// Parse createdAt timestamp to DateTime.
  DateTime? get createdAtDateTime =>
      createdAt != null ? DateTime.parse(createdAt!) : null;

  /// Parse lastMessageAt timestamp to DateTime.
  DateTime? get lastMessageAtDateTime =>
      lastMessageAt != null ? DateTime.parse(lastMessageAt!) : null;

  /// Check if a user is a member of this channel.
  bool isMember(String userId) => memberIds.contains(userId);

  /// Check if a user is an admin of this channel.
  bool isAdmin(String userId) => adminIds.contains(userId);

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'channelType': channelType.value,
      'visibility': visibility.value,
      if (description != null) 'description': description,
      if (iconEmoji != null) 'iconEmoji': iconEmoji,
      if (siteId != null) 'siteId': siteId,
      if (organizationId != null) 'organizationId': organizationId,
      'memberIds': memberIds,
      'memberCount': memberCount,
      'adminIds': adminIds,
      if (createdAt != null) 'createdAt': createdAt,
      if (createdById != null) 'createdById': createdById,
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt,
      if (lastMessagePreview != null) 'lastMessagePreview': lastMessagePreview,
      if (lastMessageSenderId != null) 'lastMessageSenderId': lastMessageSenderId,
      'isArchived': isArchived,
    };
  }

  /// Create a copy with optional new values.
  Channel copyWith({
    String? id,
    String? name,
    ChannelType? channelType,
    ChannelVisibility? visibility,
    String? description,
    String? iconEmoji,
    String? siteId,
    String? organizationId,
    List<String>? memberIds,
    int? memberCount,
    List<String>? adminIds,
    String? createdAt,
    String? createdById,
    String? lastMessageAt,
    String? lastMessagePreview,
    String? lastMessageSenderId,
    bool? isArchived,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      channelType: channelType ?? this.channelType,
      visibility: visibility ?? this.visibility,
      description: description ?? this.description,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      siteId: siteId ?? this.siteId,
      organizationId: organizationId ?? this.organizationId,
      memberIds: memberIds ?? this.memberIds,
      memberCount: memberCount ?? this.memberCount,
      adminIds: adminIds ?? this.adminIds,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        channelType,
        visibility,
        description,
        iconEmoji,
        siteId,
        organizationId,
        memberIds,
        memberCount,
        adminIds,
        createdAt,
        createdById,
        lastMessageAt,
        lastMessagePreview,
        lastMessageSenderId,
        isArchived,
      ];
}
