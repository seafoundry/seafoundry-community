// @tier: community

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/posts/post.dart';
import 'package:seafoundry_app/models/types/post_scope.dart';
import 'package:seafoundry_app/repositories/posts/base_post_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Repository for community-wide posts (cross-organization).
///
/// Manages Firestore storage for posts visible across all organizations.
/// Collection path: posts (top-level)
///
/// Extends [BasePostRepository] for shared CRUD operations and adds
/// community-specific features like organization filtering.
class CommunityPostRepository extends BasePostRepository {
  CommunityPostRepository({
    required super.userId,
    FirebaseFirestore? firestore,
    super.logger,
  }) : super(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  @override
  CollectionReference<Map<String, dynamic>> get postsCollection {
    return FirestoreCollectionResolver.instance.collection(
      firestore,
      'posts',
    );
  }

  @override
  PostScope get defaultScope => PostScope.community;

  @override
  String get logPrefix => 'community';

  /// Stream community posts with pagination.
  ///
  /// Returns a stream of non-deleted community posts ordered by creation time (newest first).
  ///
  /// Parameters:
  /// - [limit]: Maximum number of posts to return
  /// - [cursor]: Optional pagination cursor (last document from previous page)
  Stream<List<Post>> streamCommunityPosts({
    int limit = 20,
    DocumentSnapshot? cursor,
  }) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      Query<Map<String, dynamic>> query = postsCollection
          .where('scope', isEqualTo: PostScope.community.name)
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
      logger.error('Error streaming community posts', error, stackTrace);
      rethrow;
    }
  }

  /// Stream community posts by organization.
  ///
  /// Returns posts from a specific organization that are community-scoped.
  ///
  /// Parameters:
  /// - [organizationId]: Organization ID to filter by
  /// - [limit]: Maximum number of posts to return
  Stream<List<Post>> streamPostsByOrganization(
    String organizationId, {
    int limit = 20,
  }) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return postsCollection
          .where('scope', isEqualTo: PostScope.community.name)
          .where('organizationId', isEqualTo: organizationId)
          .where('metadata.deletedAt', isNull: true)
          .snapshots()
          .map((snapshot) {
            final posts = parsePostsFromSnapshot(snapshot);
            // Sort in-memory by createdAt descending (newest first)
            posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            // Apply limit after sorting
            return posts.take(limit).toList();
          });
    } catch (error, stackTrace) {
      logger.error(
        'Error streaming posts for organization $organizationId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }
}
