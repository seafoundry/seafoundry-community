// @tier: community

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/channels/channel.dart';
import 'package:seafoundry_app/models/channels/channel_member.dart';
import 'package:seafoundry_app/models/channels/channel_message.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/mention_utils.dart';

/// Abstract base class providing common message operations for channels.
///
/// This class implements the Template Method pattern to share common
/// channel operations while allowing subclasses to define:
/// - Collection path resolution (channelRef, messagesRef, membersRef)
/// - Channel-specific behavior
///
/// Subclasses:
/// - [CommunityChannelRepository]: Top-level community_channels collection
/// - [OrganizationChannelRepository]: Organization subcollection
/// - [DMChannelRepository]: Top-level dm_channels collection
abstract class BaseChannelRepository {
  BaseChannelRepository({
    required this.userId,
    FirebaseFirestore? firestore,
    LoggingService? logger,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        logger = logger ?? LoggingService.instance;

  final String userId;
  final FirebaseFirestore firestore;
  final LoggingService logger;

  // ========================================
  // Abstract methods - Subclasses must implement
  // ========================================

  /// Reference to a specific channel document.
  DocumentReference<Map<String, dynamic>> channelRef(String channelId);

  /// Reference to the messages subcollection for a channel.
  CollectionReference<Map<String, dynamic>> messagesRef(String channelId);

  /// Reference to the members subcollection for a channel.
  CollectionReference<Map<String, dynamic>> membersRef(String channelId);

  // ========================================
  // Channel Operations
  // ========================================

  /// Get a specific channel by ID.
  ///
  /// Returns null if the channel doesn't exist.
  Future<Channel?> getChannel(String channelId) async {
    try {
      final doc = await channelRef(channelId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) return null;
      return Channel.fromJson(data);
    } catch (error, stackTrace) {
      logger.error('Error getting channel $channelId', error, stackTrace);
      rethrow;
    }
  }

  /// Stream a specific channel by ID.
  ///
  /// Returns a stream that emits the channel whenever it changes.
  /// Emits null if the channel doesn't exist or is deleted.
  Stream<Channel?> streamChannel(String channelId) {
    try {
      return channelRef(channelId).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }

        final data = doc.data();
        if (data == null) return null;

        final channel = Channel.fromJson(data);
        // Check if archived
        if (channel.isArchived) {
          return null;
        }
        return channel;
      });
    } catch (error, stackTrace) {
      logger.error('Error streaming channel $channelId', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Message Operations
  // ========================================

  /// Send a message to a channel.
  ///
  /// Parameters:
  /// - [channelId]: ID of the channel to send the message to
  /// - [content]: Message text content
  /// - [senderName]: Display name of the sender
  /// - [replyToMessageId]: Optional ID of message being replied to
  /// - [attachments]: Optional list of attachments
  ///
  /// Returns the created [ChannelMessage]
  ///
  /// This method uses a Firestore transaction to atomically:
  /// 1. Create the message
  /// 2. Update the channel's lastMessage fields
  Future<ChannelMessage> sendMessage({
    required String channelId,
    required String content,
    required String senderName,
    String? replyToMessageId,
    List<ChannelAttachment>? attachments,
  }) async {
    try {
      final messageId = firestore.collection('_').doc().id;
      final now = DateTime.now().toIso8601String();
      final mentions = MentionUtils.extractMentions(content);

      // Get reply preview if this is a reply
      String? replyPreview;
      if (replyToMessageId != null) {
        final replyDoc = await messagesRef(channelId).doc(replyToMessageId).get();
        if (replyDoc.exists) {
          final replyData = replyDoc.data();
          replyPreview = replyData?['content'] as String?;
          if (replyPreview != null && replyPreview.length > 100) {
            replyPreview = '${replyPreview.substring(0, 100)}...';
          }
        }
      }

      final message = ChannelMessage(
        id: messageId,
        channelId: channelId,
        senderId: userId,
        senderName: senderName,
        content: content,
        createdAt: now,
        mentions: mentions,
        attachments: attachments ?? const [],
        replyToMessageId: replyToMessageId,
        replyToPreview: replyPreview,
      );

      // Use transaction to create message and update channel atomically
      await firestore.runTransaction((transaction) async {
        // Create the message
        transaction.set(messagesRef(channelId).doc(messageId), message.toJson());

        // Update channel's last message fields
        final messagePreview = content.length > 100
            ? '${content.substring(0, 100)}...'
            : content;

        transaction.update(channelRef(channelId), {
          'lastMessageAt': now,
          'lastMessagePreview': messagePreview,
          'lastMessageSenderId': userId,
        });
      });

      logger.info('Sent message $messageId to channel $channelId');
      return message;
    } catch (error, stackTrace) {
      logger.error('Error sending message', error, stackTrace);
      rethrow;
    }
  }

  /// Stream messages for a channel (real-time, newest first).
  ///
  /// Parameters:
  /// - [channelId]: ID of the channel
  /// - [limit]: Maximum number of messages to fetch (default: 50)
  ///
  /// Returns a stream of messages ordered by creation time (newest first)
  Stream<List<ChannelMessage>> streamMessages(String channelId, {int limit = 50}) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return messagesRef(channelId)
          .where('isDeleted', isEqualTo: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final messages = <ChannelMessage>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            messages.add(ChannelMessage.fromJson(data));
          } catch (error, stackTrace) {
            logger.error(
              'Failed to parse message ${doc.id}',
              error,
              stackTrace,
            );
          }
        }
        // Sort by createdAt descending (newest first)
        messages.sort((a, b) {
          final dateA = DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        return messages;
      });
    } catch (error, stackTrace) {
      logger.error(
        'Error streaming messages for channel $channelId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Load older messages (pagination).
  ///
  /// Parameters:
  /// - [channelId]: ID of the channel
  /// - [beforeMessageId]: ID of the oldest currently loaded message
  /// - [limit]: Maximum number of messages to fetch (default: 50)
  ///
  /// Returns a list of older messages
  ///
  /// Note: orderBy requires composite index (isDeleted + createdAt).
  /// If index is not deployed, this query will fail with 400 error.
  Future<List<ChannelMessage>> loadOlderMessages({
    required String channelId,
    required String beforeMessageId,
    int limit = 50,
  }) async {
    try {
      // Get the timestamp of the beforeMessageId
      final beforeDoc = await messagesRef(channelId).doc(beforeMessageId).get();
      if (!beforeDoc.exists) {
        logger.warning('Before message $beforeMessageId not found');
        return [];
      }

      final beforeData = beforeDoc.data();
      if (beforeData == null || beforeData['createdAt'] == null) {
        logger.warning(
          'Before message $beforeMessageId has null data; aborting pagination',
        );
        return [];
      }
      final beforeTimestamp = beforeData['createdAt'] as String;

      // Query messages older than that timestamp
      final snapshot = await messagesRef(channelId)
          .where('isDeleted', isEqualTo: false)
          .where('createdAt', isLessThan: beforeTimestamp)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final messages = <ChannelMessage>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          messages.add(ChannelMessage.fromJson(data));
        } catch (error, stackTrace) {
          logger.error('Failed to parse message ${doc.id}', error, stackTrace);
        }
      }

      logger.info('Loaded ${messages.length} older messages for channel $channelId');
      return messages;
    } catch (error, stackTrace) {
      logger.error('Error loading older messages', error, stackTrace);
      rethrow;
    }
  }

