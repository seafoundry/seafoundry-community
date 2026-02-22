// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/cohort.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/organism_record_entry.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/organism_record_change_service.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Repository for managing neutral [Cohort] records within an organization.
///
/// Cohorts currently live under `organizations/{orgId}/cohorts` so the Firestore
/// document does not need to duplicate the organization identifier. Audit
/// metadata is still stored alongside the cohort payload so downstream tooling
/// (exports/migrations) can reason about authorship.
class CohortRepository {
  CohortRepository({
    required this.organization,
    required this.user,
    required FirebaseFirestore firestore,
    required EventRepository eventRepository,
    required OrganismRecordChangeService changeService,
    OrganismContext? organismContext,
    StructureCapacityService? structureCapacityService,
  })  : _firestore = firestore,
        _eventRepository = eventRepository,
        _changeService = changeService,
        organismContext =
            organismContext ?? OrganismContext.forKind(OrganismKind.coral),
        _structureCapacityService =
            structureCapacityService ?? StructureCapacityService.disabled(),
        _resolver = FirestoreCollectionResolver.instance,
        _groupsCollection = FirestoreCollectionResolver.instance
            .collection(firestore, ModelType.organization.collectionPath)
            .doc(organization.id)
            .collection('groups'),
        _organismRecordsCollection = FirestoreCollectionResolver.instance
            .collection(firestore, ModelType.organization.collectionPath)
            .doc(organization.id)
            .collection(ModelType.organismRecord.collectionPath);

  final FirebaseFirestore _firestore;
  final Organization organization;
  final User user;
  final OrganismContext organismContext;
  final EventRepository _eventRepository;
  final OrganismRecordChangeService _changeService;
  final StructureCapacityService _structureCapacityService;
  final FirestoreCollectionResolver _resolver;
  final CollectionReference<Map<String, dynamic>> _groupsCollection;
  final CollectionReference<Map<String, dynamic>>
      _organismRecordsCollection;

  CollectionReference<Map<String, dynamic>> get collectionRef => _resolver
      .collection(_firestore, ModelType.organization.collectionPath)
      .doc(organization.id)
      .collection('cohorts');

  Future<Cohort> createCohort({
    required Cohort cohort,
  }) async {
    final docId =
        cohort.id.isNotEmpty ? cohort.id : collectionRef.doc().id;
    await _ensureOccupantCapacity(cohort: cohort);
    final now = DateTimeConverter.nowAsIso8601String();
    final assigned = cohort.copyWith(id: docId);
    final payload = {
      ...assigned.toJson(),
      'createdAt': now,
      'createdById': user.id,
      'updatedAt': now,
      'updatedById': user.id,
    };

    await collectionRef.doc(docId).set(payload);
    await _upsertOrganismRecordDocument(
      cohort: assigned,
      timestamp: now,
      preserveExistingAudit: false,
    );
    return assigned;
  }

  Future<Cohort> updateCohort(
    Cohort cohort, {
    Map<String, dynamic>? eventMetadataOverrides,
  }) async {
    if (cohort.id.isEmpty) {
      throw ArgumentError('cohort.id cannot be empty when updating.');
    }
    final existing = await getCohort(cohort.id);
    if (existing == null) {
      throw StateError('Cohort ${cohort.id} does not exist.');
    }
    _changeService.assertImmutableFields(
      previous: existing.organismRecord,
      next: cohort.organismRecord,
    );
    await _ensureOccupantCapacity(cohort: cohort, previousCohort: existing);
    final changeSet = _changeService.detectChanges(
      previous: existing.organismRecord,
      next: cohort.organismRecord,
    );
    final now = DateTimeConverter.nowAsIso8601String();
    final payload = {
      ...cohort.toJson(),
      'updatedAt': now,
      'updatedById': user.id,
    };
    await collectionRef.doc(cohort.id).update(payload);
    await _upsertOrganismRecordDocument(
      cohort: cohort,
      timestamp: now,
      preserveExistingAudit: true,
    );
    if (changeSet.hasChanges) {
      await _emitOrganismRecordEvents(
        previous: existing,
        updated: cohort,
        changeSet: changeSet,
        metadataOverrides: eventMetadataOverrides,
      );
    }
    return cohort;
  }

  /// Applies [updatedOrganismRecord] to the provided [cohort], keeping the
  /// neutral axes in sync and emitting lifecycle/measurement events.
  Future<Cohort> updateOrganismRecord(
    Cohort cohort, {
    required OrganismRecord updatedOrganismRecord,
    Map<String, dynamic>? metadataOverrides,
    Map<String, dynamic>? eventMetadataOverrides,
  }) async {
    final aligned = cohort.alignWithOrganismRecord(
      updatedOrganismRecord,
      metadataOverrides: metadataOverrides,
    );
    return updateCohort(
      aligned,
      eventMetadataOverrides: eventMetadataOverrides,
    );
  }

  Future<void> deleteCohort(String cohortId) async {
    await collectionRef.doc(cohortId).delete();
    await _organismRecordsCollection.doc(cohortId).delete();
  }

