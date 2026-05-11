import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Ensures tagged aliases (Tracks, ZIMS, CSR, etc.) remain unique across the
/// deployment. Each alias is indexed under `alias_index/{source::value}` so any
/// duplicate attempts can be blocked before the record is written.
class AliasUniquenessService {
  AliasUniquenessService({
    FirebaseFirestore? firestore,
    Map<String, String>? knownSystems,
  }) : _firestore = firestore,
       _knownSystems = Map.unmodifiable(
         knownSystems == null || knownSystems.isEmpty
             ? _defaultSystems
             : {
                 ..._defaultSystems,
                 ...knownSystems.map(
                   (key, value) => MapEntry(key.toLowerCase(), value),
                 ),
               },
       );

  static const String _collectionPath = 'alias_index';
  static const Map<String, String> _defaultSystems = {
    'provenanceId': 'Provenance ID',
    'tracks': 'AZA Tracks',
    'zims': 'ZIMS',
    'csr': 'Coral Sample Registry',
    'galaxystag': 'Galaxy STAG',
    'batch': 'Batch / Lot',
    'local': 'Local Identifier',
  };

  static Map<String, String> get defaultSystems =>
      Map<String, String>.unmodifiable(_defaultSystems);

  final FirebaseFirestore? _firestore;
  final Map<String, String> _knownSystems;

  Map<String, String> get knownSystems => _knownSystems;

  /// Deduplicates aliases locally (most recent entries win). This mirrors the
  /// Firestore-level `_uniqueAliases` guard so editors can merge payloads before
  /// persisting.
  List<OrganismAlias> deduplicateLocalAliases(
    Iterable<OrganismAlias> aliases,
  ) => _uniqueAliases(aliases).toList(growable: false);

  /// Throws [AliasConflictException] if any alias (by source/value) is already
  /// claimed by another record. Pass [excludeRecordId] when editing an existing
  /// record so it can re-use its own aliases.
  Future<void> assertAliasesUnique({
    required Iterable<OrganismAlias> aliases,
    required ModelType modelType,
    String? excludeRecordId,
  }) async {
    final firestore = _requireFirestore();
    for (final alias in _uniqueAliases(aliases)) {
      final doc = await _docRef(alias, firestore).get();
      if (!doc.exists) continue;
      final data = doc.data();
      final existingModel = data?['modelType']?.toString();
      if (existingModel != modelType.name) {
        throw AliasConflictException(
          sourceSystem: alias.sourceSystem,
          value: alias.value,
          conflictingRecordId: data?['recordId']?.toString(),
          message:
              'Alias "${alias.value}" (${alias.sourceSystem}) is already '
              'claimed by a ${existingModel ?? 'different'} record.',
        );
      }
      final existingRecord = data?['recordId']?.toString();
      if (existingRecord != null && existingRecord != excludeRecordId) {
        throw AliasConflictException(
          sourceSystem: alias.sourceSystem,
          value: alias.value,
          conflictingRecordId: existingRecord,
          message:
              'Alias "${alias.value}" (${alias.sourceSystem}) is already '
              'linked to another record.',
        );
      }
    }
  }

