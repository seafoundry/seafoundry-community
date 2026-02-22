// @tier: community
import 'package:seafoundry_app/models/inventory/custody_history_entry.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/custody_history_service.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';

/// Physical form capabilities for different organism types
///
/// Defines what operations are possible for each organism based on
/// their biological characteristics and physical form.
class PhysicalFormCapabilities {
  final bool canPropagateAsexually;      // Can be propagated asexually
  final bool canRemount;       // Can be moved to new substrate
  final bool canSpawn;         // Can reproduce sexually
  final bool canMetamorphose;  // Has larval → juvenile transition
  final bool canMolt;          // Sheds exoskeleton (crabs)
  final bool requiresSubstrate; // Needs attachment point

  const PhysicalFormCapabilities({
    this.canPropagateAsexually = false,
    this.canRemount = false,
    this.canSpawn = false,
    this.canMetamorphose = false,
    this.canMolt = false,
    this.requiresSubstrate = false,
  });

  /// Predefined capability sets by organism type

  static const coral = PhysicalFormCapabilities(
    canPropagateAsexually: true,
    canRemount: true,
    canSpawn: true,
    requiresSubstrate: true,
  );

  static const kelp = PhysicalFormCapabilities(
    canPropagateAsexually: true,
    canSpawn: true,
    requiresSubstrate: true,
  );

  static const seagrass = PhysicalFormCapabilities(
    canPropagateAsexually: true,
    canSpawn: true,
    requiresSubstrate: false, // Grows in sediment
  );

  static const oyster = PhysicalFormCapabilities(
    canSpawn: true,
    canMetamorphose: true,
    requiresSubstrate: true,
  );

  static const finfish = PhysicalFormCapabilities(
    canSpawn: true,
    canMetamorphose: true,
    requiresSubstrate: false,
  );

  static const crab = PhysicalFormCapabilities(
    canSpawn: true,
    canMetamorphose: true,
    canMolt: true,
    requiresSubstrate: false,
  );

  static const echinoid = PhysicalFormCapabilities(
    canPropagateAsexually: true, // Urchins can regenerate from body fragments
    canSpawn: true,
    canMetamorphose: true, // Larval settlement stage
    requiresSubstrate: false,
  );

  static const mangrove = PhysicalFormCapabilities(
    canPropagateAsexually: true, // Vegetative propagation via shoot/branch cuttings
    canSpawn: true,    // Flowering/propagule (seed) production
    requiresSubstrate: false, // Grows in sediment/intertidal zones
  );

  static const seaCucumber = PhysicalFormCapabilities(
    canPropagateAsexually: true, // Asexual reproduction through fission (splitting)
    canSpawn: true,
    canMetamorphose: true,
    requiresSubstrate: false,
  );

  /// Get capabilities for an organism kind
  static PhysicalFormCapabilities forOrganism(OrganismKind kind) {
    switch (kind) {
      case OrganismKind.coral:
        return coral;
      case OrganismKind.kelp:
        return kelp;
      case OrganismKind.seagrass:
        return seagrass;
      case OrganismKind.oyster:
        return oyster;
      case OrganismKind.finfish:
        return finfish;
      case OrganismKind.crab:
        return crab;
      case OrganismKind.echinoid:
        return echinoid;
      case OrganismKind.mangrove:
        return mangrove;
      case OrganismKind.seaCucumber:
        return seaCucumber;
    }
  }
}

const Set<LifeStage> _validSpawningParentLifeStages = {
  LifeStage.adult,
  LifeStage.broodstock,
};

/// Extension methods for OrganismRecord providing capability-based operations
extension OrganismRecordCapabilities on OrganismRecord {
  /// Get capabilities for this organism
  PhysicalFormCapabilities get capabilities {
    return PhysicalFormCapabilities.forOrganism(organismKind);
  }

  // Capability checks
  bool get canPropagateAsexually => capabilities.canPropagateAsexually;
  bool get canRemount => capabilities.canRemount;
  bool get canSpawn => capabilities.canSpawn;
  bool get canMetamorphose => capabilities.canMetamorphose;
  bool get canMolt => capabilities.canMolt;
  bool get requiresSubstrate => capabilities.requiresSubstrate;

  // Validation helpers

  /// Validate if this organism can be propagated asexually
  String? validateForPropagation() {
    if (!canPropagateAsexually) {
      return '${organismKind.metadata.displayName} cannot be propagated asexually';
    }

    // Output organisms must be adult or broodstock
    final validStages = ['life_stage_adult', 'life_stage_broodstock'];
    if (!validStages.contains(lifeStage.stage.id)) {
      return 'Only adults or broodstock can be propagated';
    }

    if (measurement.value <= 0) {
      return 'Need at least 1 to propagate';
    }
    return null; // Valid
  }

