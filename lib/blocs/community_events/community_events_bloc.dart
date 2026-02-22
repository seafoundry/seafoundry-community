// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:uuid/uuid.dart';

import 'package:seafoundry_app/blocs/community_events/community_events_state.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/repositories/community_events_repository.dart';

/// BLoC for managing the community event feed with cursor-based pagination.
///
/// Handles loading, filtering, and refreshing of community events. Uses
/// different concurrency strategies per action:
/// - Start/refresh/filter: token-based restartable fetches (stale results ignored)
/// - Load more: droppable when a pagination request is already in flight
/// - Post mutations: queued to preserve ordering
///
/// Maintains pagination state via Firestore document snapshots for efficient
/// cursor-based pagination.
class CommunityEventsBloc extends SafeCubit<CommunityEventsState> {
  final CommunityEventsRepository _repository;
  final String? _communityChannelId;
  final Organization? _currentOrganization;
  DocumentSnapshot? _lastDocument;
  int _loadToken = 0;
  bool _isPaginationInFlight = false;
  Future<void> _postMutationQueue = Future.value();

  /// UUID generator for creating unique temporary IDs.
  /// Using const Uuid() ensures a single instance is reused.
  static const _uuid = Uuid();

  CommunityEventsBloc({
    CommunityEventsRepository? repository,
    String? communityChannelId,
    Organization? currentOrganization,
  })  : _repository = repository ?? CommunityEventsRepository(),
        _communityChannelId = communityChannelId,
        _currentOrganization = currentOrganization,
        super(const CommunityEventsState());

  Future<void> start() async {
    if (state.isLoading) return;
    final token = ++_loadToken;
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final page = await _repository.getEvents(
        limit: 20,
        filterTypes: state.filterTypes,
        currentOrganization: _currentOrganization,
      );

      if (token != _loadToken) return;
      _lastDocument = page.lastDocument;

      final filteredEvents = _filterByChannel(page.events);

      // Capture available event types from initial load for filter chips
      final availableTypes = filteredEvents.map((e) => e.eventType).toSet();

      emit(state.copyWith(
        events: filteredEvents,
        isLoading: false,
        hasMore: page.hasMore,
        error: null,
        availableEventTypes:
            state.availableEventTypes ?? availableTypes,
      ));
    } catch (e) {
      if (token != _loadToken) return;
      emit(state.copyWith(
        isLoading: false,
        error: 'Unable to load events. Please try again.',
      ));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || _isPaginationInFlight) return;

    _isPaginationInFlight = true;
    emit(state.copyWith(isLoading: true));

