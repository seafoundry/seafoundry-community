// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/inventory_events/inventory_events_filter_service.dart';
import 'package:seafoundry_app/services/inventory_hydration/inventory_event_hydration_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/inventory/inventory_event_row.dart';

/// Callback for progress updates during batch hydration.
typedef HydrationProgressCallback = void Function(int hydratedCount, int total);

/// Result of batch hydration containing hydrated rows.
class BatchHydrationResult {
  const BatchHydrationResult({required this.rows});
  final List<InventoryEventRow> rows;
}

/// Service for batch hydrating inventory events.
///
/// Processes events in batches with progress callbacks and filters
/// to produce hydrated rows suitable for spreadsheet display.
class BatchHydrationService {
  const BatchHydrationService({
    this.batchSize = 20,
  });

  final int batchSize;

  static const _filterService = InventoryEventsFilterService();
  static const _hydrationService = InventoryEventHydrationService();

  /// Hydrates a list of events in batches.
  ///
  /// Calls [onProgress] after each batch to allow UI updates.
  /// Checks [isClosed] before each batch to allow early termination.
  Future<BatchHydrationResult> hydrateEvents({
    required List<Event> events,
    required Map<String, Group> groupLookup,
    required Map<String, String> siteLookup,
    required Map<String, Site> siteMetadata,
    required Map<String, String> eventTypeLabels,
    required Future<String> Function(String) resolveUserName,
    required Future<ResolvedRecordInfo?> Function({
      required ModelType? modelType,
      required String? recordId,
      required Map<String, Group> groupLookup,
      required Map<String, String> siteLookup,
      required Map<String, OrganismRecord?> organismCache,
      required Map<String, Genet?> genetCache,
      required String? organizationId,
      required bool Function() isClosed,
    }) resolveRecordReference,
    required String? organizationDomain,
    required bool Function() isClosed,
    HydrationProgressCallback? onProgress,
  }) async {
    final filtered = <InventoryEventRow>[];
    final organismCache = <String, OrganismRecord?>{};
    final genetCache = <String, Genet?>{};
    var hydratedCount = 0;

    for (var i = 0; i < events.length; i += batchSize) {
      if (isClosed()) break;

      final batch = events.skip(i).take(batchSize).toList();
      final batchRows = await Future.wait(
        batch.map((event) => _hydrateEvent(
              event: event,
              groupLookup: groupLookup,
              siteLookup: siteLookup,
              siteMetadata: siteMetadata,
              eventTypeLabels: eventTypeLabels,
              resolveUserName: resolveUserName,
              resolveRecordReference: resolveRecordReference,
              organismCache: organismCache,
              genetCache: genetCache,
              organizationDomain: organizationDomain,
              isClosed: isClosed,
            )),
      );

      filtered.addAll(batchRows.whereType<InventoryEventRow>());
      hydratedCount += batch.length;

      onProgress?.call(hydratedCount, events.length);
    }

    return BatchHydrationResult(rows: filtered);
  }

  Future<InventoryEventRow?> _hydrateEvent({
    required Event event,
    required Map<String, Group> groupLookup,
    required Map<String, String> siteLookup,
    required Map<String, Site> siteMetadata,
    required Map<String, String> eventTypeLabels,
    required Future<String> Function(String) resolveUserName,
    required Future<ResolvedRecordInfo?> Function({
      required ModelType? modelType,
      required String? recordId,
      required Map<String, Group> groupLookup,
      required Map<String, String> siteLookup,
      required Map<String, OrganismRecord?> organismCache,
      required Map<String, Genet?> genetCache,
      required String? organizationId,
      required bool Function() isClosed,
    }) resolveRecordReference,
    required Map<String, OrganismRecord?> organismCache,
    required Map<String, Genet?> genetCache,
    required String? organizationDomain,
    required bool Function() isClosed,
  }) async {
    try {
      final eventOrganism = _filterService.organismKindForEvent(event);
      final row = await _hydrationService.hydrateEvent(
        event: event,
        groupLookup: groupLookup,
        siteLookup: siteLookup,
        eventTypeLabels: eventTypeLabels,
        resolveUserName: resolveUserName,
        resolveRecordReference: (modelType, recordId) => resolveRecordReference(
          modelType: modelType,
          recordId: recordId,
          groupLookup: groupLookup,
          siteLookup: siteLookup,
          organismCache: organismCache,
          genetCache: genetCache,
          organizationId: event.organizationId,
          isClosed: isClosed,
        ),
        organismKind: eventOrganism,
        organizationDomain: organizationDomain,
      );

      if (row != null &&
          _filterService.shouldIncludeRow(
            event: event,
            row: row,
            siteMetadata: siteMetadata,
          )) {
        return row;
      }
      return null;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to hydrate inventory event ${event.id}',
        error,
        stackTrace,
      );
      return null;
    }
  }
}
