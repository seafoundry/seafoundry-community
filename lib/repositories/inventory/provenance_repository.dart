// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/alias.dart';
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
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
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
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  // The underlying collection name is still 'genets' for backward compatibility
  static const String _collectionName = 'genets';

  /// Uses nested collection under organizations/{orgId}/genets for proper
  /// organization scoping. This matches BaseInventoryRecordRepository behavior
  /// for other organization-scoped record types (groups, organismRecords).
  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.subcollection(
        firestore,
        'organizations',
        organization.id,
        _collectionName,
      );

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

  /// Get a provenance record by localId (fallback lookup when only the
  /// user-facing genet/local ID is available).
  Future<ProvenanceRecord?> getRecordForLocalId(String localId) async {
    final trimmed = localId.trim();
    if (trimmed.isEmpty) return null;

    Future<ProvenanceRecord?> fetchFirst(String field, String value) async {
      final snapshot = await _collection.where(field, isEqualTo: value).get();
      for (final doc in snapshot.docs) {
        final record = _recordFromFirestore(doc);
        if (record == null) continue;
        if (_isArchivedRecord(record)) continue;
        return record;
      }
      return null;
    }

    final candidates = <String>{
      trimmed,
      trimmed.toLowerCase(),
      trimmed.toUpperCase(),
    };

    for (final candidate in candidates) {
      final match = await fetchFirst('localId', candidate);
      if (match != null) return match;
    }

    for (final candidate in candidates) {
      final match = await fetchFirst('name', candidate);
      if (match != null) return match;
    }

    for (final candidate in candidates) {
      final match = await fetchFirst('displayName', candidate);
      if (match != null) return match;
    }

    return null;
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

  Future<ProvenanceRecord> _ensureIdentifiers(
    ProvenanceRecord record,
  ) async {
    var updated = record;
    final localId =
        record.localId?.trim().isNotEmpty == true
            ? record.localId!.trim()
            : record.displayName.trim();
    if (localId.isNotEmpty && localId != record.localId) {
      updated = updated.copyWith(localId: localId);
    }

    final hasProvenanceId =
        record.provenanceId?.trim().isNotEmpty == true;
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

  /// Update an existing provenance record.
  Future<ProvenanceRecord> updateProvenanceRecord(
    ProvenanceRecord record,
  ) async {
    final oldRecord = await getRecordForId(record.id);
    final data = _recordToFirestore(record);

    // Update metadata
    final now = DateTime.now().toIso8601String();
    data['updatedAt'] = now;
    data['updatedById'] = user.id;

    await _collection.doc(record.id).update(data);
    final updatedRecord = record.copyWith(metadata: {...record.metadata, 'updatedAt': now});

    // Audit trail
    if (oldRecord != null) {
      final changes = _computeChanges(oldRecord, updatedRecord);
      if (changes.isNotEmpty) {
        final eventId = _resolver.generateId(firestore);
        final slug = await nextSlugForModelType(ModelType.event);

        // Manually construct CorrectionEvent since ProvenanceRecord isn't InventoryRecord
        final eventData = {
          'id': eventId,
          'eventTypeId': 'inventory_record_correction',
          'modelType': ModelType.event.name,
          'createdById': user.id,
          'createdAt': now,
          'updatedAt': now,
          'updatedById': user.id,
          'organizationId': organization.id,
          'urlPath': '${updatedRecord.metadata['urlPath'] ?? "org/${organization.id}/genet/${updatedRecord.id}"}/$slug',
          'internalPath': 'organizations/${organization.id}/genets/${updatedRecord.id}/$eventId',
          'slug': slug,
          'recordId': updatedRecord.id,
          'recordModelType': 'genet',
          'originalEventId': '${oldRecord.id}_original', // Synthetic
          'correctedEventId': '${updatedRecord.id}_corrected', // Synthetic
          'notes': 'Provenance record updated',
          'metadata': {'changes': changes},
        };

        await _resolver.collection(firestore, 'events').doc(eventId).set(eventData);
        await _createSnapshot(updatedRecord, eventId);
      }
    }

    return updatedRecord;
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

    final eventId = _resolver.generateId(firestore);
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
    batch.set(_resolver.collection(firestore, 'events').doc(eventId), eventData);

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
    if (reason is MortalityReason || reason is OutplantLossReason) {
      return true;
    }
    return reason.id == PopulationLossReason.mortality.id;
  }

  /// Share aliases with an existing provenance record.
  Future<ProvenanceRecord> shareAliasesWithExistingRecord({
    required ProvenanceRecord target,
    required String existingRecordId,
    required List<OrganismAlias> aliases,
  }) async {
    // This logic mimics the original GenetRepository behavior
    // 1. Get the existing record to ensure it exists
    final existingDoc = await _collection.doc(existingRecordId).get();
    if (!existingDoc.exists) {
      throw Exception('Existing record $existingRecordId not found');
    }

    // 2. Prepare alias updates - must update both aliasLabels and metadata['aliases']
    // aliasLabels is used for search/display, metadata['aliases'] is used by aliasEntries getter
    final currentAliases = List<String>.from(target.aliasLabels);
    final newAliasLabels = aliases.map((a) => a.label ?? a.value).toList();
    final combinedAliasLabels = <String>{
      ...currentAliases,
      ...newAliasLabels,
    }.toList();

    // Get current alias entries from metadata and merge with new aliases
    final currentAliasEntries = List<Map<String, dynamic>>.from(
      (target.metadata['aliases'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );

    // Deduplicate aliases by sourceSystem+value
    final seenKeys = <String>{};
    final deduplicatedEntries = <Map<String, dynamic>>[];

    for (final entry in currentAliasEntries) {
      final key = '${entry['sourceSystem']}::${entry['value']}'.toLowerCase();
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        deduplicatedEntries.add(entry);
      }
    }

    for (final alias in aliases) {
      final key = '${alias.sourceSystem}::${alias.value}'.toLowerCase();
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        deduplicatedEntries.add(alias.toJson());
      }
    }

    final updatedMetadata = Map<String, dynamic>.from(target.metadata);
    updatedMetadata['aliases'] = deduplicatedEntries;

    final updatedRecord = target.copyWith(
      aliasLabels: combinedAliasLabels,
      metadata: updatedMetadata,
    );
    final savedRecord = await updateProvenanceRecord(updatedRecord);

    return savedRecord;
  }

  /// Helper to generate next slug
  Future<String> nextSlugForModelType(ModelType modelType) async {
    // Simple timestamp-based slug for genets if no slug service is available
    // This avoids needing BaseInventoryRecordRepository logic
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _createSnapshot(ProvenanceRecord record, String eventId) async {
    final snapshotData = _recordToFirestore(record);
    final snapshotId = '${record.id}_${eventId}_after';

    await _resolver.collection(firestore, 'snapshots').doc(snapshotId).set({
      'id': snapshotId,
      'recordId': record.id,
      'recordType': 'genet',
      'eventId': eventId,
      'timestamp': DateTime.now().toIso8601String(),
      'snapshotType': 'after',
      'data': snapshotData,
      'organizationId': organization.id, // Required for Firestore security rules
    });
  }

  Map<String, dynamic> _computeChanges(ProvenanceRecord old, ProvenanceRecord current) {
    final changes = <String, dynamic>{};
    if (old.displayName != current.displayName) {
      changes['displayName'] = {'from': old.displayName, 'to': current.displayName};
    }
    // Add other fields as needed
    return changes;
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
    final kindRaw = data['organismKind']?.toString().trim().toLowerCase();
    final organismKind = OrganismKind.values.firstWhere(
      (kind) => kind.name.toLowerCase() == kindRaw,
      orElse: () => OrganismKind.coral, // Default to coral for legacy data
    );

    final provenanceKind =
        ProvenanceKindX.tryParse(data['provenanceKind']?.toString()) ??
        ProvenanceKindX.tryParse(data['lineageKind']?.toString()) ??
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
    metadata.remove('name'); // Legacy name
    metadata.remove('speciesId');
    metadata.remove('parentProvenanceId');
    metadata.remove('siteId');
    metadata.remove('aliasLabels');
    metadata.remove('localId');
    metadata.remove('provenanceId');

    // Ensure specific legacy fields are preserved in metadata
    if (data['provenanceTypeId'] != null) {
      metadata['provenanceTypeId'] = data['provenanceTypeId'];
    }
    if (data['urlPath'] != null) metadata['urlPath'] = data['urlPath'];

    String? readNullableString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final localId =
        readNullableString(data['localId']) ??
        readNullableString(data['metadata']?['localId']) ??
        readNullableString(data['name']) ??
        readNullableString(data['displayName']);
    final provenanceId =
        readNullableString(data['provenanceId']) ??
        readNullableString(data['metadata']?['provenanceId']);

    final createdAt = readIsoTimestamp(data['createdAt']);
    final updatedAt = readIsoTimestamp(data['updatedAt']) ?? createdAt;
    final createdById = readString(data['createdById']);
    final updatedById = readString(data['updatedById']) ?? createdById;
    final organizationId = readString(data['organizationId']) ?? organization.id;

    final metadataDisplayName = data['metadata'] is Map
        ? data['metadata']['displayName']?.toString().trim() ??
            data['metadata']['name']?.toString().trim()
        : null;
    final resolvedDisplayName =
        data['displayName']?.toString().trim() ??
        data['name']?.toString().trim() ??
        metadataDisplayName ??
        id;

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
    data['name'] = record.displayName; // Maintain legacy 'name' field
    if (record.localId != null) data['localId'] = record.localId;
    if (record.provenanceId != null) data['provenanceId'] = record.provenanceId;
    data['speciesId'] = record.speciesId;
    if (record.siteId != null) data['siteId'] = record.siteId;
    if (record.parentProvenanceId != null) {
      data['parentProvenanceId'] = record.parentProvenanceId;
    }

    // Aliases
    data['aliasLabels'] = record.aliasLabels;
    // Also write 'aliases' as list of objects if needed by legacy,
    // but ProvenanceRecord only stores labels in aliasLabels.
    // If metadata contained 'aliases' (full objects), they are already in `data` from the first step.

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

    // Legacy 'aliases' field which might be List<Map> or List<String>
    final aliases = json['aliases'];
    if (aliases is Iterable) {
      for (final entry in aliases) {
        if (entry is String) {
          addValue(entry);
        } else if (entry is Map) {
          addValue(entry['label']);
          addValue(entry['value']);
        }
      }
    }

    return seen.toList();
  }
}