    try {
      final token = _loadToken;
      final page = await _repository.getEvents(
        limit: 20,
        startAfter: _lastDocument,
        filterTypes: state.filterTypes,
        currentEventCount: state.events.length, // For demo mode pagination
        currentOrganization: _currentOrganization,
      );

      if (token != _loadToken) return;
      _lastDocument = page.lastDocument;

      final filteredEvents = _filterByChannel(page.events);

      emit(state.copyWith(
        events: [...state.events, ...filteredEvents],
        isLoading: false,
        hasMore: page.hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Unable to load more events. Please try again.',
      ));
    } finally {
      _isPaginationInFlight = false;
    }
  }

  Future<void> refresh() async {
    _lastDocument = null;
    emit(const CommunityEventsState()); // This clears postError + reactionError
    await start();
  }

  Future<void> changeFilter(Set<EventType>? eventTypes) async {
    final token = ++_loadToken;
    _lastDocument = null;
    emit(state.copyWith(
      filterTypes: eventTypes,
      events: [],
      isLoading: true,
      error: null,  // Clear any previous error
    ));

    try {
      final page = await _repository.getEvents(
        limit: 20,
        filterTypes: eventTypes,
        currentOrganization: _currentOrganization,
      );

      if (token != _loadToken) return;
      _lastDocument = page.lastDocument;

      final filteredEvents = _filterByChannel(page.events);

      emit(state.copyWith(
        events: filteredEvents,
        isLoading: false,
        hasMore: page.hasMore,
        error: null,
      ));
    } catch (e) {
      if (token != _loadToken) return;
      emit(state.copyWith(
        isLoading: false,
        error: 'Unable to apply filter. Please try again.',
      ));
    }
  }

  Future<void> createPost({
    required String title,
    required String description,
    required String organizationId,
    required String organizationName,
    required String userId,
    required String userName,
    String? communityChannelId,
  }) {
    return _enqueuePostMutation(
      () => _handlePostCreated(
        title: title,
        description: description,
        organizationId: organizationId,
        organizationName: organizationName,
        userId: userId,
        userName: userName,
        communityChannelId: communityChannelId,
      ),
    );
  }

  Future<void> _handlePostCreated({
    required String title,
    required String description,
    required String organizationId,
    required String organizationName,
    required String userId,
    required String userName,
    String? communityChannelId,
  }) async {
    // Generate a unique temporary ID for optimistic update using UUID.
    // UUID v4 guarantees uniqueness even when called within the same millisecond,
    // preventing race conditions during rapid event creation.
    final tempId = 'temp_${_uuid.v4()}';

    // Create optimistic event for immediate display
    final optimisticEvent = _createOptimisticEvent(
      tempId: tempId,
      title: title,
      description: description,
      organizationId: organizationId,
      organizationName: organizationName,
      userId: userId,
      userName: userName,
      communityChannelId: communityChannelId,
    );

    // OPTIMISTIC UPDATE: Show post immediately in UI
    emit(state.copyWith(
      events: [optimisticEvent, ...state.events],
      pendingPostIds: {...state.pendingPostIds, tempId},
    ));

    try {
      // Send to server in background
      await _repository.createPost(
        title: title,
        description: description,
        organizationId: organizationId,
        organizationName: organizationName,
        userId: userId,
        userName: userName,
        communityChannelId: communityChannelId,
      );

      // SUCCESS: Remove optimistic post from pending set
      emit(state.copyWith(
        pendingPostIds: Set.from(state.pendingPostIds)..remove(tempId),
      ));

      // Refresh to get the server-created post with real ID
      emit(state.copyWith(
        events: state.events.where((e) => e.id != tempId).toList(),
      ));
      await refresh();
    } catch (e) {
      // FAILURE: Remove optimistic post and show post-specific error
      emit(state.copyWith(
        events: state.events.where((e) => e.id != tempId).toList(),
        pendingPostIds: Set.from(state.pendingPostIds)..remove(tempId),
        postError: 'Unable to create post. Please try again.',
      ));
    }
  }

  Future<void> deletePost(String postId) {
    return _enqueuePostMutation(() => _handlePostDeleted(postId));
  }

  Future<void> toggleReaction({
    required String postId,
    required String emoji,
    required String userId,
  }) async {
    final index = state.events.indexWhere((event) => event.id == postId);
    if (index == -1) return;

    final originalEvent = state.events[index];
    final updatedEvent = _toggleReactionOnEvent(
      originalEvent,
      emoji: emoji,
      userId: userId,
    );

    final updatedEvents = List<Event>.from(state.events);
    updatedEvents[index] = updatedEvent;

    emit(state.copyWith(
      events: updatedEvents,
      reactionError: null,
    ));

    try {
      await _repository.toggleReaction(
        postId: postId,
        userId: userId,
        emoji: emoji,
      );
    } catch (_) {
      // Revert on failure
      final revertedEvents = List<Event>.from(updatedEvents);
      revertedEvents[index] = originalEvent;
      emit(state.copyWith(
        events: revertedEvents,
        reactionError: 'Unable to update reaction. Please try again.',
      ));
    }
  }

  Event _toggleReactionOnEvent(
    Event event, {
    required String emoji,
    required String userId,
  }) {
    final metadata = Map<String, dynamic>.from(event.metadata ?? {});
    final reactions =
        Map<String, dynamic>.from(metadata['reactions'] as Map? ?? {});
    final emojiReactors = List<String>.from(reactions[emoji] as List? ?? []);
    final hasReacted = emojiReactors.contains(userId);

    if (hasReacted) {
      emojiReactors.remove(userId);
    } else {
      emojiReactors.add(userId);
    }

    if (emojiReactors.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = emojiReactors;
    }

    metadata['reactions'] = reactions;

    return event.copyWith(
      metadata: metadata,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      updatedById: userId,
    );
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String description,
    required String userId,
  }) {
    return _enqueuePostMutation(
      () => _handlePostUpdated(
        postId: postId,
        title: title,
        description: description,
        userId: userId,
      ),
    );
  }

  Future<void> _handlePostUpdated({
    required String postId,
    required String title,
    required String description,
    required String userId,
  }) async {
    // Find the original event for potential rollback
    final originalIndex = state.events.indexWhere((e) => e.id == postId);
    if (originalIndex == -1) {
      emit(state.copyWith(
        postError: 'Unable to find post to update.',
      ));
      return;
    }
    final originalEvent = state.events[originalIndex];

    // OPTIMISTIC UPDATE: Update the event in UI immediately
    final optimisticEvent = _createUpdatedEvent(
      original: originalEvent,
      title: title,
      description: description,
      userId: userId,
    );
    final optimisticEvents = List<Event>.from(state.events);
    optimisticEvents[originalIndex] = optimisticEvent;

    emit(state.copyWith(
      events: optimisticEvents,
      pendingPostIds: {...state.pendingPostIds, postId},
    ));

    try {
      await _repository.updatePost(
        postId: postId,
        title: title,
        description: description,
        userId: userId,
      );

      // SUCCESS: Remove from pending set
      emit(state.copyWith(
        pendingPostIds: Set.from(state.pendingPostIds)..remove(postId),
      ));
    } catch (e) {
      // FAILURE: Rollback to original event and show error
      final rollbackEvents = List<Event>.from(state.events);
      final currentIndex = rollbackEvents.indexWhere((e) => e.id == postId);
      if (currentIndex != -1) {
        rollbackEvents[currentIndex] = originalEvent;
      }

      emit(state.copyWith(
        events: rollbackEvents,
        pendingPostIds: Set.from(state.pendingPostIds)..remove(postId),
        postError: 'Unable to update post. Please try again.',
      ));
    }
  }

  /// Create an updated Event object for optimistic display
  Event _createUpdatedEvent({
    required Event original,
    required String title,
    required String description,
    required String userId,
  }) {
    final now = DateTime.now().toUtc();
    final originalMetadata = original.metadata ?? {};

    final eventData = {
      'id': original.id,
      'organizationId': original.organizationId,
      'eventTypeId': original.eventTypeId,
      'scope': 'community',
      'recordId': original.recordId,
      'recordModelType': original.recordModelType,
      'title': title,
      'description': description,
      'notes': description,
      'createdAt': original.createdAt,
      'createdById': original.createdById,
      'createdByName': originalMetadata['createdByName'] ?? '',
      'updatedAt': now.toIso8601String(),
      'updatedById': userId,
      'modelType': 'event',
      'urlPath': original.urlPath,
      'internalPath': original.internalPath,
      'slug': original.slug,
      'metadata': {
        ...originalMetadata,
        'title': title,
        'description': description,
        'isEdited': true,
      },
    };
    return RecordFactory.eventFromJson(eventData);
  }

  Future<void> _handlePostDeleted(String postId) async {
    final targetIndex = state.events.indexWhere((e) => e.id == postId);
    if (targetIndex == -1) {
      return;
    }

    final removedEvent = state.events[targetIndex];
    final updatedEvents = List<Event>.from(state.events)
      ..removeAt(targetIndex);

    final updatedPendingIds = Set<String>.from(state.pendingPostIds)
      ..remove(postId);

    emit(state.copyWith(
      events: updatedEvents,
      pendingPostIds: updatedPendingIds,
      postError: null,
    ));

    try {
      await _repository.deletePost(postId: postId);
    } catch (e) {
      final restoredEvents = List<Event>.from(state.events);
      final insertIndex = targetIndex.clamp(0, restoredEvents.length);
      restoredEvents.insert(insertIndex, removedEvent);
      emit(state.copyWith(
        events: restoredEvents,
        postError: 'Unable to remove post. Please try again.',
      ));
    }
  }

  Future<void> _enqueuePostMutation(Future<void> Function() action) {
    _postMutationQueue = _postMutationQueue.then((_) => action());
    return _postMutationQueue;
  }

  /// Batch creates multiple posts atomically with rollback on failure.
  ///
  /// All posts are committed to the server together. If any commit fails,
  /// all optimistically added events are rolled back to prevent duplicates
  /// on retry.
  ///
  /// This method ensures atomic behavior - either all posts are created
  /// successfully or none are (all-or-nothing semantics).
  Future<void> createPostsBatch({
    required List<BatchPostData> posts,
    required String organizationId,
    required String organizationName,
    required String userId,
    required String userName,
    String? communityChannelId,
  }) {
    return _enqueuePostMutation(
      () => _commitBatch(
        posts: posts,
        organizationId: organizationId,
        organizationName: organizationName,
        userId: userId,
        userName: userName,
        communityChannelId: communityChannelId,
      ),
    );
  }

  /// Internal batch commit with partial success handling.
  ///
  /// Strategy:
  /// - Track successfully committed posts separately from failures
  /// - On partial failure, refresh to show committed posts and report partial error
  /// - Never rollback already-committed posts (they exist on server)
  /// - Only rollback uncommitted optimistic events
  Future<void> _commitBatch({
    required List<BatchPostData> posts,
    required String organizationId,
    required String organizationName,
    required String userId,
    required String userName,
    String? communityChannelId,
  }) async {
    if (posts.isEmpty) return;

    // Generate temp IDs for all posts upfront
    final tempIds = <String>[];
    final optimisticEvents = <Event>[];

    for (final post in posts) {
      final tempId = 'temp_${_uuid.v4()}';
      tempIds.add(tempId);

      optimisticEvents.add(_createOptimisticEvent(
        tempId: tempId,
        title: post.title,
        description: post.description,
        organizationId: organizationId,
        organizationName: organizationName,
        userId: userId,
        userName: userName,
        communityChannelId: communityChannelId,
      ));
    }

    // Capture original state for potential rollback of uncommitted posts only
    final originalEvents = List<Event>.from(state.events);
    final originalPendingIds = Set<String>.from(state.pendingPostIds);

    // OPTIMISTIC UPDATE: Add all events at once
    emit(state.copyWith(
      events: [...optimisticEvents, ...state.events],
      pendingPostIds: {...state.pendingPostIds, ...tempIds},
    ));

    // Track commit progress
    int successCount = 0;
    String? errorMessage;

    // Commit posts to server, tracking successes
    try {
      for (var i = 0; i < posts.length; i++) {
        await _repository.createPost(
          title: posts[i].title,
          description: posts[i].description,
          organizationId: organizationId,
          organizationName: organizationName,
          userId: userId,
          userName: userName,
          communityChannelId: communityChannelId,
        );
        successCount++;
      }
    } catch (e) {
      // Partial or complete failure
      errorMessage = successCount > 0
          ? 'Created $successCount of ${posts.length} posts. Please retry remaining.'
          : 'Unable to create posts. Please try again.';
    }

    // Handle results based on success count
    if (successCount > 0) {
      // Some or all posts committed - remove their temp events and refresh
      // Get the temp IDs for successfully committed posts
      final committedTempIds = tempIds.sublist(0, successCount);
      final uncommittedTempIds = tempIds.sublist(successCount);

      // Remove committed temp events from pending set
      emit(state.copyWith(
        pendingPostIds: Set.from(state.pendingPostIds)
          ..removeAll(committedTempIds),
      ));

      // Remove committed optimistic events from display
      emit(state.copyWith(
        events: state.events
            .where((e) => !committedTempIds.contains(e.id))
            .toList(),
      ));

      // If there were uncommitted posts, remove their temp events too
      // (they failed, so rollback just those)
      if (uncommittedTempIds.isNotEmpty) {
        emit(state.copyWith(
          events: state.events
              .where((e) => !uncommittedTempIds.contains(e.id))
              .toList(),
          pendingPostIds: Set.from(state.pendingPostIds)
            ..removeAll(uncommittedTempIds),
        ));
      }

      // Refresh to get server-created posts
      // Handle refresh errors separately - don't rollback committed posts
      try {
        await refresh();
      } catch (refreshError) {
        // Refresh failed, but posts are on server
        // Show refresh-specific error, don't touch committed data
        emit(state.copyWith(
          postError: errorMessage ?? 'Posts created but refresh failed. Pull to refresh.',
        ));
        return;
      }

      // If there was a partial failure, show the error message
      if (errorMessage != null) {
        emit(state.copyWith(postError: errorMessage));
      }
    } else {
      // Complete failure - rollback all optimistic events
      emit(state.copyWith(
        events: originalEvents,
        pendingPostIds: originalPendingIds,
        postError: errorMessage,
      ));
    }
  }

  /// Create a local Event object for optimistic display
  Event _createOptimisticEvent({
    required String tempId,
    required String title,
    required String description,
    required String organizationId,
    required String organizationName,
    required String userId,
    required String userName,
    String? communityChannelId,
  }) {
    final now = DateTime.now().toUtc();
    final eventData = {
      'id': tempId,
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
      'urlPath': '/$organizationId/events/$tempId',
      'internalPath': 'organizations/$organizationId/events/$tempId',
      'slug': tempId,
      'metadata': {
        'isCommunityPost': true,
        'title': title,
        'description': description,
        'createdByName': userName,
        'createdByOrgName': organizationName,
        'createdByOrgId': organizationId,
        if (communityChannelId != null) 'communityChannelId': communityChannelId,
      },
    };
    return RecordFactory.eventFromJson(eventData);
  }

  bool _hasChannelFilter() {
    return _communityChannelId != null && _communityChannelId.isNotEmpty;
  }

  List<Event> _filterByChannel(List<Event> events) {
    if (!_hasChannelFilter()) return events;
    return events.where(_matchesChannel).toList();
  }

  bool _matchesChannel(Event event) {
    if (!_hasChannelFilter()) return true;
    final metadata = event.metadata;
    final channelId = metadata?['communityChannelId'];
    if (channelId == null) {
      return true;
    }
    if (channelId is String) {
      if (channelId.isEmpty) return true;
      return channelId == _communityChannelId;
    }
    return false;
  }
}

/// Data transfer object for batch post creation.
///
/// Contains the minimal data needed to create a community post
/// as part of a batch operation.
class BatchPostData {
  final String title;
  final String description;

  const BatchPostData({
    required this.title,
    required this.description,
  });
}
