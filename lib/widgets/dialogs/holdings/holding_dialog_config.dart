// @tier: community
import 'package:seafoundry_app/models/inventory/holding_record.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Configuration for a generic holding dialog.
/// Defines all organism-specific values needed to create a holding.
class HoldingDialogConfig {
  const HoldingDialogConfig({
    required this.title,
    required this.defaultName,
    required this.quantityLabel,
    required this.dateFieldLabel,
    required this.organismKind,
    required this.initialProvenanceType,
    required this.initialLifeStage,
    required this.initialPhysicalFormId,
    required this.successMessage,
    required this.fieldKeyPrefix,
    required this.fiveAxisHelpText,
    this.extraField,
    required this.holdingFactory,
  });

  /// Dialog title (e.g., "Record Crab Pond Inventory")
  final String title;

  /// Default name for the holding (e.g., "Crab Cohort")
  final String defaultName;

  /// Label for quantity field (e.g., "Quantity (count)")
  final String quantityLabel;

  /// Label for date field (e.g., "Stocking date", "Deployment date")
  final String dateFieldLabel;

  /// The organism kind for this holding
  final OrganismKind organismKind;

  /// Initial provenance type for five-axis selector
  final ProvenanceType initialProvenanceType;

  /// Initial life stage for five-axis selector
  final LifeStage initialLifeStage;

  /// Initial physical form ID for five-axis selector
  final String? initialPhysicalFormId;

  /// Success message shown after creation
  final String successMessage;

  /// Prefix for form field keys (e.g., "crab-pond")
  final String fieldKeyPrefix;

  /// Help text for five-axis section
  final String fiveAxisHelpText;

  /// Optional extra field configuration (e.g., carapace width, average weight)
  final ExtraFieldConfig? extraField;

  /// Factory function to create the holding
  final HoldingRecord Function(HoldingFactoryParams params) holdingFactory;
}

/// Configuration for an optional extra field in the dialog
class ExtraFieldConfig {
  const ExtraFieldConfig({
    required this.label,
    required this.helperText,
    required this.controllerName,
  });

  /// Field label (e.g., "Average carapace width (mm)")
  final String label;

  /// Helper text shown below the field
  final String helperText;

  /// Name identifier for the controller (e.g., "carapace", "weight", "depth")
  final String controllerName;
}

/// Parameters passed to holding factory functions.
///
/// Note on siteId/groupId vs organismRecord:
/// The [siteId] and [groupId] fields provide the structure context for where
/// the holding will be created. The [organismRecord] is a partial record
/// containing organism-specific data (life stage, provenance type, measurement,
/// etc.) but typically does NOT include siteId/groupId to avoid forcing
/// factories to handle potential conflicts.
///
/// This intentional separation allows:
/// 1. Factories to use the explicit siteId/groupId as the authoritative location
/// 2. The organismRecord to focus on organism attributes without location context
/// 3. Clear override semantics: structure IDs take precedence over any in the record
class HoldingFactoryParams {
  const HoldingFactoryParams({
    required this.recordName,
    required this.localId,
    required this.organismKind,
    required this.measurement,
    required this.siteId,
    required this.groupId,
    required this.ownerOrganizationId,
    required this.managingOrganizationId,
    required this.organismRecord,
    required this.organismLifeStage,
    this.extraFieldValue,
    this.dateValue,
    this.bagIdentifier,
  });

  final String recordName;
  final String localId;
  final OrganismKind organismKind;
  final dynamic measurement;

  /// The site ID where this holding will be created.
  /// This is the authoritative location - takes precedence over any siteId
  /// that might exist in [organismRecord].
  final String siteId;

  /// The group ID where this holding will be created.
  /// This is the authoritative location - takes precedence over any groupId
  /// that might exist in [organismRecord].
  final String groupId;
  final String ownerOrganizationId;
  final String managingOrganizationId;

  /// Partial organism record containing organism-specific attributes.
  /// Note: siteId/groupId in this record (if present) are ignored in favor
  /// of the explicit [siteId] and [groupId] fields on this params object.
  final OrganismRecord organismRecord;
  final LifeStage organismLifeStage;
  final double? extraFieldValue;
  final DateTime? dateValue;
  final String? bagIdentifier;
}
