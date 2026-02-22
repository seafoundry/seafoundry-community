// @tier: community

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/posts/post.dart';
import 'package:seafoundry_app/models/posts/post_author.dart';
import 'package:seafoundry_app/models/types/post_scope.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Base repository for posts with shared CRUD operations.
///
/// This abstract class implements the Template Method pattern to share
/// common post operations while allowing subclasses to define:
/// - Collection path resolution
/// - Post scope (organization vs community)
/// - Organization ID handling
///
/// Subclasses:
/// - [PostRepository]: Organization-scoped posts (subcollection)
/// - [CommunityPostRepository]: Community-wide posts (top-level collection)
abstract class BasePostRepository {
  BasePostRepository({
    required this.userId,
    required FirebaseFirestore firestore,
    LoggingService? logger,
  })  : _firestore = firestore,
        _logger = logger ?? LoggingService.instance;

  final String userId;
  final FirebaseFirestore _firestore;
  final LoggingService _logger;

  /// Access to Firestore instance for subclasses
  FirebaseFirestore get firestore => _firestore;

  /// Access to logger for subclasses
  LoggingService get logger => _logger;

  /// The posts collection reference.
  ///
  /// Subclasses must implement this to return the appropriate collection:
  /// - PostRepository: organizations/{orgId}/posts subcollection
  /// - CommunityPostRepository: top-level posts collection
  CollectionReference<Map<String, dynamic>> get postsCollection;

  /// The default scope for posts created by this repository.
  ///
  /// - PostRepository: PostScope.organization
  /// - CommunityPostRepository: PostScope.community
  PostScope get defaultScope;

  /// Log prefix for distinguishing log messages by repository type.
  String get logPrefix;

  /// Create a new post.
  ///
  /// Parameters:
  /// - [content]: Post content text
  /// - [title]: Optional post title
  /// - [organizationId]: Organization ID (required for all posts)
  /// - [author]: Post author information
  ///
  /// Returns the created [Post]
  Future<Post> createPost({
    required String content,
    String? title,
    required String organizationId,
    required PostAuthor author,
  }) async {
    try {
      final postId = _firestore.collection('_').doc().id;
      final now = DateTime.now().toIso8601String();

      final post = Post(
        id: postId,
        createdAt: now,
        createdById: userId,
        updatedAt: now,
        updatedById: userId,
        organizationId: organizationId,
        title: title,
        content: content,
        scope: defaultScope,
        author: author,
      );

      await postsCollection.doc(postId).set(post.toJson());
      _logger.info('Created $logPrefix post: $postId');

      return post;
    } catch (error, stackTrace) {
      _logger.error('Error creating $logPrefix post', error, stackTrace);
      rethrow;
    }
  }

  /// Update an existing post's content.
  ///
  /// Only the post author can update their post.
  Future<Post> updatePost({
    required String postId,
    required String content,
    String? title,
  }) async {
    try {
      final docRef = postsCollection.doc(postId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw StateError('Post not found: $postId');
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Post data missing: $postId');
      }
      final existingPost = Post.fromJson(data);

      // Verify the current user is the author
      if (existingPost.author.id != userId) {
        throw StateError('Only the post author can update the post');
      }

      final now = DateTime.now().toIso8601String();

      final updatedPost = existingPost.copyWith(
        content: content,
        title: title,
        updatedAt: now,
        updatedById: userId,
      ).markEdited();

      await docRef.update(updatedPost.toJson());

      _logger.info('Updated $logPrefix post: $postId');
      return updatedPost;
    } catch (error, stackTrace) {
      _logger.error('Error updating $logPrefix post', error, stackTrace);
      rethrow;
    }
  }

  /// Delete a post (uses Record's soft delete via metadata).
  ///
  /// Only the post author can delete their post.
  Future<void> deletePost(String postId) async {
    try {
      final docRef = postsCollection.doc(postId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw StateError('Post not found: $postId');
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Post $postId exists but has null data');
      }
      final existingPost = Post.fromJson(data);

      // Verify the current user is the author
      if (existingPost.author.id != userId) {
        throw StateError('Only the post author can delete the post');
      }

      final now = DateTime.now().toIso8601String();

      // Soft delete by setting deletedAt in metadata
      final metadata = Map<String, dynamic>.from(existingPost.metadata ?? {});
      metadata['deletedAt'] = now;
      metadata['deletedById'] = userId;

      await docRef.update({
        'metadata': metadata,
        'updatedAt': now,
        'updatedById': userId,
      });

      _logger.info('Deleted $logPrefix post: $postId');
    } catch (error, stackTrace) {
      _logger.error('Error deleting $logPrefix post', error, stackTrace);
      rethrow;
    }
  }

