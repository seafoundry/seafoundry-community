import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/organism_record_change_service.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Base repository for neutral [HoldingRecord] objects. Holdings live under
/// `organizations/{org}/holdings` so every organism can persist batch data
/// without creating new top-level collections.
abstract class HoldingRepository<T extends HoldingRecord> {
  HoldingRepository({
    required this.organization,
    required this.user,
    required FirebaseFirestore firestore,
    required this.organismContext,
    required this.holdingKind,
    required EventRepository eventRepository,
    required OrganismRecordChangeService changeService,
    required SnapshotService snapshotService,
    required T Function(Map<String, dynamic>) fromJson,
    StructureCapacityService? structureCapacityService,
    String collectionName = 'holdings',
  }) : _eventRepository = eventRepository,
       _changeService = changeService,
       _snapshotService = snapshotService,
       _fromJson = fromJson,
       _structureCapacityService =
           structureCapacityService ?? StructureCapacityService.disabled(),
       collectionRef = firestore
           .collection(ModelType.organization.collectionPath)
           .doc(organization.id)
           .collection(collectionName),
       _groupsCollection = firestore
           .collection(ModelType.organization.collectionPath)
           .doc(organization.id)
           .collection('groups'),
       _organismRecordsCollection = firestore
           .collection(ModelType.organization.collectionPath)
           .doc(organization.id)
           .collection(ModelType.organismRecord.collectionPath);

  final CollectionReference<Map<String, dynamic>> collectionRef;
  final CollectionReference<Map<String, dynamic>> _groupsCollection;
  final CollectionReference<Map<String, dynamic>>
      _organismRecordsCollection;
  final Organization organization;
  final User user;
  final OrganismContext organismContext;
  final String holdingKind;
  final EventRepository _eventRepository;
  final OrganismRecordChangeService _changeService;
  final SnapshotService _snapshotService;
  final T Function(Map<String, dynamic>) _fromJson;
  final StructureCapacityService _structureCapacityService;

  Future<T> createHolding(
    T holding, {
    required OrganismRecord organismRecord,
  }) async {
    _assertOrganism(holding.organismKind);
    await _ensureOccupantCapacity(
      holding: holding,
      holdingOrganismRecord: organismRecord,
    );
    final docRef = holding.id.isNotEmpty
        ? collectionRef.doc(holding.id)
        : collectionRef.doc();
    final now = DateTimeConverter.nowAsIso8601String();
    final assigned = _withId(holding, docRef.id);
    final payload = _createPayload(assigned, now);
    await docRef.set(payload);
    await _upsertOrganismRecordDocument(
      record: assigned,
      organismRecord: organismRecord,
      timestamp: now,
      preserveExistingAudit: false,
    );

    // Create audit snapshot (using synthetic event ID as creation is the event)
    await _snapshotService.createAfterSnapshot(
      record: assigned,
      eventId: 'create_${assigned.id}'
    );

    return assigned;
  }

  Future<T> updateHolding(
    T holding, {
    required OrganismRecord organismRecord,
    Map<String, dynamic>? eventMetadataOverrides,
  }) async {
    if (holding.id.isEmpty) {
      throw ArgumentError('holding.id cannot be empty when updating.');
    }
    final existing = await getHolding(holding.id);
    if (existing == null) {
      throw StateError('Holding ${holding.id} does not exist.');
    }
    _assertOrganism(holding.organismKind);
    final previousOrganismRecord = await _fetchOrganismRecord(existing);
    if (previousOrganismRecord != null) {
      _changeService.assertImmutableFields(
        previous: previousOrganismRecord,
        next: organismRecord,
      );
    }
    await _ensureOccupantCapacity(
      holding: holding,
      previousHolding: existing,
      holdingOrganismRecord: organismRecord,
    );
    final changeSet = previousOrganismRecord != null
        ? _changeService.detectChanges(
            previous: previousOrganismRecord,
            next: organismRecord,
          )
        : null;
    final now = DateTimeConverter.nowAsIso8601String();
    final payload = _updatePayload(holding, now);
    await collectionRef.doc(holding.id).update(payload);
    await _upsertOrganismRecordDocument(
      record: holding,
      organismRecord: organismRecord,
      timestamp: now,
      preserveExistingAudit: true,
    );

    // Snapshot the update
    // If events are emitted, we could link to the first one, or use a synthetic update ID
    // Since _emitOrganismRecordEvents creates multiple events, we'll use a synthetic ID or just the last event ID if possible.
    // For simplicity and safety, we use synthetic update ID.
    await _snapshotService.createAfterSnapshot(
      record: holding,
      eventId: 'update_${holding.id}_${DateTime.now().millisecondsSinceEpoch}'
    );

    if (changeSet != null && changeSet.hasChanges) {
      await _emitOrganismRecordEvents(
        updated: holding,
        snapshot: organismRecord,
        changeSet: changeSet,
        metadataOverrides: eventMetadataOverrides,
      );
    }
    return holding;
  }

