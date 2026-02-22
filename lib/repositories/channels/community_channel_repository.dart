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

/// Repository for community-wide channels (cross-organization).
///
/// Manages Firestore storage for channels visible across all organizations.
/// Collection path: community_channels (top-level)
///
/// Extends [BaseChannelRepository] for shared message operations and adds
/// community-specific features like public channel discovery.
class CommunityChannelRepository extends BaseChannelRepository {
  CommunityChannelRepository({
    required super.userId,
    FirebaseFirestore? firestore,
    super.logger,
  }) : super(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  /// Collection name for community channels.
  static const String collectionName = 'community_channels';

  // ========================================
  // Collection References (implement abstract methods)
  // ========================================

  @override
  DocumentReference<Map<String, dynamic>> channelRef(String channelId) {
    return FirestoreCollectionResolver.instance
        .collection(firestore, collectionName)
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
    return FirestoreCollectionResolver.instance.collection(
      firestore,
      collectionName,
    );
  }

  // ========================================
  // Channel CRUD Operations
  // ========================================

  /// Create a new community channel.
  ///
  /// Parameters:
  /// - [name]: Display name of the channel
  /// - [description]: Optional description of the channel
  /// - [iconEmoji]: Optional emoji icon for the channel
  /// - [visibility]: Visibility of the channel (default: public)
  /// - [initialMemberIds]: Optional list of initial member user IDs
  ///
  /// Returns the created [Channel]
  Future<Channel> createChannel({
    required String name,
    String? description,
    String? iconEmoji,
    ChannelVisibility visibility = ChannelVisibility.inviteOnly,
    List<String>? initialMemberIds,
  }) async {
    try {
      final channelId = firestore.collection('_').doc().id;
      final now = DateTime.now().toIso8601String();
      final resolvedVisibility = visibility == ChannelVisibility.public_
          ? ChannelVisibility.inviteOnly
          : visibility;

      final memberIds = <String>{userId};
      if (initialMemberIds != null) {
        memberIds.addAll(initialMemberIds);
      }

      final channel = Channel(
        id: channelId,
        name: name,
        channelType: ChannelType.community,
        visibility: resolvedVisibility,
        description: description,
        iconEmoji: iconEmoji,
        memberIds: memberIds.toList(),
        memberCount: memberIds.length,
        adminIds: [userId],
        createdAt: now,
        createdById: userId,
        lastMessageAt: now, // Initialize for proper sorting
      );

      // Create channel document
      await _channelsCollection.doc(channelId).set(channel.toJson());

      // Add members in a follow-up batch to satisfy rules that read the channel doc.
      final batch = firestore.batch();

      final ownerMember = ChannelMember(
        userId: userId,
        channelId: channelId,
        role: ChannelMemberRole.owner,
        joinedAt: now,
      );
      batch.set(membersRef(channelId).doc(userId), ownerMember.toJson());

      for (final memberId in memberIds) {
        if (memberId == userId) continue;
        final member = ChannelMember(
          userId: memberId,
          channelId: channelId,
          role: ChannelMemberRole.member,
          joinedAt: now,
        );
        batch.set(membersRef(channelId).doc(memberId), member.toJson());
      }

      await batch.commit();

      logger.info('Created community channel: $channelId');
      return channel;
    } catch (error, stackTrace) {
      logger.error('Error creating community channel', error, stackTrace);
      rethrow;
    }
  }

  /// Stream all community channels (public + member channels).
  Stream<List<Channel>> streamChannels() {
    try {
      return Rx.combineLatest2<List<Channel>, List<Channel>, List<Channel>>(
        streamPublicChannels(),
        streamUserChannels(),
        (publicChannels, memberChannels) =>
            _mergeChannels(publicChannels, memberChannels),
      );
    } catch (error, stackTrace) {
      logger.error('Error streaming community channels', error, stackTrace);
      rethrow;
    }
  }

  /// Stream all public community channels.
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
              'Failed to parse community channel ${doc.id}',
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
      logger.error('Error streaming public community channels', error, stackTrace);
      rethrow;
    }
  }

  /// Stream channels that the current user is a member of (including private).
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
              'Failed to parse community channel ${doc.id}',
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
      logger.error('Error streaming member community channels', error, stackTrace);
      rethrow;
    }
  }

  /// Get all community channels (public + member channels).
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
      logger.error('Error fetching community channels', error, stackTrace);
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
  // Membership Operations
  // ========================================

  /// Join a community channel.
  ///
  /// Uses a Firestore transaction to atomically:
  /// 1. Check if user is already a member (no-op if so)
  /// 2. Add userId to memberIds and set memberCount to match
  /// 3. Create the member subcollection document
  Future<void> joinChannel(String channelId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final channelDocRef = channelRef(channelId);
      final memberDocRef = membersRef(channelId).doc(userId);

      await firestore.runTransaction((transaction) async {
        final channelSnapshot = await transaction.get(channelDocRef);
        if (!channelSnapshot.exists) {
          throw StateError('Channel $channelId does not exist.');
        }

        final data = channelSnapshot.data()!;
        final memberIds = List<String>.from(data['memberIds'] ?? []);

        // Already a member -- nothing to do.
        if (memberIds.contains(userId)) return;

        memberIds.add(userId);

        transaction.update(channelDocRef, {
          'memberIds': memberIds,
          'memberCount': memberIds.length,
        });

        final member = ChannelMember(
          userId: userId,
          channelId: channelId,
          role: ChannelMemberRole.member,
          joinedAt: now,
        );
        transaction.set(memberDocRef, member.toJson());
      });

      logger.info('User $userId joined community channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error joining community channel', error, stackTrace);
      rethrow;
    }
  }

  /// Add members to a community channel (admin-only).
  Future<void> addMembers({
    required String channelId,
    required List<String> memberIds,
  }) async {
    if (memberIds.isEmpty) return;
    try {
      final now = DateTime.now().toIso8601String();
      final channelDocRef = channelRef(channelId);

      await firestore.runTransaction((transaction) async {
        final channelSnapshot = await transaction.get(channelDocRef);
        if (!channelSnapshot.exists) {
          throw StateError('Channel $channelId does not exist.');
        }

        final data = channelSnapshot.data()!;
        final existingIds = List<String>.from(data['memberIds'] ?? []);
        final updatedIds = <String>{...existingIds};
        final newMembers = <String>[];

        for (final memberId in memberIds) {
          if (!updatedIds.contains(memberId)) {
            updatedIds.add(memberId);
            newMembers.add(memberId);
          }
        }

        if (newMembers.isEmpty) return;

        transaction.update(channelDocRef, {
          'memberIds': updatedIds.toList(),
          'memberCount': updatedIds.length,
        });

        for (final memberId in newMembers) {
          final member = ChannelMember(
            userId: memberId,
            channelId: channelId,
            role: ChannelMemberRole.member,
            joinedAt: now,
          );
          transaction.set(membersRef(channelId).doc(memberId), member.toJson());
        }
      });

      logger.info('Added ${memberIds.length} members to community channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error adding members to community channel', error, stackTrace);
      rethrow;
    }
  }

  /// Remove members from a community channel (admin-only).
  Future<void> removeMembers({
    required String channelId,
    required List<String> memberIds,
  }) async {
    if (memberIds.isEmpty) return;
    try {
      final channelDocRef = channelRef(channelId);

      await firestore.runTransaction((transaction) async {
        final channelSnapshot = await transaction.get(channelDocRef);
        if (!channelSnapshot.exists) {
          throw StateError('Channel $channelId does not exist.');
        }

        final data = channelSnapshot.data()!;
        final existingIds = List<String>.from(data['memberIds'] ?? []);
        final updatedIds = existingIds.where((id) => !memberIds.contains(id)).toList();

        transaction.update(channelDocRef, {
          'memberIds': updatedIds,
          'memberCount': updatedIds.length,
        });

        for (final memberId in memberIds) {
          transaction.delete(membersRef(channelId).doc(memberId));
        }
      });

      logger.info('Removed ${memberIds.length} members from community channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error removing members from community channel', error, stackTrace);
      rethrow;
    }
  }

  /// Leave a community channel.
  ///
  /// Uses a Firestore transaction to atomically:
  /// 1. Verify the user is a member and not the owner
  /// 2. Remove userId from memberIds and set memberCount to match
  /// 3. Delete the member subcollection document
  ///
  /// Throws [StateError] if the current user is the channel owner.
  Future<void> leaveChannel(String channelId) async {
    try {
      final channelDocRef = channelRef(channelId);
      final memberDocRef = membersRef(channelId).doc(userId);

      await firestore.runTransaction((transaction) async {
        final channelSnapshot = await transaction.get(channelDocRef);
        final memberSnapshot = await transaction.get(memberDocRef);

        if (!channelSnapshot.exists) {
          throw StateError('Channel $channelId does not exist.');
        }

        // Owner guard
        if (memberSnapshot.exists) {
          final memberData = memberSnapshot.data();
          if (memberData?['role'] == ChannelMemberRole.owner.value) {
            throw StateError(
              'Channel owner cannot leave. '
              'Transfer ownership or delete the channel.',
            );
          }
        }

        final data = channelSnapshot.data()!;
        final memberIds = List<String>.from(data['memberIds'] ?? []);

        // Not a member -- nothing to do.
        if (!memberIds.contains(userId)) return;

        memberIds.remove(userId);

        transaction.update(channelDocRef, {
          'memberIds': memberIds,
          'memberCount': memberIds.length,
        });

        transaction.delete(memberDocRef);
      });

      logger.info('User $userId left community channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error leaving community channel', error, stackTrace);
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
    ChannelVisibility? visibility,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (iconEmoji != null) updates['iconEmoji'] = iconEmoji;
      if (visibility != null) updates['visibility'] = visibility.value;

      if (updates.isEmpty) {
        logger.warning('No updates provided for channel $channelId');
        return;
      }

      updates['updatedAt'] = DateTime.now().toIso8601String();
      updates['updatedById'] = userId;

      await channelRef(channelId).update(updates);
      logger.info('Updated community channel: $channelId');
    } catch (error, stackTrace) {
      logger.error('Error updating community channel', error, stackTrace);
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

      logger.info('Archived community channel: $channelId');
    } catch (error, stackTrace) {
      logger.error('Error archiving community channel', error, stackTrace);
      rethrow;
    }
  }
}
