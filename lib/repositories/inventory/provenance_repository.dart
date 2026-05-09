// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/types/provenance_kind.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/models/records/archive_metadata.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/provenance_id_service.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';

/// Repository for managing ProvenanceRecords (formerly Genets).
/// This repository is the source of truth for provenance metadata,
/// reading and writing directly to the underlying collection.
///
/// **Collection Path**: Uses nested collection `organizations/{orgId}/genets`
/// to ensure proper data isolation per organization. This matches how genets
/// are seeded in demo mode and provides consistent querying.
class ProvenanceRepository {
  ProvenanceRepository({
    required this.organization,
    required this.user,
    required this.firestore,
    required this.eventRepository,
    SnapshotService? snapshotService,
    ProvenanceIdService? provenanceIdService,
  }) : snapshotService =
           snapshotService ?? SnapshotService(firestore: firestore),
       _provenanceIdService =
           provenanceIdService ?? ProvenanceIdService(firestore: firestore);

  final Organization organization;
  final User user;
  final FirebaseFirestore firestore;
  final EventRepository eventRepository;
  final SnapshotService snapshotService;
  final ProvenanceIdService _provenanceIdService;
  // The underlying collection name is still 'genets' for backward compatibility
  static const String _collectionName = 'genets';

  /// Uses nested collection under organizations/{orgId}/genets for proper
  /// organization scoping. This matches InventoryRecordRepository behavior
  /// for other organization-scoped record types (groups, organismRecords).
  CollectionReference<Map<String, dynamic>> get _collection => firestore
      .collection('organizations')
      .doc(organization.id)
      .collection(_collectionName);

  /// Get all provenance records.
  Future<List<ProvenanceRecord>> getAll() async {
    final snapshot = await _collection
        .where('archived', isNotEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => _recordFromFirestore(doc))
        .whereType<ProvenanceRecord>()
        .where((record) => !_isArchivedRecord(record))
        .toList();
  }

