// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Immutable filter configuration shared across spreadsheet cubits.
///
/// Consolidates common filtering fields used by monitoring entries, outplant events,
/// inventory, and other spreadsheet views. Supports both cubit-level and widget-level
/// filters (widget filters override cubit filters for synchronized UI state).
class SpreadsheetFilters extends Equatable {
  const SpreadsheetFilters({
    this.organismFilter,
    this.siteId,
    this.speciesId,
    this.genetId,
    this.structureId,
    this.lifeStageId,
    this.provenanceTypeId,
    this.dateRange,
    this.searchTerm,
    this.outplantEventId,
    this.permitFilter,
    this.eventName,
  });

  /// Filter by organism type (coral, oyster, kelp, etc.)
  final OrganismKind? organismFilter;

  /// Filter by site ID
  final String? siteId;

  /// Filter by species ID
  final String? speciesId;

  /// Filter by genet/provenance ID
  final String? genetId;

  /// Filter by structure path (e.g., "nursery/tank/rack")
  final String? structureId;

  /// Filter by life stage ID
  final String? lifeStageId;

  /// Filter by provenance type ID
  final String? provenanceTypeId;

  /// Filter by date range
  final DateTimeRange? dateRange;

  /// Text search filter (searches across multiple fields)
  final String? searchTerm;

  /// Filter by outplant event ID (monitoring-specific)
  final String? outplantEventId;

  /// Filter by permit status: null (all), 'with', or 'without'
  final String? permitFilter;

  /// Filter by event name (outplant-specific)
  final String? eventName;

  /// Creates a copy with updated fields (immutable update pattern)
  SpreadsheetFilters copyWith({
    OrganismKind? organismFilter,
    String? siteId,
    String? speciesId,
    String? genetId,
    String? structureId,
    String? lifeStageId,
    String? provenanceTypeId,
    DateTimeRange? dateRange,
    String? searchTerm,
    String? outplantEventId,
    String? permitFilter,
    String? eventName,
    bool clearOrganism = false,
    bool clearSite = false,
    bool clearSpecies = false,
    bool clearGenet = false,
    bool clearStructure = false,
    bool clearLifeStage = false,
    bool clearProvenanceType = false,
    bool clearDateRange = false,
    bool clearSearch = false,
    bool clearOutplantEvent = false,
    bool clearPermit = false,
    bool clearEventName = false,
  }) {
    return SpreadsheetFilters(
      organismFilter: clearOrganism ? null : (organismFilter ?? this.organismFilter),
      siteId: clearSite ? null : (siteId ?? this.siteId),
      speciesId: clearSpecies ? null : (speciesId ?? this.speciesId),
      genetId: clearGenet ? null : (genetId ?? this.genetId),
      structureId: clearStructure ? null : (structureId ?? this.structureId),
      lifeStageId: clearLifeStage ? null : (lifeStageId ?? this.lifeStageId),
      provenanceTypeId: clearProvenanceType ? null : (provenanceTypeId ?? this.provenanceTypeId),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      searchTerm: clearSearch ? null : (searchTerm ?? this.searchTerm),
      outplantEventId: clearOutplantEvent ? null : (outplantEventId ?? this.outplantEventId),
      permitFilter: clearPermit ? null : (permitFilter ?? this.permitFilter),
      eventName: clearEventName ? null : (eventName ?? this.eventName),
    );
  }

  /// Resets all filters to null
  SpreadsheetFilters clear() {
    return const SpreadsheetFilters();
  }

  /// Returns true if any filter is active (non-null)
  bool get hasActiveFilters {
    return organismFilter != null ||
        siteId != null ||
        speciesId != null ||
        genetId != null ||
        structureId != null ||
        lifeStageId != null ||
        provenanceTypeId != null ||
        dateRange != null ||
        searchTerm != null ||
        outplantEventId != null ||
        permitFilter != null ||
        eventName != null;
  }

  /// Serializes to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      if (organismFilter != null) 'organismFilter': organismFilter!.name,
      if (siteId != null) 'siteId': siteId,
      if (speciesId != null) 'speciesId': speciesId,
      if (genetId != null) 'genetId': genetId,
      if (structureId != null) 'structureId': structureId,
      if (lifeStageId != null) 'lifeStageId': lifeStageId,
      if (provenanceTypeId != null) 'provenanceTypeId': provenanceTypeId,
      if (dateRange != null) 'dateRange': {
        'start': dateRange!.start.toIso8601String(),
        'end': dateRange!.end.toIso8601String(),
      },
      if (searchTerm != null) 'searchTerm': searchTerm,
      if (outplantEventId != null) 'outplantEventId': outplantEventId,
      if (permitFilter != null) 'permitFilter': permitFilter,
      if (eventName != null) 'eventName': eventName,
    };
  }

  /// Deserializes from JSON
  factory SpreadsheetFilters.fromJson(Map<String, dynamic> json) {
    DateTimeRange? dateRange;
    final dateRangeJson = json['dateRange'];
    if (dateRangeJson is Map<String, dynamic>) {
      final start = DateTime.tryParse(dateRangeJson['start'] as String? ?? '');
      final end = DateTime.tryParse(dateRangeJson['end'] as String? ?? '');
      if (start != null && end != null) {
        dateRange = DateTimeRange(start: start, end: end);
      }
    }

    return SpreadsheetFilters(
      organismFilter: OrganismKindX.tryParse(json['organismFilter'] as String?),
      siteId: json['siteId'] as String?,
      speciesId: json['speciesId'] as String?,
      genetId: json['genetId'] as String?,
      structureId: json['structureId'] as String?,
      lifeStageId: json['lifeStageId'] as String?,
      provenanceTypeId: json['provenanceTypeId'] as String?,
      dateRange: dateRange,
      searchTerm: json['searchTerm'] as String?,
      outplantEventId: json['outplantEventId'] as String?,
      permitFilter: json['permitFilter'] as String?,
      eventName: json['eventName'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    organismFilter,
    siteId,
    speciesId,
    genetId,
    structureId,
    lifeStageId,
    provenanceTypeId,
    dateRange,
    searchTerm,
    outplantEventId,
    permitFilter,
    eventName,
  ];
}
