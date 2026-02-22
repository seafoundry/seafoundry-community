// @tier: community

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/channels/channel.dart';
import 'package:seafoundry_app/models/channels/channel_member.dart';
import 'package:seafoundry_app/models/types/channel_type.dart';
import 'package:seafoundry_app/models/types/channel_visibility.dart';
import 'package:seafoundry_app/repositories/channels/base_channel_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Repository for organization-scoped channels.
///
/// Manages Firestore storage for channels within an organization.
/// Collection path: organizations/{orgId}/channels
///
/// Extends [BaseChannelRepository] for shared message operations and adds
/// organization-specific features like member management.
class OrganizationChannelRepository extends BaseChannelRepository {
  OrganizationChannelRepository({
    required this.organizationId,
    required super.userId,
    FirebaseFirestore? firestore,
    super.logger,
  }) : super(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  final String organizationId;

  // ========================================
  // Collection References (implement abstract methods)
  // ========================================

  @override
  DocumentReference<Map<String, dynamic>> channelRef(String channelId) {
    return FirestoreCollectionResolver.instance
        .subcollection(firestore, 'organizations', organizationId, 'channels')
        .doc(channelId);
  }

  @override
  CollectionReference<Map<String, dynamic>> messagesRef(String channelId) {
    return channelRef(channelId).collection('messages');
  }

  @override
  CollectionReference<Map<String, dynamic>> membersRef(String channelId) {
    return channelRef(channelId).collection('members');
  }

  /// Reference to the channels collection.
  CollectionReference<Map<String, dynamic>> get _channelsCollection {
    return FirestoreCollectionResolver.instance.subcollection(
      firestore,
      'organizations',
      organizationId,
      'channels',
    );
  }

  // ========================================
  // Channel CRUD Operations
  // ========================================

  /// Create a new organization channel.
  ///
  /// Parameters:
  /// - [name]: Display name of the channel
  /// - [description]: Optional description of the channel
  /// - [iconEmoji]: Optional emoji icon for the channel
  /// - [isPublic]: Whether the channel is visible to all org members (default: true)
  /// - [siteId]: Optional site ID for site-scoped channels
  /// - [initialMemberIds]: Optional list of initial member user IDs
  ///
  /// Returns the created [Channel]
  Future<Channel> createChannel({
    required String name,
    String? description,
    String? iconEmoji,
    bool isPublic = true,
    String? siteId,
    List<String>? initialMemberIds,
  }) async {
    try {
      final channelId = firestore.collection('_').doc().id;
      final now = DateTime.now().toIso8601String();
      final resolvedVisibility = ChannelVisibility.inviteOnly;

      // Ensure creator is included in member list
      final memberIds = <String>{userId};
      if (initialMemberIds != null) {
        memberIds.addAll(initialMemberIds);
      }

      final channel = Channel(
        id: channelId,
        name: name,
        channelType: ChannelType.organization,
        visibility: resolvedVisibility,
        organizationId: organizationId,
        description: description,
        iconEmoji: iconEmoji,
        siteId: siteId,
        memberIds: memberIds.toList(),
        memberCount: memberIds.length,
        adminIds: [userId],
        createdAt: now,
        createdById: userId,
        lastMessageAt: now, // Initialize for proper sorting
      );

      // Create the channel first so rules can read its data when adding members.
      await _channelsCollection.doc(channelId).set(channel.toJson());

      // Add members in a follow-up batch to satisfy rules that read the channel doc.
      final membersBatch = firestore.batch();

      // Add creator as owner
      final ownerMember = ChannelMember(
        userId: userId,
        channelId: channelId,
        role: ChannelMemberRole.owner,
        joinedAt: now,
      );
      membersBatch.set(
        membersRef(channelId).doc(userId),
        ownerMember.toJson(),
      );

      // Add initial members
      for (final memberId in initialMemberIds ?? []) {
        if (memberId != userId) {
          final member = ChannelMember(
            userId: memberId,
            channelId: channelId,
            role: ChannelMemberRole.member,
            joinedAt: now,
          );
          membersBatch.set(
            membersRef(channelId).doc(memberId),
            member.toJson(),
          );
        }
      }

      await membersBatch.commit();

      logger.info('Created organization channel: $channelId');
      return channel;
    } catch (error, stackTrace) {
      logger.error('Error creating organization channel', error, stackTrace);
      rethrow;
    }
  }

  /// Stream all channels in the organization.
  ///
  /// Returns a stream of non-archived channels ordered by
  /// last message time (newest first).
  Stream<List<Channel>> streamChannels() {
    try {
      return Rx.combineLatest2<List<Channel>, List<Channel>, List<Channel>>(
        streamPublicChannels(),
        streamUserChannels(),
        (publicChannels, memberChannels) =>
            _mergeChannels(publicChannels, memberChannels),
      );
    } catch (error, stackTrace) {
      logger.error('Error streaming organization channels', error, stackTrace);
      rethrow;
    }
  }

  /// Stream all public channels in the organization.
  ///
  /// Returns a stream of public, non-archived channels ordered by
  /// last message time (newest first).
  Stream<List<Channel>> streamPublicChannels() {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _channelsCollection
          .where('visibility', isEqualTo: ChannelVisibility.public_.value)
          .where('isArchived', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final channels = <Channel>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            channels.add(Channel.fromJson(data));
          } catch (error, stackTrace) {
            logger.error(
              'Failed to parse organization channel ${doc.id}',
              error,
              stackTrace,
            );
          }
        }
        // Sort by lastMessageAt descending (most recent first)
        channels.sort((a, b) {
          final dateA = DateTime.tryParse(a.lastMessageAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b.lastMessageAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        return channels;
      });
    } catch (error, stackTrace) {
      logger.error('Error streaming public organization channels', error, stackTrace);
      rethrow;
    }
  }

