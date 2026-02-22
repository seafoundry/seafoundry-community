// @tier: community
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/create_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/services/inventory_events/inventory_events_constants.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';
import 'package:seafoundry_app/widgets/spreadsheet/inventory/inventory_event_row.dart';

/// Service for filtering inventory events.
///
/// Provides utilities for determining which events should be included
/// in the inventory events spreadsheet based on event type, record type,
/// site type, and organism kind.
class InventoryEventsFilterService {
  const InventoryEventsFilterService();

  /// Returns true if the event type is relevant for the inventory spreadsheet.
  bool isRelevantEvent(Event event) {
    if (allowedEventTypeIds.contains(event.eventTypeId)) {
      return true;
    }
    return event is InventoryEvent;
  }

  /// Returns true if the record type is tracked in the inventory spreadsheet.
  bool isTrackedRecordType(ModelType? type) {
    if (type == null) return false;
    return type == ModelType.organismRecord ||
        type == ModelType.group ||
        type == ModelType.site;
  }

  /// Determines if an event row should be included in the spreadsheet.
  ///
  /// Filters based on:
  /// - Outplant events are always included
  /// - Tag groups are excluded
  /// - Nursery site events are included
  /// - Outplanting site events only include OutplantEvents
  bool shouldIncludeRow({
    required Event event,
    required InventoryEventRow row,
    required Map<String, Site> siteMetadata,
  }) {
    if (event is OutplantEvent) {
      return true;
    }

    if (event is CreateEvent) {
      final snapshot = event.snapshot;
      if (snapshot is Group && snapshot.groupTypeId == GroupType.tag.id) {
        return false;
      }
    }

    final siteId = row.siteId;
    if (siteId == null) {
      return true;
    }

    final site = siteMetadata[siteId];
    if (site == null) {
      return true;
    }

    if (nurserySiteTypeIds.contains(site.siteTypeId)) {
      return true;
    }

    if (site.siteTypeId == SiteType.outplanting.id) {
      return event is OutplantEvent;
    }

    return false;
  }

  /// Extracts the organism kind from event metadata.
  ///
  /// Falls back to [OrganismKind.coral] if no organism kind is specified.
  OrganismKind organismKindForEvent(Event event) {
    final metadata = event.metadata;
    if (metadata != null) {
      final candidate = metadata['organismKind'];
      if (candidate is String && candidate.isNotEmpty) {
        final normalized = candidate.toLowerCase();
        for (final kind in OrganismKind.values) {
          if (kind.name.toLowerCase() == normalized) {
            return kind;
          }
        }
      } else if (candidate is OrganismKind) {
        return candidate;
      }
    }
    return OrganismKind.coral;
  }

  /// Applies all spreadsheet filters to a list of hydrated rows.
  ///
  /// Filters by organism kind, event type, record type, site, permit status,
  /// and date range. Returns sorted results (newest first).
  ///
  /// Uses multiselect filters with OR logic - match ANY selected value.
  List<InventoryEventRow> applyFilters({
    required List<InventoryEventRow> rows,
    required OrganismKind organismFilter,
    Set<String> selectedEventTypeIds = const {},
    Set<String> selectedRecordTypeIds = const {},
    Set<String> selectedSiteIds = const {},
    String? permitFilter,
    DateTimeRange? selectedDateRange,
  }) {
    Iterable<InventoryEventRow> result = rows.where((row) {
      final kind = row.organismKind ?? OrganismKind.coral;
      return kind == organismFilter;
    });

    // Site filter - OR logic: match ANY selected site
    if (selectedSiteIds.isNotEmpty) {
      result = result.where(
        (row) => row.siteId != null && selectedSiteIds.contains(row.siteId),
      );
    }

    // Event type filter - OR logic: match ANY selected event type
    if (selectedEventTypeIds.isNotEmpty) {
      result = result.where(
        (row) => selectedEventTypeIds.contains(row.eventTypeId),
      );
    }

    // Record type filter - OR logic: match ANY selected record type
    if (selectedRecordTypeIds.isNotEmpty) {
      result = result.where(
        (row) =>
            row.recordModelType != null &&
            selectedRecordTypeIds.contains(row.recordModelType!.name),
      );
    }

    if (permitFilter == 'with') {
      result = result.where((row) => row.hasPermitMetadata);
    } else if (permitFilter == 'without') {
      result = result.where((row) => !row.hasPermitMetadata);
    }

    if (selectedDateRange != null) {
      final rangeStart = DateRangePresets.startOfDay(selectedDateRange.start);
      final rangeEnd = DateRangePresets.endOfDay(selectedDateRange.end);
      result = result.where((row) {
        final createdAt = row.createdAt;
        if (createdAt == null) return false;
        return !createdAt.isBefore(rangeStart) && !createdAt.isAfter(rangeEnd);
      });
    }

    return result
        .sorted((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        })
        .toList(growable: false);
  }
}
