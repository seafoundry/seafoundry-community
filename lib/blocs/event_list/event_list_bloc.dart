// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/events/event.dart';
import '../../models/events/task_event.dart';
import '../../models/types/event_type.dart';

class EventListBloc extends Cubit<EventListState> {
  static List<Event> _sortEvents(List<Event> events) {
    final sorted = List<Event>.from(events);
    sorted.sort((a, b) {
      final dateA = _eventSortTimestamp(a);
      final dateB = _eventSortTimestamp(b);
      return dateB.compareTo(dateA);
    });
    return sorted;
  }

  static DateTime _eventSortTimestamp(Event event) {
    if (event is TaskEvent && event.completedAt != null) {
      return event.completedAt!;
    }
    return DateTime.tryParse(event.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static bool _isCommunityPost(Event event) {
    return event.metadata?['isCommunityPost'] == true;
  }

  static bool _isCommentOrPost(Event event) {
    return event.eventTypeId == EventType.comment.id || _isCommunityPost(event);
  }

  static EventType _filterKeyForEvent(Event event) {
    if (_isCommentOrPost(event)) {
      return EventType.commentsAndPosts;
    }
    return event.eventType;
  }

  factory EventListBloc({
    required List<Event> events,
    Map<EventType, bool>? initialFilters,
  }) {
    final sortedEvents = _sortEvents(events);

    final eventTypes = sortedEvents
        .map(_filterKeyForEvent)
        .toSet()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final initialFilterById = initialFilters != null
        ? {
            for (final entry in initialFilters.entries) entry.key.id: entry.value,
          }
        : null;

    final filters = Map<EventType, bool>.fromEntries(
      eventTypes.map(
        (eventType) => MapEntry(
          eventType,
          initialFilterById?[eventType.id] ?? true,
        ),
      ),
    );

    final filteredEvents = sortedEvents
        .where((event) => filters[_filterKeyForEvent(event)] ?? true)
        .toList(growable: false);

    final initialState = EventListState(
      filters: filters,
      filteredEvents: filteredEvents,
    );
    return EventListBloc._(events: sortedEvents, initialState: initialState);
  }

  EventListBloc._({required List<Event> events, required EventListState initialState})
    : _events = events,
      super(initialState);

  List<Event> _events;

  void toggleFilter(EventType eventType) {
    final updatedFilters = Map<EventType, bool>.from(state.filters);
    updatedFilters[eventType] = !(updatedFilters[eventType] ?? true);

    final filteredEvents = _events
        .where((event) => updatedFilters[_filterKeyForEvent(event)] ?? true)
        .toList();

    emit(state.copyWith(filters: updatedFilters, filteredEvents: filteredEvents));
  }

  void setAllFilters(bool enabled) {
    final updatedFilters = Map<EventType, bool>.from(state.filters);
    for (final key in updatedFilters.keys) {
      updatedFilters[key] = enabled;
    }

    final filteredEvents = enabled ? _events : <Event>[];

    emit(state.copyWith(filters: updatedFilters, filteredEvents: filteredEvents));
  }

  void updateEvents(List<Event> events) {
    _events = _sortEvents(events);

    final newEventTypes = _events.map(_filterKeyForEvent).toSet().toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final updatedFilters = <EventType, bool>{};
    for (final eventType in newEventTypes) {
      updatedFilters[eventType] = state.filters[eventType] ?? true;
    }

    final filteredEvents = _events
        .where((event) => updatedFilters[_filterKeyForEvent(event)] ?? true)
        .toList(growable: false);

    emit(state.copyWith(filters: updatedFilters, filteredEvents: filteredEvents));
  }
}

class EventListState extends Equatable {
  const EventListState({required this.filters, required this.filteredEvents});

  final Map<EventType, bool> filters;
  final List<Event> filteredEvents;

  EventListState copyWith({Map<EventType, bool>? filters, List<Event>? filteredEvents}) {
    return EventListState(filters: filters ?? this.filters, filteredEvents: filteredEvents ?? this.filteredEvents);
  }

  @override
  List<Object?> get props => [filters, filteredEvents];
}
