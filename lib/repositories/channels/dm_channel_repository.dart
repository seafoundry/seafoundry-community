// @tier: community

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:seafoundry_app/models/channels/channel.dart';
import 'package:seafoundry_app/models/channels/channel_member.dart';
import 'package:seafoundry_app/models/types/channel_type.dart';
import 'package:seafoundry_app/models/types/channel_visibility.dart';
import 'package:seafoundry_app/repositories/channels/base_channel_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Repository for direct message channels.
///
/// Manages Firestore storage for private DM conversations between users.
/// Collection path: dm_channels (top-level)
///
/// Extends [BaseChannelRepository] for shared message operations and adds
/// DM-specific features like participant-based channel ID generation.
class DMChannelRepository extends BaseChannelRepository {
  DMChannelRepository({
    required super.userId,
    FirebaseFirestore? firestore,
    super.logger,
  }) : super(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  /// Collection name for DM channels.
  static const String collectionName = 'dm_channels';

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

  /// Reference to the DM channels collection.
  CollectionReference<Map<String, dynamic>> get _channelsCollection {
    return FirestoreCollectionResolver.instance.collection(
      firestore,
      collectionName,
    );
  }

  // ========================================
  // Channel ID Generation
  // ========================================

  /// Generate a deterministic channel ID from participant IDs.
  ///
  /// This ensures that for any set of participants, the same channel ID
  /// is generated regardless of the order of participant IDs.
  ///
  /// Uses SHA-256 hash of sorted participant IDs joined with colons.
  ///
  /// Example:
  /// ```dart
  /// generateChannelId(['user2@example.com', 'user1@example.com'])
  /// // Returns: 'dm_a1b2c3d4...' (consistent hash)
  /// ```
  static String generateChannelId(List<String> participantIds) {
    // Sort participant IDs to ensure consistent ordering
    final sortedIds = List<String>.from(participantIds)..sort();

    // Join with colons and hash
    final content = sortedIds.join(':');
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);

    // Prefix with 'dm_' for clarity and use first 32 chars of hash
    return 'dm_${digest.toString().substring(0, 32)}';
  }

  // ========================================
  // Channel Operations
  // ========================================

  /// Get or create a DM channel for the given participants.
  ///
  /// If a channel already exists for these participants, returns it.
  /// Otherwise, creates a new channel.
  ///
  /// Parameters:
  /// - [participantIds]: List of user IDs participating in the DM
  /// - [displayNames]: Map of user ID to display name for each participant
  ///
  /// Returns the existing or newly created [Channel]
  Future<Channel> getOrCreateChannel({
    required List<String> participantIds,
    required Map<String, String> displayNames,
  }) async {
    try {
      // Ensure current user is in participant list
      final allParticipants = <String>{userId, ...participantIds}.toList();

      // Generate deterministic channel ID
      final channelId = generateChannelId(allParticipants);

      // Check if channel already exists
      final existingDoc = await channelRef(channelId).get();
      if (existingDoc.exists) {
        final data = existingDoc.data();
        if (data != null) {
          final channel = Channel.fromJson(data);
          // If channel was archived, unarchive it
          if (channel.isArchived) {
            await unarchiveChannel(channelId);
            return channel.copyWith(isArchived: false);
          }
          return channel;
        }
      }

      // Create new DM channel
      final now = DateTime.now().toIso8601String();

      // Generate display name from participant names
      final otherParticipants = allParticipants.where((id) => id != userId);
      final channelName = otherParticipants
          .map((id) => displayNames[id] ?? id)
          .join(', ');

      final channel = Channel(
        id: channelId,
        name: channelName,
        channelType: ChannelType.directMessage,
        visibility: ChannelVisibility.inviteOnly,
        memberIds: allParticipants,
        memberCount: allParticipants.length,
        createdAt: now,
        createdById: userId,
        lastMessageAt: now, // Initialize for proper sorting
      );

      // Create the channel first so rules can read it when adding members.
      await _channelsCollection.doc(channelId).set(channel.toJson());

      // Create member documents for all participants in a follow-up batch.
      final membersBatch = firestore.batch();
      for (final participantId in allParticipants) {
        final member = ChannelMember(
          userId: participantId,
          channelId: channelId,
          role: ChannelMemberRole.member,
          joinedAt: now,
        );
        membersBatch.set(membersRef(channelId).doc(participantId), member.toJson());
      }

      await membersBatch.commit();

      logger.info('Created DM channel: $channelId with ${allParticipants.length} participants');
      return channel;
    } catch (error, stackTrace) {
      logger.error('Error getting or creating DM channel', error, stackTrace);
      rethrow;
    }
  }