  /// Upserts alias index entries so downstream services and validators can look
  /// up the owning record quickly. A second conflict check guards against races.
  Future<void> upsertAliases({
    required Iterable<OrganismAlias> aliases,
    required ModelType modelType,
    required String recordId,
    required String provenanceId,
    required String organizationId,
    required String localGenetId,
  }) async {
    final firestore = _requireFirestore();
    for (final alias in _uniqueAliases(aliases)) {
      await firestore.runTransaction((txn) async {
        final ref = _docRef(alias, firestore);
        final snapshot = await txn.get(ref);
        if (snapshot.exists) {
          final data = snapshot.data();
          final existingRecord = data?['recordId']?.toString();
          if (existingRecord != null && existingRecord != recordId) {
            throw AliasConflictException(
              sourceSystem: alias.sourceSystem,
              value: alias.value,
              conflictingRecordId: existingRecord,
              message:
                  'Alias "${alias.value}" (${alias.sourceSystem}) is already '
                  'claimed by another record.',
            );
          }
        }

        final payload = <String, dynamic>{
          'sourceSystem': alias.sourceSystem,
          'value': alias.value,
          if (alias.label != null) 'label': alias.label,
          'provenanceId': provenanceId,
          'recordId': recordId,
          'modelType': modelType.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'organizationRefs.$organizationId': {
            'recordId': recordId,
            'localGenetId': localGenetId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        };
        if (!snapshot.exists) {
          payload['createdAt'] = FieldValue.serverTimestamp();
        }
        txn.set(ref, payload, SetOptions(merge: true));
      });
    }
  }

  /// Adds the caller's organization reference to an alias that is already
  /// registered to [existingRecordId]. This is the "share" path used when two
  /// organizations intentionally reference the same provenance ID.
  Future<void> linkAliasToExistingRecord({
    required OrganismAlias alias,
    required String existingRecordId,
    required ModelType modelType,
    required String provenanceId,
    required String organizationId,
    required String localGenetId,
  }) async {
    final firestore = _requireFirestore();
    await firestore.runTransaction((txn) async {
      final ref = _docRef(alias, firestore);
      final snapshot = await txn.get(ref);
      if (!snapshot.exists) {
        throw AliasConflictException(
          sourceSystem: alias.sourceSystem,
          value: alias.value,
          conflictingRecordId: null,
          message:
              'Alias "${alias.value}" (${alias.sourceSystem}) is not yet '
              'registered. Ask the original organization to register it '
              'before sharing.',
        );
      }
      final data = snapshot.data();
      final recordId = data?['recordId']?.toString();
      if (recordId == null || recordId != existingRecordId) {
        throw AliasConflictException(
          sourceSystem: alias.sourceSystem,
          value: alias.value,
          conflictingRecordId: recordId,
          message:
              'Alias "${alias.value}" belongs to a different record '
              '($recordId).',
        );
      }
      final existingModel = data?['modelType']?.toString();
      if (existingModel != modelType.name) {
        throw AliasConflictException(
          sourceSystem: alias.sourceSystem,
          value: alias.value,
          conflictingRecordId: recordId,
          message:
              'Alias "${alias.value}" is registered as a '
              '$existingModel record.',
        );
      }
      final orgRefs = Map<String, dynamic>.from(
        data?['organizationRefs'] ?? const {},
      );
      orgRefs[organizationId] = {
        'recordId': recordId,
        'localGenetId': localGenetId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      txn.update(ref, {
        'organizationRefs': orgRefs,
        'provenanceId': provenanceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Removes alias entries owned by [recordId]. When another organization links
  /// to the same record the doc remains until the final reference is removed.
  Future<void> removeAliases({
    required Iterable<OrganismAlias> aliases,
    required String recordId,
    required String organizationId,
  }) async {
    final firestore = _requireFirestore();
    for (final alias in _uniqueAliases(aliases)) {
      await firestore.runTransaction((txn) async {
        final ref = _docRef(alias, firestore);
        final snapshot = await txn.get(ref);
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data?['recordId'] != recordId) {
          return;
        }
        final orgRefs = Map<String, dynamic>.from(
          data?['organizationRefs'] ?? const {},
        );
        orgRefs.remove(organizationId);
        if (orgRefs.isEmpty) {
          txn.delete(ref);
        } else {
          txn.update(ref, {
            'organizationRefs': orgRefs,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }
  }

  FirebaseFirestore _requireFirestore() {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError(
        'AliasUniquenessService requires a FirebaseFirestore instance for '
        'remote operations.',
      );
    }
    return firestore;
  }

  DocumentReference<Map<String, dynamic>> _docRef(
    OrganismAlias alias,
    FirebaseFirestore firestore,
  ) {
    final sanitizedSource = alias.sourceSystem.trim().toLowerCase();
    final sanitizedValue = alias.value.trim().toLowerCase();
    final docId = '$sanitizedSource::$sanitizedValue';
    return firestore.collection(_collectionPath).doc(docId);
  }

  static Iterable<OrganismAlias> _uniqueAliases(
    Iterable<OrganismAlias> aliases,
  ) {
    final seen = <_AliasKey>{};
    final deduped = <OrganismAlias>[];
    for (final alias in aliases) {
      final key = _AliasKey(
        sourceSystem: alias.sourceSystem,
        value: alias.value,
      );
      if (seen.add(key)) {
        deduped.add(alias);
      }
    }
    return deduped;
  }
}

class AliasConflictException extends Equatable implements Exception {
  const AliasConflictException({
    required this.sourceSystem,
    required this.value,
    this.conflictingRecordId,
    this.message,
  });

  final String sourceSystem;
  final String value;
  final String? conflictingRecordId;
  final String? message;

  @override
  List<Object?> get props => [
    sourceSystem,
    value,
    conflictingRecordId,
    message,
  ];

  @override
  String toString() {
    final conflict = conflictingRecordId != null
        ? ' (record: $conflictingRecordId)'
        : '';
    return message ??
        'Alias "$value" from "$sourceSystem" is already claimed$conflict.';
  }
}

class AliasIndexEntry extends Equatable {
  const AliasIndexEntry({
    required this.alias,
    required this.recordId,
    required this.modelType,
    required this.provenanceId,
    required this.organizationRefs,
  });

  factory AliasIndexEntry.fromSnapshot({
    required OrganismAlias alias,
    required Map<String, dynamic> data,
  }) {
    final orgMap = Map<String, AliasOrganizationRef>.from(
      (data['organizationRefs'] as Map<String, dynamic>? ?? const {})
          .map(
        (key, value) => MapEntry(
          key,
          AliasOrganizationRef.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
    );
    final modelName = data['modelType']?.toString();
    final modelType = ModelType.values.firstWhere(
      (type) => type.name == modelName,
      orElse: () => ModelType.unknown,
    );
    return AliasIndexEntry(
      alias: alias,
      recordId: data['recordId']?.toString() ?? '',
      modelType: modelType,
      provenanceId: data['provenanceId']?.toString() ?? '',
      organizationRefs: orgMap,
    );
  }

  final OrganismAlias alias;
  final String recordId;
  final ModelType modelType;
  final String provenanceId;
  final Map<String, AliasOrganizationRef> organizationRefs;

  @override
  List<Object?> get props => [alias, recordId, modelType, provenanceId, organizationRefs];
}

class AliasOrganizationRef extends Equatable {
  const AliasOrganizationRef({
    required this.recordId,
    required this.localGenetId,
    this.updatedAt,
  });

  factory AliasOrganizationRef.fromJson(Map<String, dynamic> json) {
    return AliasOrganizationRef(
      recordId: json['recordId']?.toString() ?? '',
      localGenetId: json['localGenetId']?.toString() ?? '',
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  final String recordId;
  final String localGenetId;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [recordId, localGenetId, updatedAt];
}

class _AliasKey extends Equatable {
  const _AliasKey({required this.sourceSystem, required this.value});

  final String sourceSystem;
  final String value;

  @override
  List<Object?> get props => [
    sourceSystem.trim().toLowerCase(),
    value.trim().toLowerCase(),
  ];
}
