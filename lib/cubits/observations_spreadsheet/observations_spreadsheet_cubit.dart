// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/events/events.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/location_display_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';

part 'observations_spreadsheet_state.dart';

class ObservationsSpreadsheetCubit extends Cubit<ObservationsSpreadsheetState> {
  ObservationsSpreadsheetCubit({
    required RecordRepository recordRepository,
    OrganismRecordRepository? organismRepository,
    required String organizationId,
    String? organizationDomain,
    String? structureFilter,
    String? speciesFilter,
    String? genetFilter,
    OrganismKind organismKind = OrganismKind.coral,
  }) : _recordRepository = recordRepository,
       _organismRepository = organismRepository,
       _organizationId = organizationId,
       _organizationDomain = organizationDomain,
       super(
         ObservationsSpreadsheetState(
           selectedStructureIds: structureFilter != null ? {structureFilter} : {},
           selectedSpeciesIds: speciesFilter != null ? {speciesFilter} : {},
           selectedGenetIds: genetFilter != null ? {genetFilter} : {},
           organismFilter: organismKind,
         ),
       ) {
    initialize();
  }

  final RecordRepository _recordRepository;
  final OrganismRecordRepository? _organismRepository;
  final String _organizationId;
  final String? _organizationDomain;

  Future<void> initialize() async {
    await _initializeLookups();
  }