  /// Validate if this organism can be remounted
  String? validateForRemounting() {
    if (!canRemount) {
      return '${organismKind.metadata.displayName} cannot be remounted';
    }
    if (!requiresSubstrate) {
      return 'This organism does not use substrates';
    }
    return null; // Valid
  }

  /// Validate if this organism can spawn
  String? validateForSpawning() {
    if (!canSpawn) {
      return '${organismKind.metadata.displayName} cannot spawn';
    }

    // Output organisms must be adult, broodstock, or existing gametes
    final validStages = ['life_stage_adult', 'life_stage_broodstock', 'life_stage_gamete'];
    if (!validStages.contains(lifeStage.stage.id)) {
      return 'Only adults, broodstock, or gametes can be used in cross events';
    }

    return null; // Valid
  }

  /// Check if this organism is eligible as a spawning parent.
  bool get isValidSpawningParent {
    if (!canSpawn) return false;
    return _validSpawningParentLifeStages.contains(lifeStage.stage);
  }

  // Metadata helpers (organism-specific data stored in metadata field)

  /// Source coral for fragments (coral-specific)
  String? get fragmentSource => metadata?['fragmentSource'] as String?;

  /// Settlement substrate ID (coral-specific)
  String? get settlementSubstrate => metadata?['settlementSubstrate'] as String?;

  /// Number of molts recorded (crab-specific)
  int? get moltCount => safeInt(metadata?['moltCount']);

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

  /// Effective organism quantity for analytics and inventory calculations.
  ///
  /// Prefers the explicit inventory-metrics count when available; falls back
  /// to the measurement value when the unit category is [MeasurementUnitCategory.count];
  /// otherwise returns 1 (each organism record represents at least one individual).
  int get organismQuantity {
    final count = inventoryMetrics.count;
    if (count != null) return count;
    if (measurement.unit.category == MeasurementUnitCategory.count) {
      return measurement.value.round();
    }
    return 1;
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

  /// Resolved genet ID using canonical priority chain.
  /// Delegates to [GenetIdResolver.resolve] to maintain single source of truth.
  String? get resolvedGenetId => GenetIdResolver.resolve(this);

  /// User-facing notes/comments
  String? get notes => metadata?['notes'] as String?;

  /// Unique slug identifier
  String? get slug => metadata?['slug'] as String?;

  /// Whether organism is archived
  bool get isArchived => metadata?['archived'] == true;

  /// Actual measured size in centimeters
  double? get actualSizeCm {
    final v = metadata?['actualSizeCm'];
    return v is num ? v.toDouble() : null;
  }

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
  /// Uses recordName first, then falls back to localId, species code + short ID.
  String get displayLabel {
    final recordValue = recordName.trim();
    if (_isMeaningful(recordValue)) {
      return recordValue;
    }
    final localIdValue = localId?.trim();
    if (_isMeaningful(localIdValue)) {
      return localIdValue!;
    }
    final species = Species.fallback(speciesId);
    final shortId = id.length >= 8 ? id.substring(id.length - 4) : id;
    return '${_formatSpeciesCode(species.code)}-$shortId';
  }

  /// Preferred reference label for UI display with local ID context.
  ///
  /// Shows recordName as the primary label and appends localId when present.
  String get referenceLabel {
    final primary = displayLabel;
    final localIdValue = localId?.trim();
    if (_isMeaningful(localIdValue)) {
      return '$primary * $localIdValue';
    }
    return primary;
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
      CustodyHistoryService.instance.readCustodyHistory(this);

  /// Returns the current custody entry (most recent in history).
  ///
  /// Returns null if no custody history exists.
  CustodyHistoryEntry? get currentCustody =>
      CustodyHistoryService.instance.getCurrentCustody(this);

  /// Returns all organization IDs that have ever had custody of this organism.
  ///
  /// Includes both owners and managers throughout the custody history.
  Set<String> get allCustodyOrganizations =>
      CustodyHistoryService.instance.getAllCustodyOrganizations(this);

  /// Whether the given organization has ever owned or managed this organism.
  bool hasEverHadCustody(String organizationId) =>
      CustodyHistoryService.instance.hasOrganizationEverHadCustody(
        this,
        organizationId,
      );

  /// Whether the given organization has ever owned this organism.
  bool hasEverOwned(String organizationId) =>
      CustodyHistoryService.instance.hasOrganizationEverOwned(
        this,
        organizationId,
      );

  /// Whether the given organization has ever managed this organism.
  bool hasEverManaged(String organizationId) =>
      CustodyHistoryService.instance.hasOrganizationEverManaged(
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