  Future<Cohort?> getCohort(String cohortId) async {
    final snapshot = await collectionRef.doc(cohortId).get();
    if (!snapshot.exists) return null;
    return _cohortFromSnapshot(snapshot);
  }

  Future<List<Cohort>> fetchCohorts({
    OrganismKind? organismKind,
  }) async {
    Query<Map<String, dynamic>> query = collectionRef;
    if (organismKind != null) {
      query = query.where('organismKind', isEqualTo: organismKind.name);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(_cohortFromSnapshot).toList(growable: false);
  }

  Stream<List<Cohort>> streamCohorts({
    OrganismKind? organismKind,
  }) {
    Query<Map<String, dynamic>> query = collectionRef;
    if (organismKind != null) {
      query = query.where('organismKind', isEqualTo: organismKind.name);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(_cohortFromSnapshot)
              .toList(growable: false),
        );
  }

  Cohort _cohortFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cohort ${snapshot.id} is missing data.');
    }
    return Cohort.fromJson({
      'id': data['id'] ?? snapshot.id,
      ...data,
    });
  }

  Future<void> _emitOrganismRecordEvents({
    required Cohort previous,
    required Cohort updated,
    required OrganismRecordChangeSet changeSet,
    Map<String, dynamic>? metadataOverrides,
  }) async {
    final recordUrlPath = _organismRecordUrlPath(updated.id);
    final recordInternalPath = _organismRecordInternalPath(updated.id);
    final snapshot = updated.organismRecord;
    final metadata = _eventMetadataForCohort(updated);
    if (metadataOverrides != null && metadataOverrides.isNotEmpty) {
      metadata.addAll(metadataOverrides);
    }

    final lifeStageChange = changeSet.lifeStageChange;
    if (lifeStageChange != null) {
      await _eventRepository.createLifeStageTransitionEvent(
        recordId: updated.id,
        recordUrlPath: recordUrlPath,
        recordInternalPath: recordInternalPath,
        snapshot: snapshot,
        oldLifeStage: lifeStageChange.oldStage,
        newLifeStage: lifeStageChange.newStage,
        oldSubtype: lifeStageChange.oldSubtype,
        newSubtype: lifeStageChange.newSubtype,
        metadata: metadata,
      );
    }

    final physicalFormChange = changeSet.physicalFormChange;
    if (physicalFormChange != null) {
      await _eventRepository.createPhysicalFormChangeEvent(
        recordId: updated.id,
        recordUrlPath: recordUrlPath,
        recordInternalPath: recordInternalPath,
        snapshot: snapshot,
        oldFormId: physicalFormChange.oldFormId,
        newFormId: physicalFormChange.newFormId,
        metadata: metadata,
      );
    }

    final sizeChange = changeSet.sizeSpecChange;
    if (sizeChange != null) {
      await _eventRepository.createSizeChangeEvent(
        recordId: updated.id,
        recordUrlPath: recordUrlPath,
        recordInternalPath: recordInternalPath,
        snapshot: snapshot,
        oldSize: sizeChange.oldSize,
        newSize: sizeChange.newSize,
        metadata: metadata,
      );
    }

    final quantityChange = changeSet.quantityChange;
    if (quantityChange != null) {
      await _eventRepository.createQuantityChangeEvent(
        recordId: updated.id,
        recordUrlPath: recordUrlPath,
        recordInternalPath: recordInternalPath,
        snapshot: snapshot,
        oldMeasurement: quantityChange.oldMeasurement,
        newMeasurement: quantityChange.newMeasurement,
        metadata: metadata,
      );
    }
  }

  Map<String, dynamic> _eventMetadataForCohort(Cohort cohort) {
    return <String, dynamic>{
      'cohortId': cohort.id,
      'cohortName': cohort.name,
      'siteId': cohort.siteId,
      'groupId': cohort.groupId,
      'structureId': cohort.structureId,
    }..removeWhere((_, value) => value == null || (value is String && value.isEmpty));
  }

  Future<void> _upsertOrganismRecordDocument({
    required Cohort cohort,
    required String timestamp,
    required bool preserveExistingAudit,
  }) async {
    final docRef = _organismRecordsCollection.doc(cohort.id);
    final audit = await _resolveOrganismRecordAudit(
      docRef: docRef,
      fallbackTimestamp: timestamp,
      preserveExistingAudit: preserveExistingAudit,
    );
    final entry = OrganismRecordEntry(
      id: cohort.id,
      createdAt: audit.createdAt,
      createdById: audit.createdById,
      updatedAt: timestamp,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: _organismRecordUrlPath(cohort.id),
      internalPath: _organismRecordInternalPath(cohort.id),
      slug: _organismRecordSlug(cohort.id),
      metadata: _organismRecordMetadata(cohort),
      displayName: cohort.name,
      source: OrganismRecordSource.cohort,
      organismRecord: cohort.organismRecord,
    );
    await docRef.set(entry.toJson());
  }

  Future<_OrganismRecordAudit> _resolveOrganismRecordAudit({
    required DocumentReference<Map<String, dynamic>> docRef,
    required String fallbackTimestamp,
    required bool preserveExistingAudit,
  }) async {
    if (!preserveExistingAudit) {
      return _OrganismRecordAudit(
        createdAt: fallbackTimestamp,
        createdById: user.id,
      );
    }
    final snapshot = await docRef.get();
    final data = snapshot.data();
    final createdAt = (data?['createdAt'] as String?) ?? fallbackTimestamp;
    final createdById = (data?['createdById'] as String?) ?? user.id;
    return _OrganismRecordAudit(
      createdAt: createdAt,
      createdById: createdById,
    );
  }

  Map<String, dynamic> _organismRecordMetadata(Cohort cohort) {
    return <String, dynamic>{
      'sourceUrlPath': '${organization.urlPath}/cohorts/${cohort.id}',
      'sourceInternalPath':
          '${organization.internalPath}/cohorts/${cohort.id}',
      'siteId': cohort.siteId,
      'groupId': cohort.groupId,
      'structureId': cohort.structureId,
      'provenanceId': cohort.provenanceId,
    }..removeWhere(
        (_, value) =>
            value == null || (value is String && value.isEmpty),
      );
  }

  String _organismRecordUrlPath(String recordId) =>
      '${organization.urlPath}/organism-records/$recordId';

  String _organismRecordInternalPath(String recordId) =>
      '${organization.internalPath}/${ModelType.organismRecord.collectionPath}/$recordId';

  String _organismRecordSlug(String recordId) => 'organism-record-$recordId';

  Future<void> _ensureOccupantCapacity({
    required Cohort cohort,
    Cohort? previousCohort,
  }) async {
    if (!_structureCapacityService.isEnabled) return;
    final groupId = cohort.groupId;
    if (groupId == null || groupId.isEmpty) return;
    await _structureCapacityService.ensureInitialized();
    final groupSnapshot = await _groupsCollection.doc(groupId).get();
    final groupData = groupSnapshot.data();
    if (groupData == null) {
      return;
    }
    final parentJson = Map<String, dynamic>.from(groupData)
      ..putIfAbsent('id', () => groupSnapshot.id);
    final group = Group.fromJson(parentJson);
    final deltaUnits = _unitsFromMeasurement(cohort.population);
    if (deltaUnits <= 0) return;
    final currentUnits = await _sumOccupantUnits(
      groupId: group.id,
      targetCohort: cohort,
      excludeCohortId: previousCohort?.id,
    );
    final evaluation = _structureCapacityService.evaluate(
      StructureCapacityRequest.forOccupants(
        containerType: group.groupType,
        organismKind: cohort.organismKind,
        lifeStage: cohort.lifeStage,
        physicalFormId: cohort.organismRecord.lifecycleFormId,
        currentUnits: currentUnits,
        deltaUnits: deltaUnits,
      ),
    );
    if (!evaluation.hasRule) return;
    if (evaluation.isOverCapacity) {
      throw CapabilityConstraintError(
        message: evaluation.blockingMessage,
        capability: 'structureCapacity',
        recoverySuggestion:
            'Choose a different structure or reduce the cohort quantity.',
        context: {
          'groupId': group.id,
          'cohortId': cohort.id,
          'projectedUnits': evaluation.projectedUnits,
          'maxUnits': evaluation.rule?.maxUnits,
        },
      );
    }
    if (evaluation.isWarning) {
      LoggingService.instance.warning('Cohort nearing capacity', {
        'groupId': group.id,
        'cohortId': cohort.id,
        'projectedUnits': evaluation.projectedUnits,
        'maxUnits': evaluation.rule?.maxUnits,
      });
    }
  }

  Future<int> _sumOccupantUnits({
    required String groupId,
    required Cohort targetCohort,
    String? excludeCohortId,
  }) async {
    final snapshot = await collectionRef.where('groupId', isEqualTo: groupId).get();
    var total = 0;
    for (final doc in snapshot.docs) {
      if (excludeCohortId != null && doc.id == excludeCohortId) {
        continue;
      }
      final cohort = _cohortFromSnapshot(doc);
      if (!_matchesOccupantFilters(cohort, targetCohort)) {
        continue;
      }
      total += _unitsFromMeasurement(cohort.population);
    }
    return total;
  }

  bool _matchesOccupantFilters(Cohort candidate, Cohort target) {
    if (candidate.organismKind != target.organismKind) return false;
    if (candidate.lifeStage != target.lifeStage) return false;
    final targetMorph = target.organismRecord.physicalForm;
    final candidateMorph = candidate.organismRecord.physicalForm;
    if (targetMorph != null && candidateMorph != targetMorph) {
      return false;
    }
    return true;
  }

  int _unitsFromMeasurement(PopulationMeasurement measurement) {
    if (measurement.value <= 0) return 0;
    return measurement.value.round();
  }
}

class _OrganismRecordAudit {
  const _OrganismRecordAudit({
    required this.createdAt,
    required this.createdById,
  });

  final String createdAt;
  final String createdById;
}