  /// Stream channels that the current user is a member of.
  ///
  /// Returns a stream of channels where the user is in the memberIds array,
  /// ordered by last message time (newest first).
  Stream<List<Channel>> streamUserChannels() {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _channelsCollection
          .where('memberIds', arrayContains: userId)
          .where('isArchived', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final channels = <Channel>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            channels.add(Channel.fromJson(data));
          } catch (error, stackTrace) {
            logger.error(
              'Failed to parse organization channel ${doc.id}',
              error,
              stackTrace,
            );
          }
        }
        // Sort by lastMessageAt descending (most recent first)
        channels.sort((a, b) {
          final dateA = DateTime.tryParse(a.lastMessageAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b.lastMessageAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        return channels;
      });
    } catch (error, stackTrace) {
      logger.error('Error streaming user channels', error, stackTrace);
      rethrow;
    }
  }

  /// Fetch the active site channel for a given site ID.
  Future<Channel?> getChannelForSite(String siteId) async {
    try {
      final snapshot = await _channelsCollection
          .where('siteId', isEqualTo: siteId)
          .where('isArchived', isEqualTo: false)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return Channel.fromJson(snapshot.docs.first.data());
    } catch (error, stackTrace) {
      logger.error('Error fetching site channel for $siteId', error, stackTrace);
      return null;
    }
  }

  /// Archive the site channel for a given site ID (if it exists).
  Future<void> archiveChannelForSite(String siteId) async {
    final channel = await getChannelForSite(siteId);
    if (channel == null) return;
    await archiveChannel(channel.id);
  }

  /// Get all channels in the organization (one-time fetch).
  ///
  /// Returns a list of non-archived channels ordered by
  /// last message time (newest first).
  ///
  /// Note: orderBy requires composite indexes for both queries.
  /// If indexes are not deployed, these queries will fail with 400 error.
  Future<List<Channel>> getChannels() async {
    try {
      final publicSnapshot = await _channelsCollection
          .where('visibility', isEqualTo: ChannelVisibility.public_.value)
          .where('isArchived', isEqualTo: false)
          .orderBy('lastMessageAt', descending: true)
          .get();
      final memberSnapshot = await _channelsCollection
          .where('memberIds', arrayContains: userId)
          .where('isArchived', isEqualTo: false)
          .orderBy('lastMessageAt', descending: true)
          .get();

      final publicChannels = publicSnapshot.docs
          .map((doc) => Channel.fromJson(doc.data()))
          .toList();
      final memberChannels = memberSnapshot.docs
          .map((doc) => Channel.fromJson(doc.data()))
          .toList();

      return _mergeChannels(publicChannels, memberChannels);
    } catch (error, stackTrace) {
      logger.error('Error fetching organization channels', error, stackTrace);
      rethrow;
    }
  }

  List<Channel> _mergeChannels(
    List<Channel> publicChannels,
    List<Channel> memberChannels,
  ) {
    final channelsById = <String, Channel>{};
    for (final channel in [...publicChannels, ...memberChannels]) {
      channelsById[channel.id] = channel;
    }
    final merged = channelsById.values.toList();
    merged.sort((a, b) {
      final aTime = _sortTimestamp(a);
      final bTime = _sortTimestamp(b);
      return bTime.compareTo(aTime);
    });
    return merged;
  }

  DateTime _sortTimestamp(Channel channel) {
    final lastMessageAt = DateTime.tryParse(channel.lastMessageAt ?? '');
    if (lastMessageAt != null) return lastMessageAt;
    final createdAt = DateTime.tryParse(channel.createdAt ?? '');
    return createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ========================================
  // Member Management Operations
  // ========================================

  /// Add a member to a channel.
  ///
  /// Parameters:
  /// - [channelId]: ID of the channel
  /// - [memberId]: User ID of the member to add
  /// - [role]: Optional role for the member (default: member)
  Future<void> addMember({
    required String channelId,
    required String memberId,
    ChannelMemberRole role = ChannelMemberRole.member,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Add user to channel's memberIds
      await channelRef(channelId).update({
        'memberIds': FieldValue.arrayUnion([memberId]),
        'memberCount': FieldValue.increment(1),
      });

      // Create member document
      final member = ChannelMember(
        userId: memberId,
        channelId: channelId,
        role: role,
        joinedAt: now,
      );
      await membersRef(channelId).doc(memberId).set(member.toJson());

      logger.info('Added member $memberId to channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error adding member to channel', error, stackTrace);
      rethrow;
    }
  }

  /// Remove a member from a channel.
  ///
  /// Parameters:
  /// - [channelId]: ID of the channel
  /// - [memberId]: User ID of the member to remove
  ///
  /// Throws [StateError] if trying to remove the channel owner.
  Future<void> removeMember({
    required String channelId,
    required String memberId,
  }) async {
    try {
      // Check if the member is an owner (owners cannot be removed)
      final memberDoc = await membersRef(channelId).doc(memberId).get();
      if (memberDoc.exists) {
        final memberData = memberDoc.data();
        if (memberData?['role'] == 'owner') {
          throw StateError(
            'Cannot remove channel owner. Transfer ownership first.',
          );
        }
      }

      // Remove user from channel's memberIds
      await channelRef(channelId).update({
        'memberIds': FieldValue.arrayRemove([memberId]),
        'memberCount': FieldValue.increment(-1),
      });

      // Delete member document
      await membersRef(channelId).doc(memberId).delete();

      logger.info('Removed member $memberId from channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error removing member from channel', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Channel Management Operations
  // ========================================

  /// Update channel details.
  ///
  /// Only updates non-null parameters.
  Future<void> updateChannel({
    required String channelId,
    String? name,
    String? description,
    String? iconEmoji,
    bool? isPublic,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (iconEmoji != null) updates['iconEmoji'] = iconEmoji;
      if (isPublic != null) {
        updates['visibility'] = ChannelVisibility.inviteOnly.value;
      }

      if (updates.isEmpty) {
        logger.warning('No updates provided for channel $channelId');
        return;
      }

      updates['updatedAt'] = DateTime.now().toIso8601String();
      updates['updatedById'] = userId;

      await channelRef(channelId).update(updates);
      logger.info('Updated organization channel: $channelId');
    } catch (error, stackTrace) {
      logger.error('Error updating organization channel', error, stackTrace);
      rethrow;
    }
  }

  /// Archive a channel (soft delete).
  ///
  /// Marks the channel as archived. Archived channels are hidden from
  /// channel lists but can be restored.
  Future<void> archiveChannel(String channelId) async {
    try {
      await channelRef(channelId).update({
        'isArchived': true,
        'archivedAt': DateTime.now().toIso8601String(),
        'archivedById': userId,
      });

      logger.info('Archived organization channel: $channelId');
    } catch (error, stackTrace) {
      logger.error('Error archiving organization channel', error, stackTrace);
      rethrow;
    }
  }
}
