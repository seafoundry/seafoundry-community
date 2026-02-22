// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';

/// Specialized [EventRepository] that exposes helpers for creating events that
/// automatically include organism metadata (organism kind, provenance details,
/// additional validation context). This lets dialog/services create ad-hoc
/// events without duplicating the metadata plumbing that already exists in the
/// core repository methods.
class OrganismAwareEventRepository extends EventRepository {
  OrganismAwareEventRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
  });

  /// Persists [event] after enriching it with organism metadata. Callers can
  /// optionally provide [additionalMetadata] that is merged with the canonical
  /// payload before the document is written.
  Future<T> createOrganismEvent<T extends Event>(
    T event, {
    WriteBatch? batch,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final enriched = withOrganismMetadata(
      event,
      additionalMetadata: additionalMetadata,
    );

    await createEvent(enriched, batch: batch);

    return enriched;
  }

  /// Persists a collection of events inside a single batched write. Each event
  /// is enriched with organism metadata prior to being added to the batch.
  Future<List<T>> createOrganismEvents<T extends Event>(
    Iterable<T> events, {
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final batch = firestore.batch();
    final enriched = events
        .map(
          (event) => withOrganismMetadata(
            event,
            additionalMetadata: additionalMetadata,
          ),
        )
        .toList();

    for (final event in enriched) {
      await createEvent(event, batch: batch);
    }

    await batch.commit();
    return enriched;
  }
}
