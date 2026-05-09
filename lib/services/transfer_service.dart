// @tier: community
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:seafoundry_app/errors/domain_errors.dart' as domainErrors;
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/events/event_permit_metadata.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/models/events/transfer_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/transfer_manifest.dart';
import 'package:seafoundry_app/models/transfer_manifest_snapshots.dart';
import 'package:seafoundry_app/models/transfer_status.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/loan_event_type.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/transfer_ownership_type.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/manual_transfer_registration_service.dart';
import 'package:seafoundry_app/services/outplant_geometry_builder.dart';
import 'package:seafoundry_app/services/custody_history_service.dart';
import 'package:seafoundry_app/services/provenance_crosswalk_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/transfer_notification_result.dart';
import 'package:seafoundry_app/utils/js_error_utils.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';
import 'package:seafoundry_app/utils/validation_utils.dart';

part 'transfer_service_acceptance.dart';
part 'transfer_service_initiation.dart';
part 'transfer_service_manifest.dart';
part 'transfer_service_validation.dart';

/// Coordinates the complete genet transfer lifecycle (initiate -> update -> ship
/// -> receive/reject). Every public method enforces the same state-machine
/// invariants and surfaces user-friendly [TransferWorkflowException] messages so
/// dialogs/cubits can guide remediation (e.g., quantity corrections).
/// Manifests act as the canonical payload passed between organizations.
class TransferService implements ManualTransferRegistrationService {
  TransferService({
    required ProvenanceRepository provenanceRepository,
    required EventRepository eventRepository,
    OrganizationRepository? organizationRepository,
    RecordRepository? recordRepository,
    OrganismRecordRepository? organismRecordRepository,
    FirebaseFirestore? db,
    String Function()? idGenerator,
    OutplantGeometryBuilder? geometryBuilder,
    ProvenanceCrosswalkService? crosswalkService,
  }) : _provenanceRepository = provenanceRepository,
       _eventRepository = eventRepository,
       _organizationRepository =
           organizationRepository ??
           (db != null
               ? OrganizationRepository(firestore: db)
               : throw ArgumentError(
                   'OrganizationRepository or FirebaseFirestore must be provided',
                 )),
       _recordRepository =
           recordRepository ??
           (throw ArgumentError(
             'RecordRepository must be provided (configured via RecordRepository.configure() in app.dart)',
           )),
       _organismRecordRepository = organismRecordRepository,
       _db = db ?? (throw ArgumentError('FirebaseFirestore must be provided')),
       _geometryBuilder = geometryBuilder ?? const OutplantGeometryBuilder(),
       _crosswalkService = crosswalkService {
    _idGenerator = idGenerator ?? (() => generateId(firestore: _db));
  }

  final ProvenanceRepository _provenanceRepository;
  final EventRepository _eventRepository;
  final OrganizationRepository _organizationRepository;
  final RecordRepository _recordRepository;
  final OrganismRecordRepository? _organismRecordRepository;
  final FirebaseFirestore _db;
  late final String Function() _idGenerator;
  final OutplantGeometryBuilder _geometryBuilder;
  final ProvenanceCrosswalkService? _crosswalkService;

  // ---------------------------------------------------------------------------
  // Public API - Transfer Initiation
  // ---------------------------------------------------------------------------

  /// Initiates a transfer (draft -> pending) and notifies the destination
  /// organization. Generates a fresh manifest each time so downstream dialogs
  /// can display a consistent summary.
  ///
  /// Throws [TransferWorkflowException] when the source genet or destination
  /// organization cannot be resolved.
  Future<TransferEvent> initiateTransfer({
    required String genetRecordId,
    required String toOrganizationId,
    required int quantity,
    String? sourceStructureUrlPath,
    String? comment,
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    OutplantGeometryInput? geometryInput,
    Map<String, int>? inventorySelection,
    TransferOwnershipType? ownershipType,
    String? originalOwnerOrganizationId,
  }) async {
    return PerformanceAnalyzer.measure(
      'TransferService.initiateTransfer',
      () => performInitiateTransfer(
        genetRecordId: genetRecordId,
        toOrganizationId: toOrganizationId,
        quantity: quantity,
        sourceStructureUrlPath: sourceStructureUrlPath,
        comment: comment,
        permitMetadata: permitMetadata,
        provenanceTypeOverride: provenanceTypeOverride,
        lifeStageOverride: lifeStageOverride,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
        geometryInput: geometryInput,
        inventorySelection: inventorySelection,
        ownershipType: ownershipType,
        originalOwnerOrganizationId: originalOwnerOrganizationId,
      ),
      metadata: {
        'genetRecordId': genetRecordId,
        'toOrganizationId': toOrganizationId,
        'quantity': quantity,
      },
    );
  }

