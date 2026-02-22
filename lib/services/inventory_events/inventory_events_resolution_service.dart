// @tier: community
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/inventory_events/inventory_events_constants.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';
import 'package:seafoundry_app/widgets/spreadsheet/inventory/inventory_event_row.dart';

/// Service for resolving record references during inventory event hydration.
///
/// Handles resolution of organisms, genets, groups, sites, and user names
/// with caching to minimize Firestore reads.
class InventoryEventsResolutionService {
  InventoryEventsResolutionService({
    required RecordRepository recordRepository,
  }) : _recordRepository = recordRepository;

  final RecordRepository _recordRepository;
  final Map<String, String> _userNameCache = {};

  /// Resolves a user ID to a display name.
  ///
  /// Uses caching to avoid repeated lookups.
  Future<String> resolveUserName(String userId) async {
    return resolveUserDisplayName(
      recordRepository: _recordRepository,
      userId: userId,
      cache: _userNameCache,
    );
  }

  /// Prefetches user names for a set of user IDs.
  ///
  /// Populates the cache to speed up subsequent [resolveUserName] calls.
  Future<void> prefetchUserNames(Set<String> userIds) async {
    if (userIds.isEmpty) return;
    const batchSize = 20;
    final ids = userIds.toList();
    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      try {
        await Future.wait(
          batch.map(
            (id) => resolveUserDisplayName(
              recordRepository: _recordRepository,
              userId: id,
              cache: _userNameCache,
            ),
          ),
        );
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to prefetch user names batch starting at $i',
          error,
          stackTrace,
        );
        // Continue with next batch rather than failing entirely
      }
    }
  }

  /// Resolves a record reference to its display information.
  ///
  /// Handles groups, organism records, and sites. Uses the provided caches
  /// to minimize Firestore reads.
  ///
  /// Returns null if the record cannot be resolved or is of an unsupported type.
  Future<ResolvedRecordInfo?> resolveRecordReference({
    required ModelType? modelType,
    required String? recordId,
    required Map<String, Group> groupLookup,
    required Map<String, String> siteLookup,
    required Map<String, OrganismRecord?> organismCache,
    required Map<String, Genet?> genetCache,
    required String? organizationId,
    required bool Function() isClosed,
  }) async {
    if (modelType == null || recordId == null || recordId.isEmpty) {
      return null;
    }

    switch (modelType) {
      case ModelType.group:
        final group = groupLookup[recordId];
        if (group != null) {
          return ResolvedRecordInfo(
            displayName: group.name,
            siteId: group.siteId,
            parentGroupId: group.parentId,
            structureId: group.id,
            structureName: group.name,
          );
        }
        return null;
      case ModelType.organismRecord:
        if (!organismCache.containsKey(recordId)) {
          try {
            if (isClosed()) return null;
            final organism = await _recordRepository.getRecord<OrganismRecord>(
              ModelType.organismRecord,
              recordId,
              organizationId: organizationId,
            );
            if (!isClosed()) {
              organismCache[recordId] = organism;
            }
          } catch (error, stackTrace) {
            LoggingService.instance.error(
              'Failed to resolve organism $recordId',
              error,
              stackTrace,
            );
            if (!isClosed()) {
              organismCache[recordId] = null;
            }
          }
        }
        final organism = organismCache[recordId];
        if (organism != null) {
          final formId = organism.physicalForm?.formId ??
              organism.metadata?['physicalFormId']?.toString();
          final genetLocalId = await _resolveGenetLocalId(
            organism: organism,
            genetCache: genetCache,
            organizationId: organizationId,
            isClosed: isClosed,
          );
          return ResolvedRecordInfo(
            displayName: organism.name,
            siteId: organism.siteId,
            parentGroupId: organism.groupId,
            structureId: organism.groupId,
            structureName: groupLookup[organism.groupId]?.name,
            physicalForm: formId,
            organism: organism,
            genetLocalId: genetLocalId,
          );
        }
        return null;
      case ModelType.cohort:
      case ModelType.holding:
        return null;
      case ModelType.site:
        final siteName = siteLookup[recordId];
        if (siteName != null) {
          return ResolvedRecordInfo(displayName: siteName, siteId: recordId);
        }
        return null;
      case ModelType.reproductiveEvent:
      case ModelType.organization:
      case ModelType.user:
      case ModelType.genet:
      case ModelType.recordType:
      case ModelType.event:
      case ModelType.invitation:
      case ModelType.brandProfile:
      case ModelType.mediaAsset:
      case ModelType.publicPlaylist:
      case ModelType.publicDigest:
      case ModelType.publicImpactPoint:
      case ModelType.visualKpiSnapshot:
      case ModelType.environmentalEvent:
      case ModelType.monitoringSchedule:
      case ModelType.mission:
      case ModelType.vessel:
      case ModelType.permit:
      case ModelType.deliverable:
      case ModelType.post:
      case ModelType.funder:
      case ModelType.zone:
      case ModelType.subplot:
      case ModelType.unknown:
        return null;
    }
  }

  Future<String?> _resolveGenetLocalId({
    required OrganismRecord organism,
    required Map<String, Genet?> genetCache,
    required String? organizationId,
    required bool Function() isClosed,
  }) async {
    final genetId = GenetIdResolver.resolve(organism);
    final genetRef = organism.foreignKeys['genetId'];
    var genetLocalId = _genetLocalIdFromMetadata(genetRef?.metadata);

    if ((genetLocalId == null || genetLocalId.isEmpty) &&
        genetId != null &&
        genetId.isNotEmpty) {
      if (!genetCache.containsKey(genetId)) {
        try {
          if (isClosed()) return null;
          final genet = await _recordRepository.getRecord<Genet>(
            ModelType.genet,
            genetId,
            organizationId: organizationId,
          );
          if (!isClosed()) {
            genetCache[genetId] = genet;
          }
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to resolve genet $genetId',
            error,
            stackTrace,
          );
          if (!isClosed()) {
            genetCache[genetId] = null;
          }
        }
      }

      final genet = genetCache[genetId];
      genetLocalId ??= _genetLocalIdFromGenet(genet);
    }

    return genetLocalId;
  }
}

// Helper functions for genet resolution

String? _stringFromMetadata(
  Map<String, dynamic>? metadata,
  List<String> keys,
) {
  if (metadata == null) return null;
  for (final key in keys) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

Map<String, dynamic>? _nestedMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  final nested = metadata['metadata'];
  if (nested is Map<String, dynamic>) {
    return nested;
  }
  if (nested is Map) {
    return nested.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? _genetLocalIdFromMetadata(Map<String, dynamic>? metadata) {
  return _stringFromMetadata(metadata, genetLocalIdKeys) ??
      _stringFromMetadata(_nestedMetadata(metadata), genetLocalIdKeys);
}

String? _genetLocalIdFromGenet(Genet? genet) {
  if (genet == null) return null;
  final name = genet.name.trim();
  if (name.isNotEmpty) {
    return name;
  }
  return _genetLocalIdFromMetadata(genet.metadata);
}
