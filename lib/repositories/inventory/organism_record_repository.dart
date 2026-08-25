import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_community/errors/domain_errors.dart';
import 'package:seafoundry_community/models/inventory/organism_extensions.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/repositories/firebase_utils.dart';
import 'package:seafoundry_community/repositories/inventory/inventory_record_repository.dart';
import 'package:seafoundry_community/services/genet_id_resolver.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/services/organism_record_change_service.dart';
import 'package:seafoundry_community/services/structure_capacity_service.dart';
import 'package:seafoundry_community/services/validation_service.dart';

part 'organism_record_repository_helpers.dart';
part 'organism_record_repository_queries.dart';
part 'organism_record_repository_mutations.dart';
part 'organism_record_repository_status.dart';

/// Base class for OrganismRecordRepository containing shared state and
/// abstract methods required by mixins.
abstract class _OrganismRecordRepositoryBase
    extends InventoryRecordRepository<OrganismRecord> {
  _OrganismRecordRepositoryBase({
    required super.organization,
    required super.user,
    required super.firestore,
    required super.eventRepository,
    OrganismContext? organismContext,
    StructureCapacityService? structureCapacityService,
    super.enforceAuth = true,
  })  : changeService = const OrganismRecordChangeService(),
        structureCapacityService =
            structureCapacityService ?? StructureCapacityService.disabled(),
        super(
          modelType: ModelType.organismRecord,
          organismContext:
              organismContext ?? OrganismContext.forKind(OrganismKind.coral),
        );

  /// Service for detecting changes between organism record versions.
  final OrganismRecordChangeService changeService;

  /// Service for validating structure capacity constraints.
  final StructureCapacityService structureCapacityService;

  CollectionReference<Map<String, dynamic>> get archivedCollectionRef =>
      db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection('archived_organism_records');

  /// Count organisms in a specific group (abstract for cross-mixin access).
  Future<int> countByGroup(String groupId);
}

/// Repository for managing organism records in Firestore.
///
/// This repository provides CRUD operations and streaming access to
/// OrganismRecord documents, which represent the universal five-axis
/// data model for inventory holdings across all organism types.
///
/// The repository is decomposed into focused mixins:
/// - [_OrganismRecordRepositoryHelpers]: Validation, parsing, slug generation
/// - [_OrganismRecordRepositoryQueries]: Streams and search operations
/// - [_OrganismRecordRepositoryMutations]: Create, update, population changes
/// - [_OrganismRecordRepositoryStatus]: Health, archive, outplant status updates
class OrganismRecordRepository extends _OrganismRecordRepositoryBase
    with
        _OrganismRecordRepositoryHelpers,
        _OrganismRecordRepositoryQueries,
        _OrganismRecordRepositoryMutations,
        _OrganismRecordRepositoryStatus {
  OrganismRecordRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    required super.eventRepository,
    super.organismContext,
    super.structureCapacityService,
    super.enforceAuth,
  });

  @override
  bool shouldIncludeRecord(OrganismRecord record) {
    final metadata = record.metadata;
    if (metadata?['archived'] == true) {
      return false;
    }
    if (metadata?['isDeleted'] == true) {
      return false;
    }
    return true;
  }

  @override
  Future<void> updateRecord(
    OrganismRecord record, {
    WriteBatch? batch,
  }) async {
    final guardedRecord = _ensureArchivedWhenZero(record);
    await super.updateRecord(guardedRecord, batch: batch);
  }

  OrganismRecord _ensureArchivedWhenZero(OrganismRecord record) {
    if (record.measurement.value > 0) {
      return record;
    }
    if (_isArchivedRecord(record)) {
      return record;
    }

    final now = DateTime.now().toIso8601String();
    final updatedAt = record.updatedAt.isMissing ? now : record.updatedAt;
    final updatedById = record.updatedById.isMissing ? user.id : record.updatedById;
    final existingMetadata = record.metadata ?? const <String, dynamic>{};

    final metadata = <String, dynamic>{
      ...existingMetadata,
      kArchivedFlagKey: true,
      kArchivedAtKey: existingMetadata[kArchivedAtKey] ?? updatedAt,
      kArchivedByIdKey: existingMetadata[kArchivedByIdKey] ?? user.id,
      kArchivedReasonTypeKey:
          existingMetadata[kArchivedReasonTypeKey] ?? kArchiveReasonTypeDeleted,
    };

    return record.copyWith(
      metadata: metadata,
      updatedAt: updatedAt,
      updatedById: updatedById,
    );
  }

  bool _isArchivedRecord(OrganismRecord record) {
    final metadata = record.metadata;
    return metadata?['archived'] == true || metadata?['isDeleted'] == true;
  }

  // All interface methods are implemented in the mixins.
  // The mixin chain provides implementations for:
  // - Streams: streamBySite, streamByGroup, streamByOrganism, etc.
  // - Queries: queryBySite, queryByGroup, queryByOrganismKind, etc.
  // - Mutations: createRecord, updateRecord, updatePopulation, etc.
  // - Status: updateHealthStatus, archiveOrganismRecord, etc.
}
