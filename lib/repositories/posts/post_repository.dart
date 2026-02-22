// @tier: community

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/posts/post.dart';
import 'package:seafoundry_app/models/posts/post_author.dart';
import 'package:seafoundry_app/models/types/post_scope.dart';
import 'package:seafoundry_app/repositories/posts/base_post_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Repository for organization-scoped posts.
///
/// Manages Firestore storage for posts within an organization.
/// Collection path: organizations/{orgId}/posts
///
/// Extends [BasePostRepository] for shared CRUD operations and adds
/// organization-specific features like pinning.
class PostRepository extends BasePostRepository {
  PostRepository({
    required this.organizationId,
    required super.userId,
    FirebaseFirestore? firestore,
    super.logger,
  }) : super(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  final String organizationId;

  @override
  CollectionReference<Map<String, dynamic>> get postsCollection {
    return FirestoreCollectionResolver.instance.subcollection(
      firestore,
      'organizations',
      organizationId,
      'posts',
    );
  }

  @override
  PostScope get defaultScope => PostScope.organization;

  @override
  String get logPrefix => 'organization';

  /// Create a new organization-scoped post.
  ///
  /// Convenience method that uses the repository's organizationId.
  ///
  /// Parameters:
  /// - [content]: Post content text
  /// - [title]: Optional post title
  /// - [author]: Post author information
  ///
  /// Returns the created [Post]
  Future<Post> createOrganizationPost({
    required String content,
    String? title,
    required PostAuthor author,
  }) {
    return createPost(
      content: content,
      title: title,
      organizationId: organizationId,
      author: author,
    );
  }

  /// Stream organization posts with pagination.
  ///
  /// Returns a stream of non-deleted posts ordered by creation time (newest first).
  ///
  /// Parameters:
  /// - [limit]: Maximum number of posts to return
  /// - [cursor]: Optional pagination cursor (last document from previous page)
  Stream<List<Post>> streamPosts({
    int limit = 20,
    DocumentSnapshot? cursor,
  }) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      Query<Map<String, dynamic>> query = postsCollection
          .where('metadata.deletedAt', isNull: true);

      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      return query.snapshots().map((snapshot) {
        final posts = parsePostsFromSnapshot(snapshot);
        // Sort in-memory by createdAt descending (newest first)
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // Apply limit after sorting
        return posts.take(limit).toList();
      });
    } catch (error, stackTrace) {
      logger.error('Error streaming posts', error, stackTrace);
      rethrow;
    }
  }

  /// Stream pinned posts.
  ///
  /// Returns a stream of pinned, non-deleted posts ordered by creation time.
  Stream<List<Post>> streamPinnedPosts() {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return postsCollection
          .where('isPinned', isEqualTo: true)
          .where('metadata.deletedAt', isNull: true)
          .snapshots()
          .map((snapshot) {
            final posts = parsePostsFromSnapshot(snapshot);
            // Sort in-memory by createdAt descending (newest first)
            posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return posts;
          });
    } catch (error, stackTrace) {
      logger.error('Error streaming pinned posts', error, stackTrace);
      rethrow;
    }
  }

  /// Pin a post.
  ///
  /// Marks the post as pinned. Pinned posts appear at the top of feeds.
  Future<void> pinPost(String postId) async {
    try {
      final post = await getPost(postId);
      if (post == null) {
        throw StateError('Post not found: $postId');
      }

      final pinnedPost = post.pin();

      await postsCollection.doc(postId).update({
        'isPinned': pinnedPost.isPinned,
        'pinnedAt': pinnedPost.pinnedAt,
        'updatedAt': pinnedPost.updatedAt,
        'updatedById': userId,
      });

      logger.info('Pinned post: $postId');
    } catch (error, stackTrace) {
      logger.error('Error pinning post', error, stackTrace);
      rethrow;
    }
  }

  /// Unpin a post.
  ///
  /// Removes the pinned status from a post.
  Future<void> unpinPost(String postId) async {
    try {
      final post = await getPost(postId);
      if (post == null) {
        throw StateError('Post not found: $postId');
      }

      final now = DateTime.now().toIso8601String();

      await postsCollection.doc(postId).update({
        'isPinned': false,
        'pinnedAt': FieldValue.delete(),
        'updatedAt': now,
        'updatedById': userId,
      });

      logger.info('Unpinned post: $postId');
    } catch (error, stackTrace) {
      logger.error('Error unpinning post', error, stackTrace);
      rethrow;
    }
  }
}