  /// Stream all provenance records.
  Stream<List<ProvenanceRecord>> get streamAll {
    return _collection
        .where('archived', isNotEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _recordFromFirestore(doc))
              .whereType<ProvenanceRecord>()
              .where((record) => !_isArchivedRecord(record))
              .toList(),
        );
  }

  /// Get a provenance record by ID.
  Future<ProvenanceRecord?> getRecordForId(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return _recordFromFirestore(doc);
  }

  bool _isArchivedRecord(ProvenanceRecord record) {
    final metadata = record.metadata;
    if (metadata[kArchivedFlagKey] == true || metadata['isDeleted'] == true) {
      return true;
    }
    final nested = metadata['metadata'];
    if (nested is Map) {
      return nested[kArchivedFlagKey] == true || nested['isDeleted'] == true;
    }
    return false;
  }

  /// Create a new provenance record.
  ///
  /// If [transaction] is provided, the write will be part of that transaction.
  /// This ensures atomicity when creating a genet as part of a larger operation
  /// (e.g., accepting a transfer).
  Future<ProvenanceRecord> createProvenanceRecord(
    ProvenanceRecord record, {
    Transaction? transaction,
  }) async {
    final resolvedRecord = await _ensureIdentifiers(record);
    final data = _recordToFirestore(resolvedRecord);

    // Add creation metadata
    final now = DateTime.now().toIso8601String();
    data['modelType'] = ModelType.genet.name;
    data['id'] = resolvedRecord.id;
    data['createdAt'] = now;
    data['updatedAt'] = now;
    data['createdById'] = user.id;
    data['updatedById'] = user.id;
    data['organizationId'] = organization.id;
    data['organizationDomain'] = organization.domain;
    data['archived'] = false;

    final docRef = _collection.doc(resolvedRecord.id);
    if (transaction != null) {
      transaction.set(docRef, data);
    } else {
      await docRef.set(data);
    }

    return resolvedRecord.copyWith(
      metadata: {
        ...resolvedRecord.metadata,
        'createdAt': now,
        'updatedAt': now,
      },
    );
  }

  Future<ProvenanceRecord> _ensureIdentifiers(ProvenanceRecord record) async {
    var updated = record;
    final localId = record.localId?.trim().isNotEmpty == true
        ? record.localId!.trim()
        : record.displayName.trim();
    if (localId.isNotEmpty && localId != record.localId) {
      updated = updated.copyWith(localId: localId);
    }

    final hasProvenanceId = record.provenanceId?.trim().isNotEmpty == true;
    if (!hasProvenanceId) {
      final speciesId = record.speciesId.trim();
      if (speciesId.isNotEmpty) {
        final generated = await _provenanceIdService.nextProvenanceId(
          speciesId: speciesId,
        );
        updated = updated.copyWith(provenanceId: generated);
      }
    }

    return updated;
  }

  /// Archive a provenance record by ID.
  Future<void> archiveGenet(
    String id, {
    PopulationLossReason? lossReason,
    String? comment,
  }) async {
    final record = await getRecordForId(id);
    if (record == null) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final archiveMetadata = <String, dynamic>{
      ...record.metadata,
      kArchivedFlagKey: true,
      kArchivedAtKey: now,
      kArchivedByIdKey: user.id,
      kArchivedReasonTypeKey: _archiveReasonType(lossReason),
      if (lossReason != null) kArchivedReasonIdKey: lossReason.id,
      if (comment != null) 'archiveReason': comment,
    };

    final archivedRecord = record.copyWith(
      metadata: archiveMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    final batch = firestore.batch();
    final archivedData = _recordToFirestore(archivedRecord);
    archivedData['updatedAt'] = now;
    archivedData['updatedById'] = user.id;
    batch.update(_collection.doc(record.id), archivedData);

    final eventId = firestore.collection('temp').doc().id;
    final slug = await nextSlugForModelType(ModelType.event);

    // Create a generic activity event for archival
    final eventData = {
      'id': eventId,
      'eventTypeId': 'activity_feed_event',
      'modelType': ModelType.event.name,
      'createdById': user.id,
      'createdAt': now,
      'updatedAt': now,
      'updatedById': user.id,
      'organizationId': organization.id,
      'urlPath':
          '${record.metadata['urlPath'] ?? "org/${organization.id}/genet/${record.id}"}/$slug',
      'internalPath':
          'organizations/${organization.id}/genets/${record.id}/$eventId',
      'slug': slug,
      'recordId': record.id,
      'recordModelType': 'genet',
      'metadata': {
        'activityType': 'archive',
        if (comment != null) 'comment': comment,
        if (lossReason != null) 'lossReasonId': lossReason.id,
      },
    };
    batch.set(firestore.collection('events').doc(eventId), eventData);

    await batch.commit();

    // Snapshot the archived state
    await _createSnapshot(archivedRecord, eventId);
  }

  String _archiveReasonType(PopulationLossReason? reason) {
    if (_isMortalityReason(reason)) {
      return kArchiveReasonTypeMortality;
    }
    return kArchiveReasonTypeDeleted;
  }

  bool _isMortalityReason(PopulationLossReason? reason) {
    if (reason == null) return false;
    return reason.isMortality;
  }

  /// Helper to generate next slug
  Future<String> nextSlugForModelType(ModelType modelType) async {
    // Simple timestamp-based slug for genets if no slug service is available
    // This avoids needing InventoryRecordRepository logic
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _createSnapshot(ProvenanceRecord record, String eventId) async {
    final snapshotData = _recordToFirestore(record);
    final snapshotId = '${record.id}_${eventId}_after';

    await firestore.collection('snapshots').doc(snapshotId).set({
      'id': snapshotId,
      'recordId': record.id,
      'recordType': 'genet',
      'eventId': eventId,
      'timestamp': DateTime.now().toIso8601String(),
      'snapshotType': 'after',
      'data': snapshotData,
      'organizationId':
          organization.id, // Required for Firestore security rules
    });
  }

  // --- Mapping Helpers ---

  ProvenanceRecord? _recordFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;

    String? readString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    String? readIsoTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return value;
      if (value is Timestamp) return value.toDate().toIso8601String();
      if (value is DateTime) return value.toIso8601String();
      return null;
    }

    final id = doc.id;
    const organismKind = OrganismKind.coral;

    final provenanceKind =
        ProvenanceKindX.tryParse(data['provenanceKind']?.toString()) ??
        ProvenanceKind.genet;

    final parentValue =
        data['parentProvenanceId']?.toString().trim() ??
        data['parentLineageId']?.toString().trim();

    // Extract root fields that belong in metadata for ProvenanceRecord
    final metadata = <String, dynamic>{
      ...data, // Start with all data
    };

    // Remove core fields from metadata to avoid duplication (optional, but cleaner)
    metadata.remove('id');
    metadata.remove('organismKind');
    metadata.remove('provenanceKind');
    metadata.remove('displayName');
    metadata.remove('name');
    metadata.remove('speciesId');
    metadata.remove('parentProvenanceId');
    metadata.remove('siteId');
    metadata.remove('aliasLabels');
    metadata.remove('localId');
    metadata.remove('provenanceId');

    if (data['provenanceTypeId'] != null) {
      metadata['provenanceTypeId'] = data['provenanceTypeId'];
    }
    if (data['urlPath'] != null) metadata['urlPath'] = data['urlPath'];

    String? readNullableString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final localId = readNullableString(data['localId']);
    final provenanceId = readNullableString(data['provenanceId']);

    final createdAt = readIsoTimestamp(data['createdAt']);
    final updatedAt = readIsoTimestamp(data['updatedAt']) ?? createdAt;
    final createdById = readString(data['createdById']);
    final updatedById = readString(data['updatedById']) ?? createdById;
    final organizationId =
        readString(data['organizationId']) ?? organization.id;

    final resolvedDisplayName = data['displayName']?.toString().trim() ?? id;

    return ProvenanceRecord(
      id: id,
      createdAt: createdAt ?? Missing.dateTimeString,
      createdById: createdById ?? Missing.string,
      updatedAt: updatedAt ?? Missing.dateTimeString,
      updatedById: updatedById ?? Missing.string,
      organizationId: organizationId,
      organismKind: organismKind,
      provenanceKind: provenanceKind,
      displayName: resolvedDisplayName,
      localId: localId,
      provenanceId: provenanceId,
      speciesId: data['speciesId']?.toString().trim() ?? '',
      parentProvenanceId: parentValue?.isEmpty == true ? null : parentValue,
      siteId: data['siteId']?.toString().trim(),
      aliasLabels: _parseAliasLabels(data),
      metadata: metadata,
    );
  }

  Map<String, dynamic> _recordToFirestore(ProvenanceRecord record) {
    // Start with metadata (flattened)
    final data = Map<String, dynamic>.from(record.metadata);

    // Overwrite with core fields to ensure consistency
    data['organismKind'] = record.organismKind.name;
    data['provenanceKind'] = record.provenanceKind.name;
    data['displayName'] = record.displayName;
    if (record.localId != null) data['localId'] = record.localId;
    if (record.provenanceId != null) data['provenanceId'] = record.provenanceId;
    data['speciesId'] = record.speciesId;
    if (record.siteId != null) data['siteId'] = record.siteId;
    if (record.parentProvenanceId != null) {
      data['parentProvenanceId'] = record.parentProvenanceId;
    }

    // Canonical aliases only.
    data.remove('aliases');
    data['aliasLabels'] = record.aliasLabels;

    return data;
  }

  List<String> _parseAliasLabels(Map<String, dynamic> json) {
    final seen = <String>{};
    void addValue(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        seen.add(value.trim());
      }
    }

    final labelList = json['aliasLabels'];
    if (labelList is Iterable) {
      for (final entry in labelList) {
        addValue(entry);
      }
    }

    return seen.toList();
  }
}