  /// Edit a message.
  ///
  /// Only the message sender can edit their message.
  /// Updates the [isEdited] flag and extracts new mentions.
  Future<void> editMessage({
    required String channelId,
    required String messageId,
    required String content,
  }) async {
    try {
      final docRef = messagesRef(channelId).doc(messageId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw StateError('Message not found: $messageId');
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Message data missing: $messageId');
      }
      final existingMessage = ChannelMessage.fromJson(data);

      // Verify the current user is the sender
      if (existingMessage.senderId != userId) {
        throw StateError('Only the message sender can edit the message');
      }

      final mentions = MentionUtils.extractMentions(content);

      await docRef.update({
        'content': content,
        'mentions': mentions,
        'isEdited': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      logger.info('Edited message: $messageId');
    } catch (error, stackTrace) {
      logger.error('Error editing message', error, stackTrace);
      rethrow;
    }
  }

  /// Delete a message (soft delete).
  ///
  /// Only the message sender can delete their message.
  /// Sets [isDeleted] to true instead of removing the document.
  Future<void> deleteMessage({
    required String channelId,
    required String messageId,
  }) async {
    try {
      final docRef = messagesRef(channelId).doc(messageId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw StateError('Message not found: $messageId');
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Message data missing: $messageId');
      }
      final existingMessage = ChannelMessage.fromJson(data);

      // Verify the current user is the sender
      if (existingMessage.senderId != userId) {
        throw StateError('Only the message sender can delete the message');
      }

      await docRef.update({
        'isDeleted': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      logger.info('Deleted message: $messageId');
    } catch (error, stackTrace) {
      logger.error('Error deleting message', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Reaction Operations
  // ========================================

  /// Add reaction to a message.
  ///
  /// Uses Firestore's [FieldValue.arrayUnion] to atomically add the user
  /// to the reaction list for the specified emoji.
  Future<void> addReaction({
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await messagesRef(channelId).doc(messageId).update({
        'reactions.$emoji': FieldValue.arrayUnion([userId]),
      });

      logger.info('Added reaction $emoji to message $messageId');
    } catch (error, stackTrace) {
      logger.error('Error adding reaction', error, stackTrace);
      rethrow;
    }
  }

  /// Remove reaction from a message.
  ///
  /// Uses Firestore's [FieldValue.arrayRemove] to atomically remove the user
  /// from the reaction list for the specified emoji.
  Future<void> removeReaction({
    required String channelId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await messagesRef(channelId).doc(messageId).update({
        'reactions.$emoji': FieldValue.arrayRemove([userId]),
      });

      logger.info('Removed reaction $emoji from message $messageId');
    } catch (error, stackTrace) {
      logger.error('Error removing reaction', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Pin Operations
  // ========================================

  /// Pin a message.
  ///
  /// Marks the message as pinned. Pinned messages can be displayed
  /// prominently in the channel UI.
  Future<void> pinMessage({
    required String channelId,
    required String messageId,
  }) async {
    try {
      await messagesRef(channelId).doc(messageId).update({
        'isPinned': true,
        'pinnedAt': DateTime.now().toIso8601String(),
        'pinnedById': userId,
      });

      logger.info('Pinned message: $messageId');
    } catch (error, stackTrace) {
      logger.error('Error pinning message', error, stackTrace);
      rethrow;
    }
  }

  /// Unpin a message.
  ///
  /// Removes the pinned status from a message.
  Future<void> unpinMessage({
    required String channelId,
    required String messageId,
  }) async {
    try {
      await messagesRef(channelId).doc(messageId).update({
        'isPinned': false,
        'pinnedAt': FieldValue.delete(),
        'pinnedById': FieldValue.delete(),
      });

      logger.info('Unpinned message: $messageId');
    } catch (error, stackTrace) {
      logger.error('Error unpinning message', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Read Tracking Operations
  // ========================================

  /// Mark messages as read.
  ///
  /// Uses batch updates to mark multiple messages as read by the current user.
  ///
  /// Parameters:
  /// - [channelId]: ID of the channel
  /// - [messageIds]: List of message IDs to mark as read
  Future<void> markAsRead({
    required String channelId,
    required List<String> messageIds,
  }) async {
    try {
      if (messageIds.isEmpty) {
        return;
      }

      final batch = firestore.batch();

      for (final messageId in messageIds) {
        batch.update(messagesRef(channelId).doc(messageId), {
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }

      await batch.commit();
      logger.info(
        'Marked ${messageIds.length} messages as read in channel $channelId',
      );
    } catch (error, stackTrace) {
      logger.error('Error marking messages as read', error, stackTrace);
      rethrow;
    }
  }

  // ========================================
  // Member Operations
  // ========================================

  /// Get the current user's member record for a channel.
  ///
  /// Returns null if the user is not a member.
  Future<ChannelMember?> getCurrentMember(String channelId) async {
    try {
      final doc = await membersRef(channelId).doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) return null;
      return ChannelMember.fromJson(data);
    } catch (error, stackTrace) {
      logger.error(
        'Error getting member for channel $channelId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Stream the current user's member record for a channel.
  ///
  /// Returns a stream that emits the member record whenever it changes.
  /// Emits null if the user is not a member.
  Stream<ChannelMember?> streamCurrentMember(String channelId) {
    try {
      return membersRef(channelId).doc(userId).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }

        final data = doc.data();
        if (data == null) return null;
        return ChannelMember.fromJson(data);
      });
    } catch (error, stackTrace) {
      logger.error(
        'Error streaming member for channel $channelId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update member preferences for the current user.
  ///
  /// Parameters:
  /// - [channelId]: ID of the channel
  /// - [isMuted]: Whether to mute notifications for this channel
  /// - [notificationPreference]: Notification level ('all', 'mentions', 'none')
  Future<void> updateMemberPreferences({
    required String channelId,
    bool? isMuted,
    String? notificationPreference,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (isMuted != null) updates['isMuted'] = isMuted;
      if (notificationPreference != null) {
        updates['notificationPreference'] = notificationPreference;
      }

      if (updates.isEmpty) {
        logger.warning('No updates provided for member preferences');
        return;
      }

      await membersRef(channelId).doc(userId).update(updates);
      logger.info('Updated member preferences for channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error updating member preferences', error, stackTrace);
      rethrow;
    }
  }

  /// Update the last read timestamp for the current user.
  ///
  /// This is typically called when the user views the channel.
  Future<void> updateLastRead(String channelId) async {
    try {
      await membersRef(channelId).doc(userId).update({
        'lastReadAt': DateTime.now().toIso8601String(),
      });

      logger.info('Updated last read for channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error updating last read', error, stackTrace);
      rethrow;
    }
  }

  /// Set the starred status for the current user.
  ///
  /// Starred channels appear in a special section of the sidebar.
  Future<void> setStarred({
    required String channelId,
    required bool starred,
  }) async {
    try {
      await membersRef(channelId).doc(userId).update({
        'isStarred': starred,
      });

      logger.info('Set starred=$starred for channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error setting starred status', error, stackTrace);
      rethrow;
    }
  }

  /// Set the muted status for the current user.
  ///
  /// Muted channels don't send notifications.
  Future<void> setMuted({
    required String channelId,
    required bool muted,
  }) async {
    try {
      await membersRef(channelId).doc(userId).update({
        'isMuted': muted,
      });

      logger.info('Set muted=$muted for channel $channelId');
    } catch (error, stackTrace) {
      logger.error('Error setting muted status', error, stackTrace);
      rethrow;
    }
  }

}
