// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/status_event_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for loading and parsing inventory events from Firestore.
///
/// Encapsulates query building, event parsing, and event type label resolution.
class InventoryEventsLoaderService {
  const InventoryEventsLoaderService();

  /// Builds the Firestore query for fetching inventory events.
  Query<Map<String, dynamic>> buildQuery({
    required FirebaseFirestore db,
    required String organizationId,
    required int limit,
  }) {
    return FirestoreCollectionResolver.instance
        .collection(db, ModelType.event.collectionPath)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  /// Parses Firestore documents into Event objects.
  ///
  /// Logs errors for individual parsing failures but continues processing.
  List<Event> parseEvents(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final events = <Event>[];
    for (final doc in snapshot.docs) {
      final json = doc.data();
      try {
        events.add(RecordFactory.eventFromJson(json));
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to parse inventory event ${json['id'] ?? 'unknown'}',
          error,
          stackTrace,
        );
      }
    }
    return events;
  }

  /// Builds the event type labels map from all event type enums.
  ///
  /// Combines labels from [EventType], [InventoryEventType], and
  /// [StatusEventType] builtins.
  Map<String, String> buildEventTypeLabels() {
    return <String, String>{}
      ..addAll(
        EventType.builtins.map((key, value) => MapEntry(key, value.name)),
      )
      ..addAll(
        InventoryEventType.builtins.map(
          (key, value) => MapEntry(key, value.name),
        ),
      )
      ..addAll(
        StatusEventType.builtins.map(
          (key, value) => MapEntry(key, value.name),
        ),
      );
  }
}