  Future<void> _initializeLookups() async {
    final speciesMap = SpeciesRegistry.globalMap();
    final speciesLookup = {
      for (final entry in speciesMap.entries)
        entry.key: '${entry.value.genus} ${entry.value.species}',
    };

    emit(state.copyWith(isLoadingGenets: true, speciesLookup: speciesLookup));

    try {
      // Query genets and sites scoped to this organization
      final db = _recordRepository.db;
      final resolver = FirestoreCollectionResolver.instance;
      final genetsFuture = resolver
          .subcollection(
            db,
            'organizations',
            _organizationId,
            ModelType.genet.collectionPath,
          )
          .get()
          .then((qs) => qs.docs
              .map((d) => RecordFactory.recordFromJson<Genet>(d.data()))
              .toList());
      final sitesFuture = resolver
          .collection(db, ModelType.site.collectionPath)
          .where('organizationId', isEqualTo: _organizationId)
          .get()
          .then((qs) => qs.docs
              .map((d) => RecordFactory.recordFromJson<Site>(d.data()))
              .toList());
      final genets = await genetsFuture;
      final sites = await sitesFuture;

      String genetLabel(Genet genet) {
        final name = genet.name.trim();
        if (name.isNotEmpty) return name;
        final clonalId = ClonalIdDisplayService.resolveForGenet(genet);
        if (clonalId != null) return clonalId;
        return genet.id;
      }

      final genetLookup = {
        for (final genet in genets) genet.id: genetLabel(genet),
      };
      final genetRecords = {for (final genet in genets) genet.id: genet};
      final siteLookup = {for (final site in sites) site.id: site.name};

      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingGenets: false,
          genetLookup: genetLookup,
          genetRecords: genetRecords,
          siteLookup: siteLookup,
        ),
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        LoggingService.instance.warning(
          'Permission denied loading genets for observations filter: ${e.message}',
        );
        if (isClosed) return;
        emit(
          state.copyWith(
            isLoadingGenets: false,
            errorMessage:
                'You do not have permission to view observations data.',
          ),
        );
        return;
      }
      LoggingService.instance.error(
        'Failed to load genets for observations filter',
        e,
        stackTrace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingGenets: false,
          errorMessage: 'Failed to load initial data: $e',
        ),
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load genets for observations filter',
        error,
        stackTrace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingGenets: false,
          errorMessage: 'Failed to load initial data: $error',
        ),
      );
    }
  }

  Future<PageResult<Map<String, dynamic>>> loadObservations({
    required int pageSize,
    PageCursor? startAfter,
    String? sortField,
    bool descending = true,
  }) async {
    try {
      final db = _recordRepository.db;
      final isCoralOrganism = state.organismFilter == OrganismKind.coral;

      // Define all observation event types
      const observationEventTypes = [
        'event_observation',
        'event_disease_observation',
        'event_biofouling_observation',
        'event_pest_observation',
        'event_thermal_stress_observation',
        'event_discoloration_observation',
        'event_maintenance_required_observation',
      ];

      var query = FirestoreCollectionResolver.instance
          .collection(db, ModelType.event.collectionPath)
          .where('organizationId', isEqualTo: _organizationId)
          .where('eventTypeId', whereIn: observationEventTypes);

      // Apply sorting
      final field = sortField ?? 'createdAt';
      query = query.orderBy(field, descending: descending);

      final dateRange = state.selectedDateRange;
      if (dateRange != null) {
        final startUtc = dateRange.start.isUtc
            ? dateRange.start
            : DateTime.utc(
                dateRange.start.year,
                dateRange.start.month,
                dateRange.start.day,
              );
        final endUtc = dateRange.end.isUtc
            ? dateRange.end
            : DateTime.utc(
                dateRange.end.year,
                dateRange.end.month,
                dateRange.end.day,
                23,
                59,
                59,
                999,
              );
        query = query
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: startUtc.toIso8601String(),
            )
            .where(
              'createdAt',
              isLessThanOrEqualTo: endUtc.toIso8601String(),
            );
      }

      // Apply pagination
      if (startAfter != null && startAfter is DocumentSnapshot) {
        query = query.startAfterDocument(startAfter);
      }

      // Limit
      query = query.limit(pageSize);

      final qs = await query.get();
      final allEvents = qs.docs
          .map((d) => RecordFactory.eventFromJson(d.data()))
          .toList();

      // No need to filter by type in memory anymore as we use whereIn
      final observations = allEvents;

      final targetOrganism = state.organismFilter;
      // Check if type is an organism record
      bool isOrganismType(ModelType? type) =>
          type == ModelType.organismRecord;

      final organismFiltered = observations.where((event) {
        final metadataKind = _metadataString(event, 'organismKind');
        if (metadataKind != null) {
          return metadataKind.toLowerCase() == targetOrganism.name;
        }
        return targetOrganism == OrganismKind.coral &&
            isOrganismType(event.recordModelType);
      }).toList();

      // Update dynamic filter options
      final structureIds = organismFiltered
          .map((obs) => obs.urlPath)
          .where((path) => path.isNotEmpty)
          .toSet();

      final organismCache = Map<String, OrganismRecord>.from(state.coralCache);
      final organismIds = <String>{};
      if (isCoralOrganism) {
        organismIds.addAll(
          organismFiltered
              .where(
                (event) =>
                    isOrganismType(event.recordModelType) &&
                    event.recordId.isNotEmpty,
              )
              .map((event) => event.recordId)
              .toSet(),
        );

        final missingOrganismIds = organismIds
            .where((id) => !organismCache.containsKey(id))
            .toList();
        if (missingOrganismIds.isNotEmpty) {
          final fetchedOrganisms = await Future.wait(
            missingOrganismIds.map((id) async {
              try {
                // Use OrganismRecordRepository if available
                if (_organismRepository != null) {
                  return await _organismRepository.getRecordForId(id);
                }
                return null;
              } catch (error, stackTrace) {
                LoggingService.instance.error(
                  'Failed to load organism $id for observations spreadsheet',
                  error,
                  stackTrace,
                );
                return null;
              }
            }),
          );

          for (var i = 0; i < missingOrganismIds.length; i++) {
            final organism = fetchedOrganisms[i];
            if (organism != null) {
              organismCache[missingOrganismIds[i]] = organism;
            }
          }
        }
      }

      // Load missing genets
      final genetRecords = Map<String, Genet>.from(state.genetRecords);
      final genetLookup = Map<String, String>.from(state.genetLookup);
      final genetIdsFromOrganisms = isCoralOrganism
          ? organismIds
                .map((id) { final o = organismCache[id]; return o != null ? GenetIdResolver.resolve(o) : null; })
                .whereType<String>()
                .toSet()
          : <String>{};

      final missingGenetIds = genetIdsFromOrganisms
          .where((id) => !genetRecords.containsKey(id))
          .toList();
      if (missingGenetIds.isNotEmpty) {
        final fetchedGenets = await Future.wait(
          missingGenetIds.map((id) async {
            try {
              return await _recordRepository.getRecord<Genet>(
                ModelType.genet,
                id,
                organizationId: _organizationId,
              );
            } catch (error, stackTrace) {
              LoggingService.instance.error(
                'Failed to load genet $id for observations spreadsheet',
                error,
                stackTrace,
              );
              return null;
            }
          }),
        );

        for (var i = 0; i < missingGenetIds.length; i++) {
          final genet = fetchedGenets[i];
          if (genet != null) {
            genetRecords[missingGenetIds[i]] = genet;
            genetLookup.putIfAbsent(
              missingGenetIds[i],
              () {
                final name = genet.name.trim();
                if (name.isNotEmpty) return name;
                final clonalId = ClonalIdDisplayService.resolveForGenet(genet);
                if (clonalId != null) return clonalId;
                return genet.id;
              },
            );
          }
        }
      }

      // Collect dynamic filter IDs
      final siteIds = <String>{};
      final lifeStageIds = <String>{};
      final provenanceTypes = <String>{};
      final observationTypes = <String>{};

      for (final event in organismFiltered) {
        observationTypes.add(_getObservationType(event));
        final organism = organismCache[event.recordId];
        final genetId = organism != null ? GenetIdResolver.resolve(organism) : null;
        final genet = genetId != null ? genetRecords[genetId] : null;
        final resolvedSiteId = _resolveSiteId(event, organism);
        if (resolvedSiteId != null && resolvedSiteId.isNotEmpty) {
          siteIds.add(resolvedSiteId);
        }
        _collectFilterMetadata(
          event: event,
          organism: organism,
          genet: genet,
          lifeStageIds: lifeStageIds,
          provenanceTypes: provenanceTypes,
        );
      }

      // Load user names
      final userIdToName = Map<String, String>.from(state.userIdToName);
      final userIds = organismFiltered.map((o) => o.createdById).toSet();
      for (final userId in userIds) {
        if (userId.isEmpty || userIdToName.containsKey(userId)) continue;
        final displayName = await resolveUserDisplayName(
          recordRepository: _recordRepository,
          userId: userId,
          cache: userIdToName,
        );
        if (displayName.isNotEmpty) {
          userIdToName[userId] = displayName;
        }
      }

      // Apply filters - using OR logic within each filter (match ANY selected value)
      final filteredObservations = organismFiltered.where((obs) {
        // Structure filter - OR logic
        if (state.selectedStructureIds.isNotEmpty) {
          final matches = state.selectedStructureIds.any(
            (structureId) => _matchStructure(obs.urlPath, structureId),
          );
          if (!matches) return false;
        }

        final organism = organismCache[obs.recordId];
        final genetId = organism != null ? GenetIdResolver.resolve(organism) : null;
        final genet = genetId != null ? genetRecords[genetId] : null;
        final resolvedSiteId = _resolveSiteId(obs, organism);

        // Site filter - OR logic
        if (state.selectedSiteIds.isNotEmpty) {
          if (resolvedSiteId == null ||
              !state.selectedSiteIds.contains(resolvedSiteId)) {
            return false;
          }
        }

        if (isCoralOrganism) {
          // Life stage filter - OR logic
          if (state.selectedLifeStageIds.isNotEmpty) {
            final matches = state.selectedLifeStageIds.any(
              (lifeStageId) => _matchesLifeStageFilter(
                event: obs,
                organism: organism,
                genet: genet,
                requiredStageId: lifeStageId,
              ),
            );
            if (!matches) return false;
          }

          // Provenance type filter - OR logic
          if (state.selectedProvenanceTypeIds.isNotEmpty) {
            final matches = state.selectedProvenanceTypeIds.any(
              (provenanceTypeId) => _matchesProvenanceType(
                event: obs,
                genet: genet,
                organism: organism,
                requiredTypeId: provenanceTypeId,
              ),
            );
            if (!matches) return false;
          }
        }

        // Species filter - OR logic
        if (state.selectedSpeciesIds.isNotEmpty) {
          final resolvedSpeciesId = _resolveSpeciesId(obs, organism);
          if (resolvedSpeciesId == null ||
              !state.selectedSpeciesIds.contains(resolvedSpeciesId)) {
            return false;
          }
        }

        // Genet filter - OR logic
        if (state.selectedGenetIds.isNotEmpty) {
          final resolvedGenetId = genet?.id ?? _resolveGenetId(obs, organism);
          if (resolvedGenetId == null ||
              !state.selectedGenetIds.contains(resolvedGenetId)) {
            return false;
          }
        }

        // Observation type filter - OR logic
        if (state.selectedObservationTypes.isNotEmpty) {
          if (!state.selectedObservationTypes.contains(_getObservationType(obs))) {
            return false;
          }
        }

        return true;
      }).toList();

      // Convert to spreadsheet data
      final observationData = filteredObservations.map((obs) {
        final displayUser = userIdToName.containsKey(obs.createdById)
            ? userIdToName[obs.createdById]
            : obs.createdById;
        return {
          'timestamp': obs.createdAt,
          'user': displayUser,
          'location': LocationDisplayService.formatFromEvent(
            obs,
            organizationDomain: _organizationDomain,
            fallback: obs.urlPath,
          ),
          'record_id': obs.recordId,
          'observation_type': _getObservationType(obs),
          'old_health_status': obs is ObservationEvent
              ? (obs.oldHealthStatusEnum?.name ?? '')
              : '',
          'new_health_status': obs is ObservationEvent
              ? (obs.newHealthStatusEnum?.name ?? '')
              : '',
          'notes': _getComment(obs),
          'image_url': _getImageUrl(obs),
        };
      }).toList();

      // Sort by timestamp (newest first)
      observationData.sort(
        (a, b) => DateTime.parse(
          b['timestamp'] as String,
        ).compareTo(DateTime.parse(a['timestamp'] as String)),
      );

      // Update state with new caches and filter options
      if (isClosed) {
        return const PageResult<Map<String, dynamic>>(
          items: [],
          nextCursor: null,
          totalCount: 0,
        );
      }
      emit(
        state.copyWith(
          structureIds: structureIds,
          siteIds: siteIds,
          lifeStageIds: lifeStageIds,
          provenanceTypes: provenanceTypes,
          observationTypes: observationTypes,
          coralCache: organismCache,
          genetRecords: genetRecords,
          genetLookup: genetLookup,
          userIdToName: userIdToName,
        ),
      );

      final nextCursor = qs.docs.isNotEmpty ? qs.docs.last : null;

      return PageResult<Map<String, dynamic>>(
        items: observationData,
        nextCursor: nextCursor,
        totalCount: null,
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        LoggingService.instance.warning(
          'Permission denied loading observations: ${e.message}',
        );
        if (!isClosed) {
          emit(state.copyWith(
            errorMessage:
                'You do not have permission to view observations.',
          ));
        }
        return const PageResult<Map<String, dynamic>>(
          items: [],
          nextCursor: null,
          totalCount: 0,
        );
      }
      LoggingService.instance.error(
        'Failed to load observations',
        e,
        stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Failed to load observations: $e'));
      }
      return const PageResult<Map<String, dynamic>>(
        items: [],
        nextCursor: null,
        totalCount: 0,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load observations',
        e,
        stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Failed to load observations: $e'));
      }
      return const PageResult<Map<String, dynamic>>(
        items: [],
        nextCursor: null,
        totalCount: 0,
      );
    }
  }

  void applyFilters({
    Set<String>? structureIds,
    Set<String>? siteIds,
    Set<String>? speciesIds,
    Set<String>? genetIds,
    Set<String>? lifeStageIds,
    Set<String>? provenanceTypeIds,
    Set<String>? observationTypes,
    DateTimeRange? dateRange,
    bool clearDate = false,
    bool clearDownstreamFromSite = false,
    bool clearDownstreamFromStructure = false,
    bool clearDownstreamFromSpecies = false,
    bool clearDownstreamFromGenet = false,
    bool clearDownstreamFromLifeStage = false,
    bool clearDownstreamFromProvenanceType = false,
  }) {
    // Cascading filter clear logic
    var newStructureIds = structureIds ?? state.selectedStructureIds;
    var newSpeciesIds = speciesIds ?? state.selectedSpeciesIds;
    var newGenetIds = genetIds ?? state.selectedGenetIds;
    var newLifeStageIds = lifeStageIds ?? state.selectedLifeStageIds;
    var newProvenanceTypeIds = provenanceTypeIds ?? state.selectedProvenanceTypeIds;
    var newObservationTypes = observationTypes ?? state.selectedObservationTypes;

    if (clearDownstreamFromSite) {
      newStructureIds = {};
      newSpeciesIds = {};
      newGenetIds = {};
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
      newObservationTypes = {};
    } else if (clearDownstreamFromStructure) {
      newSpeciesIds = {};
      newGenetIds = {};
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
      newObservationTypes = {};
    } else if (clearDownstreamFromSpecies) {
      newGenetIds = {};
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
      newObservationTypes = {};
    } else if (clearDownstreamFromGenet) {
      newLifeStageIds = {};
      newProvenanceTypeIds = {};
      newObservationTypes = {};
    } else if (clearDownstreamFromLifeStage) {
      newProvenanceTypeIds = {};
      newObservationTypes = {};
    } else if (clearDownstreamFromProvenanceType) {
      newObservationTypes = {};
    }

    emit(
      state.copyWith(
        selectedStructureIds: newStructureIds,
        selectedSiteIds: siteIds ?? state.selectedSiteIds,
        selectedSpeciesIds: newSpeciesIds,
        selectedGenetIds: newGenetIds,
        selectedLifeStageIds: newLifeStageIds,
        selectedProvenanceTypeIds: newProvenanceTypeIds,
        selectedObservationTypes: newObservationTypes,
        selectedDateRange: clearDate
            ? null
            : dateRange ?? state.selectedDateRange,
        reloadToken: state.reloadToken + 1,
      ),
    );
  }

  void _collectFilterMetadata({
    required Event event,
    OrganismRecord? organism,
    Genet? genet,
    required Set<String> lifeStageIds,
    required Set<String> provenanceTypes,
  }) {
    final organismStage = _normalizeLifeStageId(
      organism?.metadata?['lifeStageId'] as String?,
    );
    if (organismStage != null) {
      lifeStageIds.add(organismStage);
    }
    final metadataStage = _normalizeLifeStageId(
      _metadataString(event, 'lifeStageId'),
    );
    if (metadataStage != null) {
      lifeStageIds.add(metadataStage);
    }
    final canonicalSelection = _deriveProvenanceSelection(
      organism: organism,
      genet: genet,
    );
    if (canonicalSelection != null) {
      lifeStageIds.add(canonicalSelection.lifeStage.id);
      provenanceTypes.add(canonicalSelection.provenanceType.metadata.id);
    }

    final metadataType = _normalizeProvenanceType(
      _metadataString(event, 'provenanceType'),
    );
    if (metadataType != null) {
      provenanceTypes.add(metadataType);
    }
    final provenanceType = _provenanceTypeFromGenet(genet);
    if (provenanceType != null) {
      provenanceTypes.add(provenanceType);
    }
  }

  bool _matchesLifeStageFilter({
    required Event event,
    OrganismRecord? organism,
    Genet? genet,
    required String requiredStageId,
  }) {
    final organismStage = _normalizeLifeStageId(
      organism?.metadata?['lifeStageId'] as String?,
    );
    final metadataStage = _normalizeLifeStageId(
      _metadataString(event, 'lifeStageId'),
    );
    return [
      organismStage,
      metadataStage,
      _deriveProvenanceSelection(organism: organism, genet: genet)
          ?.lifeStage
          .id,
    ].whereType<String>().any((value) => value == requiredStageId);
  }

  bool _matchesProvenanceType({
    required Event event,
    Genet? genet,
    OrganismRecord? organism,
    required String requiredTypeId,
  }) {
    final metadataType = _normalizeProvenanceType(
      _metadataString(event, 'provenanceType'),
    );
    final provenanceType = _provenanceTypeFromGenet(genet);
    return [
      metadataType,
      provenanceType,
      _deriveProvenanceSelection(organism: organism, genet: genet)
          ?.provenanceType
          .metadata
          .id,
    ].whereType<String>().any((value) => value == requiredTypeId);
  }

  String? _normalizeLifeStageId(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = LifeStageX.tryParse(value);
    return parsed?.id ?? value.trim();
  }

  String? _normalizeProvenanceType(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = ProvenanceTypeX.tryParse(value);
    return parsed?.id ?? value.trim();
  }