  /// Fetches the canonical [OrganismRecord] document associated with [holding]
  /// via its [HoldingRecord.organismRecordId]. Returns null when the FK is
  /// empty or the doc is missing — callers must tolerate that for newly
  /// constructed holdings whose organism record has not been written yet.
  Future<OrganismRecord?> _fetchOrganismRecord(T holding) async {
    final lookup = await holding.resolveOrganismRecord((id) async {
      final snapshot = await _organismRecordsCollection.doc(id).get();
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      final entry = OrganismRecordEntry.fromJson(<String, dynamic>{
        ...data,
        'id': snapshot.id,
      });
      return entry.organismRecord;
    });
    return lookup;
  }

  /// Applies an updated canonical [OrganismRecord] snapshot to [holding] and
  /// persists the change while emitting lifecycle/measurement events as needed.
  Future<T> updateOrganismRecord(
    T holding, {
    required OrganismRecord updatedOrganismRecord,
    Map<String, dynamic>? metadataOverrides,
    Map<String, dynamic>? eventMetadataOverrides,
  }) async {
    final aligned =
        holding.alignWithOrganismRecord(
              updatedOrganismRecord,
              metadataOverrides: metadataOverrides,
            )
            as T;
    return updateHolding(
      aligned,
      organismRecord: updatedOrganismRecord,
      eventMetadataOverrides: eventMetadataOverrides,
    );
  }

