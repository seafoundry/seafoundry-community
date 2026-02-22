// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';

/// Sentinel value to distinguish between "not provided" and "explicitly null"
const _sentinel = Object();

/// Immutable state for the community events feed.
///
/// Tracks the list of events, loading state, pagination state, error state,
/// and optional event type filters. Fields:
/// - [events]: The currently loaded list of events
/// - [isLoading]: Whether a fetch operation is in progress
/// - [hasMore]: Whether more events are available for pagination
/// - [error]: Error message if the last operation failed
/// - [filterTypes]: Optional set of event types to filter by (null means show all)
///
/// Uses a sentinel pattern in [copyWith] to distinguish between "not updating"
/// and "explicitly setting to null" for the [error] field.
class CommunityEventsState extends Equatable {
  final List<Event> events;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final Set<EventType>? filterTypes;
  /// Available event types from the initial unfiltered load
  /// Used to populate filter chips without shrinking as filters are applied
  final Set<EventType>? availableEventTypes;
  /// IDs of posts that are optimistically displayed but not yet confirmed by server
  /// Used to show subtle "posting..." indicator on pending posts
  final Set<String> pendingPostIds;
  /// Error specific to post creation (separate from feed loading errors)
  /// Used to show snackbar only for post failures, not feed loading failures
  final String? postError;
  /// Error specific to reaction updates
  final String? reactionError;

  const CommunityEventsState({
    this.events = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.filterTypes,
    this.availableEventTypes,
    this.pendingPostIds = const {},
    this.postError,
    this.reactionError,
  });

  CommunityEventsState copyWith({
    List<Event>? events,
    bool? isLoading,
    bool? hasMore,
    Object? error = _sentinel,
    Object? filterTypes = _sentinel,
    Object? availableEventTypes = _sentinel,
    Set<String>? pendingPostIds,
    Object? postError = _sentinel,
    Object? reactionError = _sentinel,
  }) {
    return CommunityEventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
      filterTypes: filterTypes == _sentinel ? this.filterTypes : filterTypes as Set<EventType>?,
      availableEventTypes: availableEventTypes == _sentinel ? this.availableEventTypes : availableEventTypes as Set<EventType>?,
      pendingPostIds: pendingPostIds ?? this.pendingPostIds,
      postError: postError == _sentinel ? this.postError : postError as String?,
      reactionError:
          reactionError == _sentinel ? this.reactionError : reactionError as String?,
    );
  }

  /// Check if a specific post is still pending server confirmation
  bool isPostPending(String postId) => pendingPostIds.contains(postId);

  @override
  List<Object?> get props => [
        events,
        isLoading,
        hasMore,
        error,
        filterTypes,
        availableEventTypes,
        pendingPostIds,
        postError,
        reactionError,
      ];
}