  /// Get a single post by ID.
  ///
  /// Returns null if the post doesn't exist or has been deleted.
  Future<Post?> getPost(String postId) async {
    try {
      final doc = await postsCollection.doc(postId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) {
        return null;
      }

      final post = Post.fromJson(data);

      // Check if soft-deleted
      if (post.metadata?['deletedAt'] != null) {
        return null;
      }

      return post;
    } catch (error, stackTrace) {
      _logger.error('Error getting $logPrefix post $postId', error, stackTrace);
      rethrow;
    }
  }

  /// Increment comment count for a post.
  ///
  /// Called when a comment is added to a post.
  Future<void> incrementCommentCount(String postId) async {
    try {
      await postsCollection.doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      _logger.info('Incremented comment count for $logPrefix post: $postId');
    } catch (error, stackTrace) {
      _logger.error('Error incrementing comment count', error, stackTrace);
      rethrow;
    }
  }

  /// Decrement comment count for a post.
  ///
  /// Called when a comment is deleted from a post.
  Future<void> decrementCommentCount(String postId) async {
    try {
      await postsCollection.doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });

      _logger.info('Decremented comment count for $logPrefix post: $postId');
    } catch (error, stackTrace) {
      _logger.error('Error decrementing comment count', error, stackTrace);
      rethrow;
    }
  }

  /// Add a reaction to a post.
  ///
  /// Parameters:
  /// - [postId]: ID of the post to react to
  /// - [emoji]: The emoji reaction (e.g., '👍', '❤️', '🎉')
  ///
  /// If the user has already reacted with this emoji, the reaction is not duplicated.
  Future<void> addReaction({
    required String postId,
    required String emoji,
  }) async {
    try {
      await postsCollection.doc(postId).update({
        'reactions.$emoji': FieldValue.arrayUnion([userId]),
      });

      _logger.info('Added reaction $emoji to $logPrefix post: $postId');
    } catch (error, stackTrace) {
      _logger.error('Error adding reaction to post', error, stackTrace);
      rethrow;
    }
  }

  /// Remove a reaction from a post.
  ///
  /// Parameters:
  /// - [postId]: ID of the post
  /// - [emoji]: The emoji reaction to remove
  Future<void> removeReaction({
    required String postId,
    required String emoji,
  }) async {
    try {
      await postsCollection.doc(postId).update({
        'reactions.$emoji': FieldValue.arrayRemove([userId]),
      });

      _logger.info('Removed reaction $emoji from $logPrefix post: $postId');
    } catch (error, stackTrace) {
      _logger.error('Error removing reaction from post', error, stackTrace);
      rethrow;
    }
  }

  /// Toggle a reaction on a post.
  ///
  /// Uses a Firestore transaction for atomicity.
  /// If the user hasn't reacted with this emoji, adds the reaction.
  /// If the user has already reacted, removes the reaction.
  ///
  /// Returns true if the reaction was added, false if removed.
  Future<bool> toggleReaction({
    required String postId,
    required String emoji,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final docRef = postsCollection.doc(postId);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw StateError('Post not found: $postId');
        }

        final data = doc.data()!;
        final reactions =
            (data['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final emojiReactors =
            List<String>.from((reactions[emoji] as List?) ?? []);

        final hasReacted = emojiReactors.contains(userId);
        if (hasReacted) {
          emojiReactors.remove(userId);
        } else {
          emojiReactors.add(userId);
        }

        transaction.update(docRef, {'reactions.$emoji': emojiReactors});
        _logger.info(
          '${hasReacted ? 'Removed' : 'Added'} reaction $emoji '
          '${hasReacted ? 'from' : 'to'} $logPrefix post: $postId',
        );
        return !hasReacted;
      });
    } catch (error, stackTrace) {
      _logger.error('Error toggling reaction on post', error, stackTrace);
      rethrow;
    }
  }

  /// Parse posts from a query snapshot, filtering out deleted posts.
  ///
  /// Helper method for subclass stream methods.
  List<Post> parsePostsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final posts = <Post>[];
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final post = Post.fromJson(data);
        // Double-check deletion status
        if (post.metadata?['deletedAt'] == null) {
          posts.add(post);
        }
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to parse $logPrefix post ${doc.id}',
          error,
          stackTrace,
        );
      }
    }
    return posts;
  }
}
