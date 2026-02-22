// @tier: community

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/comments/comment.dart';
import 'package:seafoundry_app/models/types/comment_target_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/mention_utils.dart';

/// Repository for comments on community posts.
///
/// Manages Firestore storage for comments with no organization isolation.
/// Collection path: post_comments (top-level, not org-scoped)
/// Supports threading, mentions, reactions, and soft-deletion.
class CommunityCommentRepository {
  CommunityCommentRepository({
    required this.userId,
    FirebaseFirestore? firestore,
    LoggingService? logger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? LoggingService.instance;

  final String userId;
  final FirebaseFirestore _firestore;
  final LoggingService _logger;

  /// Reference to top-level post_comments collection
  CollectionReference<Map<String, dynamic>> get _commentsCollection {
    return FirestoreCollectionResolver.instance.collection(
      _firestore,
      'post_comments',
    );
  }

  /// Create a new comment on a community post
  ///
  /// Parameters:
  /// - [targetId]: ID of the post being commented on
  /// - [content]: Comment text content
  /// - [authorName]: Display name of the comment author
  /// - [parentCommentId]: Optional ID of parent comment for threading
  ///
  /// Returns the created [Comment] with extracted mentions
  Future<Comment> createComment({
    required String targetId,
    required String content,
    required String authorName,
    String? parentCommentId,
  }) async {
    try {
      final commentId = _firestore.collection('_').doc().id;
      final now = DateTime.now().toIso8601String();
      final mentions = MentionUtils.extractMentions(content);

      final comment = Comment(
        id: commentId,
        organizationId: '', // No org scoping for community comments
        targetType: CommentTargetType.post.id,
        targetId: targetId,
        authorUid: userId,
        authorName: authorName,
        content: content,
        createdAt: now,
        parentCommentId: parentCommentId,
        mentions: mentions,
      );

      await _commentsCollection.doc(commentId).set(comment.toJson());
      _logger.info('Created community comment: $commentId on post/$targetId');

      return comment;
    } catch (error, stackTrace) {
      _logger.error('Error creating community comment', error, stackTrace);
      rethrow;
    }
  }

  /// Update an existing comment's content
  ///
  /// Only the comment author can update their comment.
  Future<Comment> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final docRef = _commentsCollection.doc(commentId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw StateError('Comment not found: $commentId');
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Comment data missing: $commentId');
      }
      final existingComment = Comment.fromJson(data);

      // Verify the current user is the author
      if (existingComment.authorUid != userId) {
        throw StateError('Only the comment author can update the comment');
      }

      final now = DateTime.now().toIso8601String();
      final mentions = MentionUtils.extractMentions(content);

      final updatedComment = existingComment.copyWith(
        content: content,
        updatedAt: now,
        mentions: mentions,
        isEdited: true,
      );

      await docRef.update({
        'content': content,
        'updatedAt': now,
        'mentions': mentions,
        'isEdited': true,
      });

      _logger.info('Updated community comment: $commentId');
      return updatedComment;
    } catch (error, stackTrace) {
      _logger.error('Error updating community comment', error, stackTrace);
      rethrow;
    }
  }

  /// Soft-delete a comment and any replies authored by the current user.
  ///
  /// Sets [isDeleted] to true instead of removing the document.
  /// Only the comment author can delete their comment.
  Future<void> deleteComment(String commentId) async {
    try {
      final docRef = _commentsCollection.doc(commentId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw StateError('Comment not found: $commentId');
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Comment $commentId exists but has null data');
      }
      final existingComment = Comment.fromJson(data);

      // Verify the current user is the author
      if (existingComment.authorUid != userId) {
        throw StateError('Only the comment author can delete the comment');
      }

      final now = DateTime.now().toIso8601String();

      // Use a batch to atomically soft-delete parent and permitted replies
      final batch = _firestore.batch();

      // Delete the parent comment
      batch.update(docRef, {
        'isDeleted': true,
        'updatedAt': now,
      });

      // Only delete replies authored by the current user to comply with rules.
      final repliesSnapshot = await _commentsCollection
          .where('parentCommentId', isEqualTo: commentId)
          .get();
      var deletedReplies = 0;
      for (final replyDoc in repliesSnapshot.docs) {
        final data = replyDoc.data();
        final authorUid = data['authorUid'] as String?;
        if (authorUid?.toLowerCase() != userId.toLowerCase()) {
          continue;
        }
        batch.update(replyDoc.reference, {
          'isDeleted': true,
          'updatedAt': now,
        });
        deletedReplies += 1;
      }

      await batch.commit();

      _logger.info(
        'Deleted community comment: $commentId (with $deletedReplies replies)',
      );
    } catch (error, stackTrace) {
      _logger.error('Error deleting community comment', error, stackTrace);
      rethrow;
    }
  }

  /// Add a reaction (emoji) to a comment
  ///
  /// Uses Firestore's [FieldValue.arrayUnion] to atomically add the user
  /// to the reaction list for the specified emoji.
  Future<void> addReaction({
    required String commentId,
    required String emoji,
  }) async {
    try {
      await _commentsCollection.doc(commentId).update({
        'reactions.$emoji': FieldValue.arrayUnion([userId]),
      });

      _logger.info('Added reaction $emoji to community comment $commentId');
    } catch (error, stackTrace) {
      _logger.error('Error adding reaction', error, stackTrace);
      rethrow;
    }
  }

  /// Remove a reaction (emoji) from a comment
  ///
  /// Uses Firestore's [FieldValue.arrayRemove] to atomically remove the user
  /// from the reaction list for the specified emoji.
  Future<void> removeReaction({
    required String commentId,
    required String emoji,
  }) async {
    try {
      await _commentsCollection.doc(commentId).update({
        'reactions.$emoji': FieldValue.arrayRemove([userId]),
      });

      _logger.info(
        'Removed reaction $emoji from community comment $commentId',
      );
    } catch (error, stackTrace) {
      _logger.error('Error removing reaction', error, stackTrace);
      rethrow;
    }
  }

  /// Stream comments for a specific post
  ///
  /// Returns a stream of all non-deleted comments for the specified post,
  /// ordered by creation time (oldest first).
  ///
  /// Parameters:
  /// - [postId]: ID of the post
  Stream<List<Comment>> streamComments({
    required String postId,
  }) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _commentsCollection
          .where('targetType', isEqualTo: 'post')
          .where('targetId', isEqualTo: postId)
          .where('isDeleted', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final comments = <Comment>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            comments.add(Comment.fromJson(data));
          } catch (error, stackTrace) {
            _logger.error(
              'Failed to parse community comment ${doc.id}',
              error,
              stackTrace,
            );
          }
        }
        // Sort in-memory by createdAt ascending (oldest first)
        comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return comments;
      });
    } catch (error, stackTrace) {
      _logger.error('Error streaming community comments', error, stackTrace);
      rethrow;
    }
  }

  /// Get the count of comments for a specific post
  ///
  /// Returns the number of non-deleted comments for the post.
  Future<int> getCommentCount({
    required String postId,
  }) async {
    try {
      final snapshot = await _commentsCollection
          .where('targetType', isEqualTo: 'post')
          .where('targetId', isEqualTo: postId)
          .where('isDeleted', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (error, stackTrace) {
      _logger.error('Error getting comment count', error, stackTrace);
      rethrow;
    }
  }
}