  /// Stream DM channels for the current user.
  ///
  /// Returns a stream of non-archived DM channels where the user is a member,
  /// ordered by last message time (newest first).
  Stream<List<Channel>> streamChannels() {
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
              'Failed to parse DM channel ${doc.id}',
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
      logger.error('Error streaming DM channels', error, stackTrace);
      rethrow;
    }
  }

  /// Get DM channels for the current user (one-time fetch).
  ///
  /// Returns a list of non-archived DM channels where the user is a member,
  /// ordered by last message time (newest first).
  ///
  /// Note: orderBy requires composite index (memberIds + isArchived + lastMessageAt).
  /// If index is not deployed, this query will fail with 400 error.
  Future<List<Channel>> getChannels() async {
    try {
      final snapshot = await _channelsCollection
          .where('memberIds', arrayContains: userId)
          .where('isArchived', isEqualTo: false)
          .orderBy('lastMessageAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return Channel.fromJson(data);
          })
          .whereType<Channel>()
          .toList();
    } catch (error, stackTrace) {
      logger.error('Error fetching DM channels', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Group DM Operations
  // ========================================

  /// Add a member to a group DM.
  ///
  /// Only works for group DMs (3+ participants).
  /// Updates the channel name to include the new participant.
  ///
  /// Parameters:
  /// - [channelId]: ID of the DM channel
  /// - [memberId]: User ID of the member to add
  /// - [displayName]: Display name of the new member
  /// - [displayNames]: Map of all user IDs to display names
  Future<void> addMemberToGroupDM({
    required String channelId,
    required String memberId,
    required String displayName,
    required Map<String, String> displayNames,
  }) async {
    try {
      final channel = await getChannel(channelId);
      if (channel == null) {
        throw StateError('Channel not found: $channelId');
      }

      if (channel.channelType != ChannelType.directMessage) {
        throw StateError('Cannot add members to non-DM channels');
      }

      final now = DateTime.now().toIso8601String();

      // Update channel with new member
      final newMemberIds = [...channel.memberIds, memberId];
      final updatedDisplayNames = Map<String, String>.from(displayNames);
      updatedDisplayNames[memberId] = displayName;

      // Update channel name to include new member
      final otherNames = newMemberIds
          .where((id) => id != userId)
          .map((id) => updatedDisplayNames[id] ?? id);
      final newName = otherNames.join(', ');

      await channelRef(channelId).update({
        'memberIds': FieldValue.arrayUnion([memberId]),
        'memberCount': FieldValue.increment(1),
        'name': newName,
        'updatedAt': now,
        'updatedById': userId,
      });

      // Create member document
      final member = ChannelMember(
        userId: memberId,
        channelId: channelId,
        role: ChannelMemberRole.member,
        joinedAt: now,
      );
      await membersRef(channelId).doc(memberId).set(member.toJson());

      logger.info('Added member $memberId to group DM $channelId');
    } catch (error, stackTrace) {
      logger.error('Error adding member to group DM', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Archive Operations
  // ========================================

  /// Archive a DM channel (soft delete).
  ///
  /// Marks the channel as archived for the current user.
  /// The channel can be unarchived if a new message is sent.
  Future<void> archiveChannel(String channelId) async {
    try {
      await channelRef(channelId).update({
        'isArchived': true,
        'archivedAt': DateTime.now().toIso8601String(),
        'archivedById': userId,
      });

      logger.info('Archived DM channel: $channelId');
    } catch (error, stackTrace) {
      logger.error('Error archiving DM channel', error, stackTrace);
      rethrow;
    }
  }

  /// Unarchive a DM channel.
  ///
  /// Restores a previously archived channel.
  Future<void> unarchiveChannel(String channelId) async {
    try {
      await channelRef(channelId).update({
        'isArchived': false,
        'archivedAt': FieldValue.delete(),
        'archivedById': FieldValue.delete(),
      });

      logger.info('Unarchived DM channel: $channelId');
    } catch (error, stackTrace) {
      logger.error('Error unarchiving DM channel', error, stackTrace);
      rethrow;
    }
  }
}