String? _provenanceTypeFromGenet(Genet? genet) {
  final kind = genet?.provenanceKind;
  if (kind == null) return null;
  final type = ProvenanceTypeX.fromLegacyKind(kind);
  return type?.id;
}

ProvenanceLifeStageSelection? _deriveProvenanceSelection({
  OrganismRecord? organism,
  Genet? genet,
}) {
  if (organism != null) {
    return buildProvenanceSelection(organism: organism, provenance: genet);
  }
  if (genet != null) {
    return ProvenanceLifeStageSelection.fromGenet(genet);
  }
  return null;
}

  static bool _matchStructure(String urlPath, String structureId) {
    return urlPath.contains(structureId);
  }

  static String _getObservationType(Event event) {
    if (event is ObservationEvent && event.isHealthStatusChange) {
      return 'Health Status Change';
    }
    switch (event.eventTypeId) {
      case 'event_disease_observation':
        return 'Disease Observation';
      case 'event_biofouling_observation':
        return 'Biofouling Observation';
      case 'event_pest_observation':
        return 'Pest Observation';
      case 'event_thermal_stress_observation':
        return 'Thermal Stress Observation';
      case 'event_discoloration_observation':
        return 'Discoloration Observation';
      case var id when id == EventType.maintenanceRequiredObservation.id:
        return 'Maintenance Required';
      default:
        return 'General Observation';
    }
  }

  static String _getComment(Event event) {
    if (event is ObservationEvent) {
      return event.comment ?? '';
    }
    final data = event.toJson();
    return data['comment'] ?? data['notes'] ?? '';
  }

  static String _getImageUrl(Event event) {
    if (event is ObservationEvent) {
      return event.imageUrl ?? '';
    }
    final data = event.toJson();
    return data['imageUrl'] ?? data['image_url'] ?? '';
  }

  void setOrganismFilter(OrganismKind kind) {
    if (state.organismFilter == kind) return;
    emit(
      state.copyWith(organismFilter: kind, reloadToken: state.reloadToken + 1),
    );
  }

  String? _metadataString(Event event, String key) {
    final metadata = event.metadata;
    if (metadata == null) return null;
    final value = metadata[key];
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final converted = value.toString().trim();
    return converted.isEmpty ? null : converted;
  }

  String? _resolveSiteId(Event event, OrganismRecord? organism) {
    final siteId = organism?.siteId;
    if (siteId != null && siteId.isNotEmpty) {
      return siteId;
    }
    return _metadataString(event, 'siteId');
  }

  String? _resolveSpeciesId(Event event, OrganismRecord? organism) {
    final speciesId = organism?.speciesId;
    if (speciesId != null && speciesId.isNotEmpty) {
      return speciesId;
    }
    return _metadataString(event, 'speciesId');
  }

  String? _resolveGenetId(Event event, OrganismRecord? organism) {
    final genetId = organism != null ? GenetIdResolver.resolve(organism) : null;
    if (genetId == null || genetId.isEmpty) return null;
    return genetId;
  }
}
