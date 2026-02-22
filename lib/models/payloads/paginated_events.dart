// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/events/event.dart';

/// Result of a paginated event query with a cursor for the next page.
class PaginatedEvents {
  final List<Event> events;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedEvents({
    required this.events,
    this.lastDocument,
    required this.hasMore,
  });
}
