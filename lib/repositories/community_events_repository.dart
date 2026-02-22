// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/events/event.dart';
import '../models/factories/record_factory.dart';
import '../models/organization.dart';
import '../models/types/event_type.dart';
import '../models/types/model_type.dart';
import '../services/firestore_collection_resolver.dart';
import '../services/logging_service.dart';

/// Repository for querying cross-organization community events
///
/// This repository queries events with scope='community' from multiple
/// public organizations, supporting pagination and filtering.
class CommunityEventsRepository {
  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;
  final Map<String, bool> _outplantShareCache = {};

  CommunityEventsRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, ModelType.event.collectionPath);

  DocumentReference<Map<String, dynamic>> _privacyConfigDoc(String organizationId) {
    return _resolver
        .subcollection(
          _firestore,
          ModelType.organization.collectionPath,
          organizationId,
          'config',
        )
        .doc('data_privacy');
  }

  /// Get community events with pagination support
  ///
  /// Returns events ordered by createdAt DESC (most recent first)
  /// Supports optional filtering by event types and community channel
  /// Uses cursor-based pagination for efficient loading
  Future<CommunityEventsPage> getEvents({
    int limit = 20,
    DocumentSnapshot? startAfter,
    Set<EventType>? filterTypes,
    int currentEventCount = 0,
    String? communityChannelId,
    Organization? currentOrganization,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('scope', isEqualTo: 'community')
          .where('metadata.isCommunityPost', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      final includeCommunityPosts = _includesCommunityPosts(filterTypes);
      final includeOutplants = _includesOutplantEvents(filterTypes);
      if (!includeCommunityPosts) {
        query = query.where('eventTypeId', isEqualTo: '__skip__');
      } else if (filterTypes != null && filterTypes.isNotEmpty) {
        final typeIds = filterTypes.map((t) => t.id).toList();
        query = query.where('eventTypeId', whereIn: typeIds);
      }

      if (communityChannelId != null && communityChannelId.isNotEmpty) {
        query = query.where(
          'metadata.communityChannelId',
          isEqualTo: communityChannelId,
        );
      }

      // Apply cursor for pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Request limit + 1 to accurately detect if more results exist
      query = query.limit(limit + 1);

      final snapshot = await query.get();
      final docs = snapshot.docs;

      // Check if there are more results than requested
      final hasMore = docs.length > limit;

      // Use only the requested number of documents
      final actualDocs = hasMore ? docs.take(limit).toList() : docs;

      final events = <Event>[];

      for (final doc in actualDocs) {
        try {
          final eventData = doc.data();
          eventData['id'] = doc.id;

          final event = _createEventFromData(eventData);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to parse community event ${doc.id}: $e',
          );
        }
      }

      // Get cursor for next page
      final lastDoc = actualDocs.isNotEmpty ? actualDocs.last : null;

      final outplantEvents =
          await _loadOutplantEventsIfAllowed(
        includeOutplants: includeOutplants,
        currentOrganization: currentOrganization,
        startAfter: startAfter,
        limit: limit,
      );

      final merged = <Event>[
        ...events,
        ...outplantEvents,
      ];
      if (merged.isNotEmpty) {
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final deduped = _dedupeOutplantEvents(merged, includeCommunityPosts);

      return CommunityEventsPage(
        events: deduped,
        lastDocument: lastDoc,
        hasMore: hasMore,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get community events',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  bool _includesCommunityPosts(Set<EventType>? filterTypes) {
    if (filterTypes == null || filterTypes.isEmpty) return true;
    return filterTypes.any(
      (type) =>
          type.id == EventType.update.id ||
          type.id == EventType.commentsAndPosts.id,
    );
  }

  bool _includesOutplantEvents(Set<EventType>? filterTypes) {
    if (filterTypes == null || filterTypes.isEmpty) return true;
    return filterTypes.any((type) => type.id == EventType.outplant.id);
  }

  Future<List<Event>> _loadOutplantEventsIfAllowed({
    required bool includeOutplants,
    required Organization? currentOrganization,
    required DocumentSnapshot? startAfter,
    required int limit,
  }) async {
    if (!includeOutplants) return const [];
    if (currentOrganization == null) return const [];
    if (startAfter != null) return const [];

    final shareEnabled = await _shouldShareOutplantEvents(currentOrganization);
    if (!shareEnabled) return const [];

    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: currentOrganization.id)
          .where('eventTypeId', isEqualTo: EventType.outplant.id)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final events = <Event>[];
      for (final doc in snapshot.docs) {
        try {
          final eventData = doc.data();
          eventData['id'] = doc.id;
          final event = _createEventFromData(eventData);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to parse outplant event ${doc.id}: $e',
          );
        }
      }
      return events;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load outplant events for ${currentOrganization.id}',
        e,
        stackTrace,
      );
      return const [];
    }
  }

  Future<bool> _shouldShareOutplantEvents(Organization organization) async {
    if (organization.tier.isCommunity) return true;
    final cached = _outplantShareCache[organization.id];
    if (cached != null) return cached;
    try {
      final doc = await _privacyConfigDoc(organization.id).get();
      final shareOutplantEvents = doc.data()?['shareOutplantEvents'] == true;
      _outplantShareCache[organization.id] = shareOutplantEvents;
      return shareOutplantEvents;
    } catch (_) {
      return false;
    }
  }

  List<Event> _dedupeOutplantEvents(
    List<Event> events,
    bool includeCommunityPosts,
  ) {
    if (!includeCommunityPosts) return events;

    final sourceIds = <String>{};
    for (final event in events) {
      final metadata = event.metadata;
      if (metadata == null || metadata['isCommunityPost'] != true) continue;
      final sourceEventId = metadata['sourceEventId'];
      if (sourceEventId is String && sourceEventId.isNotEmpty) {
        sourceIds.add(sourceEventId);
      }
    }

    if (sourceIds.isEmpty) return events;
    return events
        .where(
          (event) =>
              event.eventTypeId != EventType.outplant.id ||
              !sourceIds.contains(event.id),
        )
        .toList(growable: false);
  }

  /// Stream community events (for real-time updates)
  Stream<List<Event>> streamEvents({
    int limit = 20,
    Set<EventType>? filterTypes,
    String? communityChannelId,
  }) {
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    Query<Map<String, dynamic>> query = _collection
        .where('scope', isEqualTo: 'community')
        .where('metadata.isCommunityPost', isEqualTo: true);

    // Add event type filter if specified
    if (filterTypes != null && filterTypes.isNotEmpty) {
      final typeIds = filterTypes.map((t) => t.id).toList();
      query = query.where('eventTypeId', whereIn: typeIds);
    }

    if (communityChannelId != null && communityChannelId.isNotEmpty) {
      query = query.where(
        'metadata.communityChannelId',
        isEqualTo: communityChannelId,
      );
    }

    return query.snapshots().map((snapshot) {
      final events = <Event>[];
      for (final doc in snapshot.docs) {
        try {
          final eventData = doc.data();
          eventData['id'] = doc.id;

          final event = _createEventFromData(eventData);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to parse community event ${doc.id}: $e',
          );
        }
      }
      // Sort in-memory by createdAt descending (newest first)
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Apply limit after sorting
      return events.take(limit).toList();
    });
  }

  /// Create an event from Firestore data
  Event? _createEventFromData(Map<String, dynamic> data) {
    try {
      return RecordFactory.eventFromJson(data);
    } catch (e) {
      LoggingService.instance.warning('Failed to create event from data: $e');
      return null;
    }
  }

  /// Maximum allowed content length for post descriptions
  static const int maxContentLength = 5000;

  /// Create a new community post
  ///
  /// Writes to Firestore in both demo and production modes.
  /// In demo mode, the FirestoreCollectionResolver automatically
  /// uses the demo_events collection prefix.
  ///
  /// Throws [ArgumentError] if description exceeds [maxContentLength] characters.
  Future<void> createPost({
    required String title,
    required String description,
    required String organizationId,
    required String organizationName,
    required String userId,
    required String userName,
    String? communityChannelId,
  }) async {
    // Validate content length
    if (description.length > maxContentLength) {
      throw ArgumentError(
        'Post description exceeds maximum length of $maxContentLength characters '
        '(current: ${description.length})',
      );
    }

    try {
      final now = DateTime.now().toUtc();

      // Create new document reference - _collection uses FirestoreCollectionResolver
      // which automatically applies demo_ prefix in demo mode
      final docRef = _collection.doc();

      final eventData = {
        'id': docRef.id,
        'organizationId': organizationId,
        'eventTypeId': 'event_update',
        'scope': 'community',
        'recordId': organizationId,
        'recordModelType': 'organization',
        'title': title,
        'description': description,
        'notes': description,
        'createdAt': now.toIso8601String(),
        'createdById': userId,
        'createdByName': userName,
        'updatedAt': now.toIso8601String(),
        'updatedById': userId,
        'modelType': 'event',
        'urlPath': '/$organizationId/events/${docRef.id}',
        'internalPath': 'organizations/$organizationId/events/${docRef.id}',
        'slug': docRef.id,
        'metadata': {
          'isCommunityPost': true,
          'title': title,
          'description': description,
          'createdByName': userName,
          'createdByOrgName': organizationName,
          'createdByOrgId': organizationId,
          'reactions': <String, List<String>>{},
          if (communityChannelId != null) 'communityChannelId': communityChannelId,
        },
      };

      await docRef.set(eventData);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create community post',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Remove a community post by ID.
  Future<void> deletePost({required String postId}) async {
    try {
      await _collection.doc(postId).delete();
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to delete community post',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing community post.
  ///
  /// Only the post author can update their post.
  /// Sets isEdited to true in metadata to indicate the post was modified.
  ///
  /// Throws [ArgumentError] if description exceeds [maxContentLength] characters.
  /// Throws [StateError] if the post doesn't exist or the user is not the author.
  Future<void> updatePost({
    required String postId,
    required String title,
    required String description,
    required String userId,
  }) async {
    // Validate content length
    if (description.length > maxContentLength) {
      throw ArgumentError(
        'Post description exceeds maximum length of $maxContentLength characters '
        '(current: ${description.length})',
      );
    }

    try {
      final docRef = _collection.doc(postId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw StateError('Post not found: $postId');
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Post data missing: $postId');
      }

      // Verify the current user is the author
      final createdById = data['createdById'] as String?;
      if (createdById != userId) {
        throw StateError('Only the post author can update the post');
      }

      final now = DateTime.now().toUtc();

      // Update the post with new content and mark as edited
      await docRef.update({
        'title': title,
        'description': description,
        'notes': description,
        'updatedAt': now.toIso8601String(),
        'updatedById': userId,
        'metadata.title': title,
        'metadata.description': description,
        'metadata.isEdited': true,
      });

      LoggingService.instance.info('Updated community post: $postId');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update community post',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Toggle a reaction on a community post.
  ///
  /// Adds the emoji reaction if the user hasn't reacted, removes it otherwise.
  Future<void> toggleReaction({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final docRef = _collection.doc(postId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Post not found: $postId');
        }
        final data = snapshot.data();
        if (data == null) {
          throw StateError('Post data missing: $postId');
        }

        final metadata =
            Map<String, dynamic>.from(data['metadata'] as Map? ?? {});
        final reactions =
            Map<String, dynamic>.from(metadata['reactions'] as Map? ?? {});
        final emojiReactors =
            List<String>.from(reactions[emoji] as List? ?? []);
        final hasReacted = emojiReactors.contains(userId);

        if (hasReacted) {
          emojiReactors.remove(userId);
        } else {
          emojiReactors.add(userId);
        }

        metadata['reactions'] = reactions;

        final updates = <String, dynamic>{
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'updatedById': userId,
        };

        if (emojiReactors.isEmpty) {
          updates['metadata.reactions.$emoji'] = FieldValue.delete();
          reactions.remove(emoji);
        } else {
          reactions[emoji] = emojiReactors;
          updates['metadata.reactions.$emoji'] = emojiReactors;
        }

        transaction.update(docRef, updates);
      });
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to toggle reaction on community post',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}

/// Represents a page of community events with pagination cursor
class CommunityEventsPage {
  final List<Event> events;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const CommunityEventsPage({
    required this.events,
    this.lastDocument,
    required this.hasMore,
  });
}
