import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:seafoundry_community/errors/domain_errors.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/repositories/inventory/inventory_record_repository.dart';
import 'package:seafoundry_community/repositories/inventory/site_repository.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/services/structure_capacity_service.dart';

class GroupRepository extends InventoryRecordRepository<Group> {
  GroupRepository({
    required super.organization,
    required super.user,
    required super.eventRepository,
    required super.snapshotService,
    required super.firestore,
    OrganismContext? organismContext,
    StructureCapacityService? structureCapacityService,
    SiteRepository? siteRepository,
    super.enforceAuth = true,
  }) : _structureCapacityService =
           structureCapacityService ?? StructureCapacityService.disabled(),
       _siteRepository = siteRepository,
       super(
         modelType: ModelType.group,
         organismContext:
             organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       );

  final StructureCapacityService _structureCapacityService;
  final SiteRepository? _siteRepository;

  @override
  Future<Group> createRecord(
    Group partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  }) async {
    await _maybeEnforceChildCapacity(
      parent: parent,
      childTypeId: partialRecord.groupTypeId,
      excludeRecordId: null,
    );
    return super.createRecord(
      partialRecord,
      parent,
      base: base,
    );
  }

  @override
  Future<Group> moveRecord({
    required Group record,
    required GraphNodeRecord fromParent,
    required GraphNodeRecord toParent,
    required Transaction transaction,
    required String moveOutSlug,
    required String moveInSlug,
    String? moveOutEventId,
    String? moveInEventId,
    String? partialNewOrganismSlug,
    String? partialNewOrganismId,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    await _maybeEnforceChildCapacity(
      parent: toParent,
      childTypeId: record.groupTypeId,
      excludeRecordId: record.id,
    );
    return super.moveRecord(
      record: record,
      fromParent: fromParent,
      toParent: toParent,
      transaction: transaction,
      moveOutSlug: moveOutSlug,
      moveInSlug: moveInSlug,
      moveOutEventId: moveOutEventId,
      moveInEventId: moveInEventId,
      partialNewOrganismSlug: partialNewOrganismSlug,
      partialNewOrganismId: partialNewOrganismId,
      partialSelection: partialSelection,
      moveReason: moveReason,
      base: base,
    );
  }

  Stream<List<Group>> groupsForSite(Site site, {bool shallow = false}) =>
      streamRecordsForUrlPath(site.urlPath, shallow: shallow);

  /// Update a group record and create a correction event documenting the changes
  ///
  /// Computes field-level diffs between original and updated records,
  /// persists the update, and creates a CorrectionEvent with EventType.inventoryRecordCorrection.
  Future<Group> updateGroupWithCorrection({
    required Group originalGroup,
    required Group updatedGroup,
    String? notes,
  }) async {
    // Compute changes map
    final changes = _computeGroupChanges(originalGroup, updatedGroup);

    // Update the record
    await updateRecord(updatedGroup);

    // Create correction event if there are actual changes
    if (changes.isNotEmpty) {
      await eventRepository.createInventoryRecordCorrectionEvent(
        originalRecord: originalGroup,
        updatedRecord: updatedGroup,
        changes: changes,
        notes: notes,
      );
    }

    return updatedGroup;
  }

  /// Compute field-level changes between two group records
  Map<String, dynamic> _computeGroupChanges(Group original, Group updated) {
    final changes = <String, dynamic>{};

    if (original.name != updated.name) {
      changes['name'] = {'from': original.name, 'to': updated.name};
    }
    if (original.groupTypeId != updated.groupTypeId) {
      changes['groupTypeId'] = {
        'from': original.groupTypeId,
        'to': updated.groupTypeId,
      };
    }
    if (original.description != updated.description) {
      changes['description'] = {
        'from': original.description,
        'to': updated.description,
      };
    }
    if (original.capacity != updated.capacity) {
      changes['capacity'] = {'from': original.capacity, 'to': updated.capacity};
    }
    if (original.rowIndex != updated.rowIndex) {
      changes['rowIndex'] = {'from': original.rowIndex, 'to': updated.rowIndex};
    }
    if (original.colIndex != updated.colIndex) {
      changes['colIndex'] = {'from': original.colIndex, 'to': updated.colIndex};
    }

    return changes;
  }

  Future<void> _maybeEnforceChildCapacity({
    required GraphNodeRecord parent,
    required String childTypeId,
    String? excludeRecordId,
  }) async {
    final organismKind = await _resolveOrganismKindFor(parent);
    final evaluation = await previewChildCapacity(
      parent: parent,
      childTypeId: childTypeId,
      excludeRecordId: excludeRecordId,
      organismKindOverride: organismKind,
    );
    if (evaluation == null) {
      return;
    }
    if (evaluation.isOverCapacity) {
      throw CapabilityConstraintError(
        message: evaluation.blockingMessage,
        recoverySuggestion:
            'Select a different parent or relocate existing structures first.',
        capability: 'structureCapacity',
        context: {
          'parentId': parent.id,
          'childType': childTypeId,
          'projectedUnits': evaluation.projectedUnits,
          'maxUnits': evaluation.rule?.maxUnits,
        },
      );
    }
    if (evaluation.isWarning) {
      LoggingService.instance.warning('Structure nearing capacity', {
        'parentId': parent.id,
        'childType': childTypeId,
        'projectedUnits': evaluation.projectedUnits,
        'maxUnits': evaluation.rule?.maxUnits,
      });
    }
  }

  Future<StructureCapacityResult?> previewChildCapacity({
    required GraphNodeRecord parent,
    required String childTypeId,
    String? excludeRecordId,
    OrganismKind? organismKindOverride,
  }) async {
    if (!_structureCapacityService.isEnabled || parent is! Group) {
      return null;
    }
    await _structureCapacityService.ensureInitialized();
    final childType = GroupType.builtins[childTypeId] ?? GroupType.group;
    final currentCount = await _countChildren(
      parentId: parent.id,
      childTypeId: childType.id,
      excludeRecordId: excludeRecordId,
    );
    final result = _structureCapacityService.evaluate(
      StructureCapacityRequest.forChildStructures(
        containerType: parent.groupType,
        targetGroupType: childType,
        organismKind: organismKindOverride ?? organismContext.kind,
        currentUnits: currentCount,
        deltaUnits: 1,
      ),
    );
    if (!result.hasRule) {
      return null;
    }
    return result;
  }

  Future<OrganismKind> _resolveOrganismKindFor(GraphNodeRecord parent) async {
    if (parent is Site) {
      return _pickOrganismForSite(parent);
    }
    if (parent is Group) {
      final siteRepository = _siteRepository;
      if (siteRepository != null) {
        final site = await siteRepository.getRecordForId(parent.siteId);
        if (site != null) {
          return _pickOrganismForSite(site);
        }
      }
    }
    return organismContext.kind;
  }

  OrganismKind _pickOrganismForSite(Site site) {
    if (site.supportedOrganismKinds.contains(organismContext.kind)) {
      return organismContext.kind;
    }
    if (site.supportedOrganismKinds.isNotEmpty) {
      return site.supportedOrganismKinds.first;
    }
    return organismContext.kind;
  }

  Future<int> _countChildren({
    required String parentId,
    required String childTypeId,
    String? excludeRecordId,
  }) async {
    try {
      // Compound aggregation query — server-side count, no doc reads.
      final aggregation = await collectionRef
          .where('parentId', isEqualTo: parentId)
          .where('groupTypeId', isEqualTo: childTypeId)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      var count = aggregation.count ?? 0;
      // Subtract the excluded record if it would have been counted.
      if (excludeRecordId != null && count > 0) {
        final excluded = await collectionRef
            .doc(excludeRecordId)
            .get()
            .timeout(const Duration(seconds: 10));
        if (excluded.exists) {
          final data = excluded.data();
          if (data?['parentId'] == parentId &&
              data?['groupTypeId'] == childTypeId) {
            count -= 1;
          }
        }
      }
      return count;
    } on TimeoutException {
      LoggingService.instance.warning(
        'Timeout counting children for parent $parentId',
      );
      return 0;
    }
  }

  /// Find a group by name within a specific site using case-insensitive matching.
  ///
  /// Returns the first matching group or null if not found.
  /// Uses an in-memory filter on the current snapshot for efficiency.
  Future<Group?> findByNameInSite(String siteId, String groupName) async {
    if (siteId.trim().isEmpty || groupName.trim().isEmpty) return null;

    final normalizedName = groupName.trim().toLowerCase();

    // Use current snapshot from the stream for efficiency
    final groups = await streamAll.first;
    return groups.firstWhereOrNull(
      (group) =>
          group.siteId == siteId &&
          group.name.toLowerCase() == normalizedName,
    );
  }
}