  /// Initiates a transfer to a recipient via email address (instead of org ID).
  /// Used when the recipient may not be in the system yet. The transfer is
  /// created in pending state and the recipient can claim it later.
  ///
  /// Unlike [initiateTransfer], this does not require an existing organization.
  /// The manifest's toOrganization will contain email-only placeholder data.
  ///
  /// Throws [TransferWorkflowException] when the source genet cannot be found
  /// or email validation fails.
  Future<TransferEvent> initiateTransferToEmail({
    required String genetRecordId,
    required String toOrganizationEmail,
    required int quantity,
    String? sourceStructureUrlPath,
    String? comment,
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    OutplantGeometryInput? geometryInput,
    Map<String, int>? inventorySelection,
    TransferOwnershipType? ownershipType,
    String? originalOwnerOrganizationId,
  }) async {
    return PerformanceAnalyzer.measure(
      'TransferService.initiateTransferToEmail',
      () => performInitiateTransferToEmail(
        genetRecordId: genetRecordId,
        toOrganizationEmail: toOrganizationEmail,
        quantity: quantity,
        sourceStructureUrlPath: sourceStructureUrlPath,
        comment: comment,
        permitMetadata: permitMetadata,
        provenanceTypeOverride: provenanceTypeOverride,
        lifeStageOverride: lifeStageOverride,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
        geometryInput: geometryInput,
        inventorySelection: inventorySelection,
        ownershipType: ownershipType,
        originalOwnerOrganizationId: originalOwnerOrganizationId,
      ),
      metadata: {
        'genetRecordId': genetRecordId,
        'toOrganizationEmail': toOrganizationEmail,
        'quantity': quantity,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Public API - Transfer Status Changes
  // ---------------------------------------------------------------------------

  /// Marks a pending transfer as shipped (pending -> shipped).
  Future<TransferEvent> markTransferShipped({
    required String transferEventId,
    String? trackingNumber,
    String? comment,
  }) async {
    return performMarkTransferShipped(
      transferEventId: transferEventId,
      trackingNumber: trackingNumber,
      comment: comment,
    );
  }

  /// Accepts an incoming transfer (pending/shipped -> received) and creates a
  /// genet record based on the manifest payload. Validates manifest ownership
  /// before mutating any data so the receiving dialog can surface actionable
  /// errors when the payload is stale.
  Future<ProvenanceRecord> acceptTransfer({
    required String transferEventId,
    required String newGenetName,
    String? localGenetId,
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    OutplantGeometryInput? geometryInput,
    String? targetUrlPath,
    String? destinationSiteId,
    String? destinationGroupId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) async {
    return performAcceptTransfer(
      transferEventId: transferEventId,
      newGenetName: newGenetName,
      localGenetId: localGenetId,
      provenanceTypeOverride: provenanceTypeOverride,
      lifeStageOverride: lifeStageOverride,
      geometryInput: geometryInput,
      targetUrlPath: targetUrlPath,
      destinationSiteId: destinationSiteId,
      destinationGroupId: destinationGroupId,
      ownerOrganizationId: ownerOrganizationId,
      managingOrganizationId: managingOrganizationId,
    );
  }

  /// Rejects an incoming transfer (pending/shipped -> rejected) and appends the
  /// rejection note to both the manifest and notification for traceability.
  Future<void> rejectTransfer({
    required String transferEventId,
    String? reason,
  }) async {
    return performRejectTransfer(
      transferEventId: transferEventId,
      reason: reason,
    );
  }

  /// Cancels an outbound transfer (pending/shipped -> cancelled).
  ///
  /// Only the sender organization can cancel. This unlocks any organisms
  /// that were locked for this transfer and notifies the recipient if one exists.
  Future<void> cancelTransfer({
    required String transferEventId,
    String? reason,
  }) async {
    return performCancelTransfer(
      transferEventId: transferEventId,
      reason: reason,
    );
  }

  /// Updates a pending transfer's quantity/comment while regenerating the
  /// manifest.
  Future<TransferEvent> updatePendingTransfer({
    required String transferEventId,
    required int quantity,
    String? comment,
    EventPermitMetadata? permitMetadata,
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    OutplantGeometryInput? geometryInput,
  }) async {
    return PerformanceAnalyzer.measure(
      'TransferService.updatePendingTransfer',
      () => performUpdatePendingTransfer(
        transferEventId: transferEventId,
        quantity: quantity,
        comment: comment,
        permitMetadata: permitMetadata,
        provenanceTypeOverride: provenanceTypeOverride,
        lifeStageOverride: lifeStageOverride,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
        geometryInput: geometryInput,
      ),
      metadata: {'transferEventId': transferEventId, 'quantity': quantity},
    );
  }

  // ---------------------------------------------------------------------------
  // Public API - Transfer Queries
  // ---------------------------------------------------------------------------

  /// Returns all pending/shipped transfers addressed to the current
  /// organization. Used by the pending-transfers dialog to render the inbox.
  Future<List<TransferEvent>> getPendingTransfers() async {
    try {
      final organization = _provenanceRepository.organization;
      final snapshot = await _db
          .collection('events')
          .where('eventTypeId', whereIn: LoanEventType.queryIds)
          .where('toOrganizationId', isEqualTo: organization.id)
          .where(
            'status',
            whereIn: [
              TransferStatus.pending.value,
              TransferStatus.shipped.value,
            ],
          )
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransferEvent.fromJson(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get pending transfers',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Returns all pending/shipped transfers created by the current organization.
  /// Used by the pending-transfers dialog to render the outbox.
  Future<List<TransferEvent>> getOutboundPendingTransfers() async {
    try {
      final organization = _provenanceRepository.organization;
      final snapshot = await _db
          .collection('events')
          .where('organizationId', isEqualTo: organization.id)
          .where('eventTypeId', whereIn: LoanEventType.queryIds)
          .orderBy('createdAt', descending: true)
          .get();

      final transfers = <TransferEvent>[];
      for (final doc in snapshot.docs) {
        final transfer = TransferEvent.fromJson(doc.data());
        final status = transfer.status;
        if (status != TransferStatus.pending.value &&
            status != TransferStatus.shipped.value) {
          continue;
        }
        transfers.add(transfer);
      }

      return transfers;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get outbound pending transfers',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Public API - Manifest
  // ---------------------------------------------------------------------------

  /// Retrieve the manifest stored for a transfer.
  Future<TransferManifest> getTransferManifest(String transferEventId) async {
    final transfer = await requireTransferEvent(transferEventId);
    return requireManifest(transfer);
  }

  /// Try to reconstruct the source genet using the transfer manifest.
  Future<ProvenanceRecord?> getSourceGenet(TransferEvent transfer) async {
    final manifestData = transfer.manifest;
    if (manifestData == null) {
      return null;
    }
    final manifest = TransferManifest.fromJson(manifestData);
    try {
      final genetMap = manifest.genet.toJson();
      final metadata = _hydrateManifestGenetMetadata(genetMap);
      return ProvenanceRecord.fromJson({
        'id': genetMap['id'],
        'organismKind': OrganismKind.coral.name,
        'provenanceKind': metadata['provenanceKind'] ?? 'genet',
        'displayName': genetMap['name'],
        'localGenetId': genetMap['localGenetId'],
        'provenanceId': genetMap['provenanceId'],
        'speciesId': genetMap['speciesId'],
        'metadata': metadata,
        'aliasLabels': _manifestAliasLabels(genetMap),
      }, id: genetMap['id'] as String);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to reconstruct genet from manifest',
        e,
        stackTrace,
      );
    }

    return null;
  }

  Map<String, dynamic> _hydrateManifestGenetMetadata(
    Map<String, dynamic> genetMap,
  ) {
    final metadata = <String, dynamic>{};
    final rawMetadata = genetMap['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      metadata.addAll(Map<String, dynamic>.from(rawMetadata));
    } else if (rawMetadata is Map) {
      metadata.addAll(Map<String, dynamic>.from(rawMetadata));
    }

    for (final key in _manifestMetadataKeys) {
      _copyIfPresent(target: metadata, source: genetMap, key: key);
    }
    return metadata;
  }

  List<String> _manifestAliasLabels(Map<String, dynamic> genetMap) {
    final aliases = genetMap['aliases'];
    if (aliases is! List) {
      return const [];
    }
    final values = <String>[];
    for (final entry in aliases) {
      if (entry is Map && entry['value'] is String) {
        final value = (entry['value'] as String).trim();
        if (value.isNotEmpty) {
          values.add(value);
        }
      }
    }
    return values;
  }

  void _copyIfPresent({
    required Map<String, dynamic> target,
    required Map<String, dynamic> source,
    required String key,
  }) {
    if (source[key] != null) {
      target[key] = source[key];
    }
  }

  static const List<String> _manifestMetadataKeys = <String>[
    'provenanceTypeId',
    'clonalId',
    'accessionNumber',
    'notes',
    'provenance',
    'parentGameteIds',
    'parentCohortId',
    'donorGenotypeId',
    'damGameteIds',
    'sireGameteIds',
    'crossDate',
    'readyForOutplant',
    'aliases',
  ];

  // ---------------------------------------------------------------------------
  // Public API - Manual Registration (ManualTransferRegistrationService)
  // ---------------------------------------------------------------------------

  @override
  Future<ProvenanceRecord> registerManualGenet({
    required String name,
    required String speciesId,
    required ProvenanceType provenanceType,
    required LifeStage lifeStage,
    OrganismKind organismKind = OrganismKind.coral,
    String? physicalFormId,
    SizeSpec sizeSpec = const SizeSpec(),
    String? comment,
    String? fromOrganizationId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    String? sourceContactEmail,
    String? sourceProvenanceId,
    List<OrganismAlias> aliases = const [],
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw TransferWorkflowException('Genet name is required.');
    }

    final normalizedAliases = aliases
        .where((alias) => alias.value.trim().isNotEmpty)
        .map((alias) => alias.toJson())
        .toList(growable: false);

    final provenanceKind = provenanceType.defaultProvenanceKind;

    final metadata = <String, dynamic>{
      'provenanceTypeId': provenanceType.id,
      'lifeStageId': lifeStage.id,
      'manualRegistration': true,
    };
    if (physicalFormId != null) {
      metadata['physicalFormId'] = physicalFormId;
    }
    if (ownerOrganizationId != null && ownerOrganizationId.trim().isNotEmpty) {
      metadata['ownerOrganizationId'] = ownerOrganizationId.trim();
    }
    if (managingOrganizationId != null &&
        managingOrganizationId.trim().isNotEmpty) {
      metadata['managingOrganizationId'] = managingOrganizationId.trim();
    }
    if (fromOrganizationId != null && fromOrganizationId.trim().isNotEmpty) {
      metadata['sourceOrganizationId'] = fromOrganizationId.trim();
    }
    if (sourceContactEmail != null && sourceContactEmail.trim().isNotEmpty) {
      metadata['sourceContactEmail'] = sourceContactEmail.trim();
    }
    if (sourceProvenanceId != null && sourceProvenanceId.trim().isNotEmpty) {
      metadata['sourceProvenanceId'] = sourceProvenanceId.trim();
    }
    final provenance = <String, dynamic>{'registrationSource': 'manual'};
    if (fromOrganizationId != null && fromOrganizationId.trim().isNotEmpty) {
      provenance['sendingOrganization'] = fromOrganizationId.trim();
    }
    if (sourceProvenanceId != null && sourceProvenanceId.trim().isNotEmpty) {
      provenance['sourceProvenanceId'] = sourceProvenanceId.trim();
    }

    final notes = comment?.trim().isEmpty == true ? null : comment?.trim();
    if (notes != null) {
      metadata['notes'] = notes;
    }

    final id = _idGenerator();
    final organization = _provenanceRepository.organization;
    metadata['urlPath'] = '${organization.domain}/genetics/$id';
    metadata['internalPath'] = '${organization.internalPath}/genetics/$id';

    final genet = ProvenanceRecord(
      id: id,
      organismKind: organismKind,
      provenanceKind: provenanceKind,
      displayName: trimmedName,
      speciesId: speciesId,
      metadata: metadata,
      aliasLabels: normalizedAliases.map((e) => e['value'] as String).toList(),
    );
    return _provenanceRepository.createProvenanceRecord(genet);
  }

  // ---------------------------------------------------------------------------
  // Public API - Crosswalk Retry
  // ---------------------------------------------------------------------------

  /// Checks if a transfer event has a failed crosswalk registration.
  ///
  /// Returns true if there is a pending crosswalk failure that needs attention.
  Future<bool> hasCrosswalkRegistrationFailure(String transferEventId) async {
    try {
      final doc = await _db.collection('events').doc(transferEventId).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data();
      final failure =
          data?['crosswalkRegistrationFailure'] as Map<String, dynamic>?;
      return failure != null && failure['status'] == 'pending_retry';
    } catch (e) {
      LoggingService.instance.debug(
        'Error checking crosswalk failure for transfer $transferEventId: $e',
      );
      return false;
    }
  }
}

/// User-friendly exception surfaced by [TransferService] when a workflow guard
/// fails (e.g., missing genet). Callers can pattern
/// match on this type to distinguish expected validation failures from system
/// errors.
class TransferWorkflowException implements Exception {
  const TransferWorkflowException(this.message);

  final String message;

  @override
  String toString() => 'TransferWorkflowException: $message';
}