  Future<T?> getHolding(String holdingId) async {
    final snapshot = await collectionRef.doc(holdingId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return _fromSnapshot(snapshot);
  }

  Future<List<T>> fetchHoldings({
    LifeStage? lifeStage,
    OrganismKind? organismKind,
  }) async {
    final snapshot = await _queryHoldings(
      lifeStage: lifeStage,
      organismKind: organismKind,
    ).get();
    return snapshot.docs.map(_fromSnapshot).toList(growable: false);
  }

  Stream<List<T>> streamHoldings({
    LifeStage? lifeStage,
    OrganismKind? organismKind,
  }) {
    return _queryHoldings(
      lifeStage: lifeStage,
      organismKind: organismKind,
    ).snapshots().map(
      (snapshot) => snapshot.docs.map(_fromSnapshot).toList(growable: false),
    );
  }

  Query<Map<String, dynamic>> _queryHoldings({
    LifeStage? lifeStage,
    OrganismKind? organismKind,
  }) {
    Query<Map<String, dynamic>> query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('holdingKind', isEqualTo: holdingKind)
        .where(
          'organismKind',
          isEqualTo: (organismKind ?? organismContext.kind).name,
        );
    if (lifeStage != null) {
      query = query.where('lifeStage', isEqualTo: lifeStage.id);
    }
    return query;
  }

  void _assertOrganism(OrganismKind kind) {
    if (kind != organismContext.kind) {
      throw StateError(
        'Holding kind mismatch: expected ${organismContext.kind.name}, '
        'received ${kind.name}',
      );
    }
  }

  T _withId(T holding, String id) {
    if (holding.id == id) {
      return holding;
    }
    return holding.copyWith(id: id) as T;
  }

  Map<String, dynamic> _baseJson(T holding) {
    final json = Map<String, dynamic>.from(holding.toJson());
    json['holdingKind'] = holdingKind;
    json['organismKind'] = holding.organismKind.name;
    json['organizationId'] = organization.id;
    return json;
  }

  Map<String, dynamic> _createPayload(T holding, String timestamp) {
    final json = _baseJson(holding);
    json['createdAt'] = timestamp;
    json['createdById'] = user.id;
    json['updatedAt'] = timestamp;
    json['updatedById'] = user.id;
    return json;
  }

  Map<String, dynamic> _updatePayload(T holding, String timestamp) {
    final json = _baseJson(holding);
    json['updatedAt'] = timestamp;
    json['updatedById'] = user.id;
    return json;
  }

  T _fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Holding ${snapshot.id} is missing data.');
    }
    final payload = Map<String, dynamic>.from(data);
    payload['id'] = payload['id'] ?? snapshot.id;
    return _fromJson(payload);
  }

  Future<void> _emitOrganismRecordEvents({
    required T updated,
    required OrganismRecord snapshot,
    required OrganismRecordChangeSet changeSet,
    Map<String, dynamic>? metadataOverrides,
  }) async {
    final recordUrlPath = _organismRecordUrlPath(updated.id);
    final recordInternalPath = _organismRecordInternalPath(updated.id);
    final metadata = _eventMetadataForHolding(updated);
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

  Map<String, dynamic> _eventMetadataForHolding(T holding) {
    return <String, dynamic>{
      'holdingKind': holdingKind,
      'tagId': holding.tagId,
      'siteId': holding.siteId,
      'groupId': holding.groupId,
      'structureId': holding.structureId,
      'cohortId': holding.cohortId,
    }..removeWhere(
      (_, value) => value == null || (value is String && value.isEmpty),
    );
  }

  Future<void> _upsertOrganismRecordDocument({
    required T record,
    required OrganismRecord organismRecord,
    required String timestamp,
    required bool preserveExistingAudit,
  }) async {
    final docRef = _organismRecordsCollection.doc(record.id);
    final audit = await _resolveOrganismRecordAudit(
      docRef: docRef,
      fallbackTimestamp: timestamp,
      preserveExistingAudit: preserveExistingAudit,
    );
    final entry = OrganismRecordEntry(
      id: record.id,
      createdAt: audit.createdAt,
      createdById: audit.createdById,
      updatedAt: timestamp,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: _organismRecordUrlPath(record.id),
      internalPath: _organismRecordInternalPath(record.id),
      slug: _organismRecordSlug(record.id),
      metadata: _organismRecordMetadata(record),
      displayName: record.tagId,
      source: OrganismRecordSource.holding,
      sourceKind: holdingKind,
      organismRecord: organismRecord,
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

  Map<String, dynamic> _organismRecordMetadata(T record) {
    return <String, dynamic>{
      'sourceUrlPath': '${organization.urlPath}/holdings/${record.id}',
      'sourceInternalPath':
          '${organization.internalPath}/holdings/${record.id}',
      'holdingKind': holdingKind,
      'siteId': record.siteId,
      'groupId': record.groupId,
      'structureId': record.structureId,
      'cohortId': record.cohortId,
      'provenanceId': record.provenanceId,
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
    required T holding,
    required OrganismRecord holdingOrganismRecord,
    T? previousHolding,
  }) async {
    if (!_structureCapacityService.isEnabled) return;
    final groupId = holding.groupId;
    if (groupId == null || groupId.isEmpty) return;
    await _structureCapacityService.ensureInitialized();
    final groupSnapshot = await _groupsCollection.doc(groupId).get();
    final groupData = groupSnapshot.data();
    if (groupData == null) {
      return;
    }
    final parentJson = Map<String, dynamic>.from(groupData);
    parentJson['id'] = groupSnapshot.id;
    final group = Group.fromJson(parentJson);
    final deltaUnits = _unitsFromMeasurement(holding.measurement);
    if (deltaUnits <= 0) return;
    final currentUnits = await _sumOccupantUnits(
      groupId: group.id,
      targetHolding: holding,
      targetOrganismRecord: holdingOrganismRecord,
      excludeHoldingId: previousHolding?.id,
    );
    final evaluation = _structureCapacityService.evaluate(
      StructureCapacityRequest.forOccupants(
        containerType: group.groupType,
        organismKind: holding.organismKind,
        lifeStage: holding.lifeStage,
        physicalFormId: holdingOrganismRecord.physicalForm?.formId,
        currentUnits: currentUnits,
        deltaUnits: deltaUnits,
      ),
    );
    if (!evaluation.hasRule) {
      return;
    }
    if (evaluation.isOverCapacity) {
      throw CapabilityConstraintError(
        message: evaluation.blockingMessage,
        capability: 'structureCapacity',
        recoverySuggestion:
            'Choose a different structure or reduce the batch quantity.',
        context: {
          'groupId': group.id,
          'holdingKind': holdingKind,
          'projectedUnits': evaluation.projectedUnits,
          'maxUnits': evaluation.rule?.maxUnits,
        },
      );
    }
    if (evaluation.isWarning) {
      LoggingService.instance.warning('Holding nearing capacity', {
        'groupId': group.id,
        'holdingKind': holdingKind,
        'projectedUnits': evaluation.projectedUnits,
        'maxUnits': evaluation.rule?.maxUnits,
      });
    }
  }

  Future<int> _sumOccupantUnits({
    required String groupId,
    required HoldingRecord targetHolding,
    required OrganismRecord targetOrganismRecord,
    String? excludeHoldingId,
  }) async {
    final snapshot = await collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('groupId', isEqualTo: groupId)
        .where('holdingKind', isEqualTo: holdingKind)
        .get();
    final targetMorph = targetOrganismRecord.physicalForm;
    var total = 0;
    for (final doc in snapshot.docs) {
      if (excludeHoldingId != null && doc.id == excludeHoldingId) {
        continue;
      }
      final record = _fromSnapshot(doc);
      if (record.organismKind != targetHolding.organismKind) continue;
      if (record.lifeStage != targetHolding.lifeStage) continue;
      if (targetMorph != null) {
        final candidateRecord = await _fetchOrganismRecord(record);
        if (candidateRecord?.physicalForm != targetMorph) continue;
      }
      total += _unitsFromMeasurement(record.measurement);
    }
    return total;
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
