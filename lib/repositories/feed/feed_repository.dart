// @tier: community

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/feed/feed_item.dart';
import 'package:seafoundry_app/repositories/posts/post_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for unified event+post feeds.
///
/// Combines events and posts into a single chronological feed.
class FeedRepository {
  FeedRepository({
    required this.organizationId,
    required this.userId,
    required PostRepository postRepository,
    LoggingService? logger,
  })  : _postRepository = postRepository,
        _logger = logger ?? LoggingService.instance;

  final String organizationId;
  final String userId;
  final PostRepository _postRepository;
  final LoggingService _logger;

  /// Stream organization feed (events + posts)
  ///
  /// Merges events and posts, sorted by timestamp descending (newest first).
  ///
  /// Parameters:
  /// - [limit]: Maximum number of items to return
  /// - [cursor]: Optional pagination cursor
  ///
  /// Note: This is a simple implementation that streams both sources separately.
  /// For production use with large datasets, consider:
  /// 1. Using a Cloud Function to maintain a unified feed collection
  /// 2. Implementing client-side merging with proper pagination
  /// 3. Using Firestore collection group queries if structure allows
  Stream<List<FeedItem>> streamOrganizationFeed({
    int limit = 20,
    DocumentSnapshot? cursor,
  }) {
    try {
      // Stream posts
      final postsStream = _postRepository.streamPosts(
        limit: limit,
        cursor: cursor,
      );

      // Transform posts to feed items
      return postsStream.map((posts) {
        final feedItems = <FeedItem>[];

        // Add posts as feed items
        for (final post in posts) {
          feedItems.add(PostFeedItem(post));
        }

        // Sort by timestamp descending
        feedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Take only the limit
        if (feedItems.length > limit) {
          return feedItems.sublist(0, limit);
        }

        return feedItems;
      });
    } catch (error, stackTrace) {
      _logger.error('Error streaming organization feed', error, stackTrace);
      rethrow;
    }
  }

  /// Stream combined feed with events
  ///
  /// This is a more complex implementation that fetches both events and posts
  /// and merges them on the client side. For better performance with large
  /// datasets, consider using a Cloud Function to maintain a denormalized
  /// feed collection.
  ///
  /// Parameters:
  /// - [startDate]: Optional start date for filtering
  /// - [endDate]: Optional end date for filtering
  /// - [limit]: Maximum number of items to return
  Stream<List<FeedItem>> streamCombinedFeed({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) {
    try {
      // Stream posts
      final postsStream = _postRepository.streamPosts(limit: limit);

      // Transform posts to feed items with date filtering
      return postsStream.map((posts) {
        final feedItems = <FeedItem>[];

        // Add posts as feed items
        for (final post in posts) {
          final postTimestamp = post.createdAtDateTime;

          // Apply date filters if provided
          if (startDate != null && postTimestamp.isBefore(startDate)) {
            continue;
          }
          if (endDate != null && postTimestamp.isAfter(endDate)) {
            continue;
          }

          feedItems.add(PostFeedItem(post));
        }

        // Sort by timestamp descending
        feedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Take only the limit
        if (feedItems.length > limit) {
          return feedItems.sublist(0, limit);
        }

        return feedItems;
      });
    } catch (error, stackTrace) {
      _logger.error('Error streaming combined feed', error, stackTrace);
      rethrow;
    }
  }
}
