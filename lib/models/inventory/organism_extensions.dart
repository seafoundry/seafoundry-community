// @tier: community
import 'package:seafoundry_app/models/inventory/custody_history_entry.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/custody_history_service.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';

/// Extension methods for OrganismRecord providing metadata access and helpers
extension OrganismRecordCapabilities on OrganismRecord {
  // Metadata helpers (organism-specific data stored in metadata field)

  /// Health status
  String? get healthStatus => metadata?['healthStatus'] as String?;

  /// Ready for outplant flag
  bool get readyForOutplant => metadata?['readyForOutplant'] == true;

  /// Ready for propagation flag
  bool get readyForPropagation => metadata?['readyForPropagation'] == true;

  /// Pending outplant flag - organism is allocated but not yet outplanted
  bool get isPendingOutplant => metadata?['pendingOutplant'] == true;

  /// Pending transfer ID - organism is locked for outbound transfer.
  /// Null when not locked, contains transferEventId when locked.
  String? get pendingTransferId => metadata?['pendingTransferId'] as String?;

  /// Whether this organism is locked by a pending transfer
  bool get isLockedForTransfer => pendingTransferId != null;

  /// Quantity locked for pending transfer (safely handles int/double)
  int? get lockedQuantityForTransfer {
    final value = metadata?['lockedTransferQuantity'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  /// Pending batch ID - links to planned outplant allocation (exclusive membership)
  String? get pendingBatchId => metadata?['pendingBatchId'] as String?;

  /// Pending allocation details (null if not pending)
  Map<String, dynamic>? get pendingAllocation =>
      safeMapCast(metadata?['pendingAllocation']);

  /// Quantity allocated to pending batch (safely handles int/double)
  int? get pendingQuantity {
    final value = pendingAllocation?['quantity'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  /// Target site ID for pending outplant (null if empty)
  String? get pendingTargetSiteId {
    final value = pendingAllocation?['targetSiteId'] as String?;
    return (value?.isEmpty ?? true) ? null : value;
  }

  /// Target date for pending outplant (stored as ISO 8601 string)
  DateTime? get pendingTargetDate {
    final dateStr = pendingAllocation?['targetDate'] as String?;
    return dateStr != null ? DateTime.tryParse(dateStr) : null;
  }

  /// Whether the pending state is internally consistent.
  /// Returns true if not pending, or if pending with valid batchId and allocation.
  bool get isPendingStateConsistent {
    if (!isPendingOutplant) return true;
    return pendingBatchId != null && pendingAllocation != null;
  }

  /// Whether this organism can be added to a pending batch.
  /// Invariant: Must be readyForOutplant, not already pending, and have population > 0.
  bool get canAddToPendingBatch =>
      readyForOutplant && !isPendingOutplant && measurement.value > 0;

  /// Whether this organism can be transferred.
  /// Blocked when pendingOutplant=true OR pendingTransferId is set.
  ///
  /// IMPORTANT: This constraint should be enforced at the UI layer when selecting
  /// organisms or genets for transfer. The TransferService operates at the genet
  /// level, so validation should occur before calling initiateTransfer().
  ///
  /// Recommended validation patterns:
  /// - Filter out organisms with isPendingOutplant=true from transfer selection
  /// - Filter out organisms with isLockedForTransfer=true from transfer selection
  /// - Show warning when a genet has pending organisms
  /// - Block transfer initiation if any organism for the genet is pending or locked
  bool get canBeTransferred => !isPendingOutplant && !isLockedForTransfer;

  /// User-facing notes/comments
  String? get notes => metadata?['notes'] as String?;

  /// Unique slug identifier
  String? get slug => metadata?['slug'] as String?;

  /// Whether organism is archived
  bool get isArchived => metadata?['archived'] == true;

  /// Alternative identifier/alias
  String? get alias => metadata?['alias'] as String?;


  /// User-assigned tag
  String? get tag => metadata?['tag'] as String?;

  /// Life stage identifier from metadata
  String? get lifeStageId => metadata?['lifeStageId'] as String?;

  /// Coral size measurement (legacy field)
  double? get coralSize {
    final v = metadata?['coralSize'];
    return v is num ? v.toDouble() : null;
  }

  /// Preferred label for UI display.
  ///
  /// Uses tagId first, then falls back to localGenetId, species code + short ID.
  String get displayLabel {
    final recordValue = tagId.trim();
    if (_isMeaningful(recordValue)) {
      return recordValue;
    }
    final localIdValue = localGenetId?.trim();
    if (_isMeaningful(localIdValue)) {
      return localIdValue!;
    }
    final species = Species.fallback(speciesId);
    final shortId = id.length >= 8 ? id.substring(id.length - 4) : id;
    return '${_formatSpeciesCode(species.code)}-$shortId';
  }

  /// Formatted physical form display name (synchronous fallback).
  ///
  /// This is a convenience getter for UI contexts where the PhysicalFormRegistry
  /// is not available or loaded. It derives the display name by formatting the
  /// form ID (e.g., 'settlement_substrate' -> 'Settlement Substrate').
  ///
  /// **Trade-off**: This may differ from the canonical displayName configured
  /// in PhysicalFormRegistry. For authoritative display names, prefer using
  /// `PhysicalFormRegistry.getForm(formId)?.displayName` when available.
  String? get physicalFormDisplayName {
    final formId = physicalForm?.formId;
    if (formId == null) return null;
    return formatSnakeCaseToTitleCase(formId);
  }

  /// Formatted provenance type display name
  String? get provenanceDisplayName => provenanceType?.displayName;

  // ---------------------------------------------------------------------------
  // Chain of Custody
  // ---------------------------------------------------------------------------

  /// Returns the full chain of custody history for this organism.
  ///
  /// The history is ordered chronologically from original creation to current.
  /// Returns an empty list if no custody history exists.
  List<CustodyHistoryEntry> get custodyHistory =>
      CustodyHistoryService.readCustodyHistory(this);

  /// Whether the given organization has ever owned or managed this organism.
  bool hasEverHadCustody(String organizationId) =>
      CustodyHistoryService.hasOrganizationEverHadCustody(
        this,
        organizationId,
      );

  /// Whether the given organization has ever owned this organism.
  bool hasEverOwned(String organizationId) =>
      CustodyHistoryService.hasOrganizationEverOwned(
        this,
        organizationId,
      );

  /// Whether the given organization has ever managed this organism.
  bool hasEverManaged(String organizationId) =>
      CustodyHistoryService.hasOrganizationEverManaged(
        this,
        organizationId,
      );
}

bool _isMeaningful(String? value) {
  if (value == null) return false;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed == '__missing__') return false;
  return true;
}

String _formatSpeciesCode(String code) {
  if (code.isEmpty) return 'Org';
  return code[0].toUpperCase() + code.substring(1).toLowerCase();
}
