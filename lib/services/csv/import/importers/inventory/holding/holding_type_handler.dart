// @tier: community
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/inventory/holding_record.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';

/// Parameters required to build a holding record from CSV row data.
class HoldingBuildParams {
  const HoldingBuildParams({
    required this.row,
    required this.provenanceId,
    required this.targetGroup,
    required this.organismKind,
    required this.measurement,
    required this.localId,
    required this.recordName,
    required this.sizeSpec,
    required this.attributes,
    required this.aliases,
    required this.ownerOrganizationId,
    required this.managingOrganizationId,
    required this.foreignKeys,
    this.sourceName,
  });

  final Map<String, String> row;
  final String provenanceId;
  final Group targetGroup;
  final OrganismKind organismKind;
  final PopulationMeasurement measurement;
  final String localId;
  final String recordName;
  final SizeSpec sizeSpec;
  final HoldingAttributes attributes;
  final List<OrganismAlias> aliases;
  final String? ownerOrganizationId;
  final String? managingOrganizationId;
  final Map<String, ForeignKeyReference> foreignKeys;
  final String? sourceName;
}

/// Abstract base for holding type handlers.
///
/// Each subclass handles creation of a specific holding type (e.g., seeded
/// line, gamete batch) from CSV import data.
abstract class HoldingTypeHandler<T extends HoldingRecord> {
  const HoldingTypeHandler();

  /// The holding kind identifier this handler manages.
  String get holdingKind;

  /// Returns true if this handler can process the given holding kind.
  bool canHandle(String holdingKind) => this.holdingKind == holdingKind;

  /// Builds a holding record from the provided parameters.
  ///
  /// Returns null if required fields are missing or validation fails.
  T buildHolding(HoldingBuildParams params);

  /// Builds the organism record embedded within the holding.
  ///
  /// Subclasses may override to customize life stage or physical form.
  OrganismRecord buildOrganismRecord(HoldingBuildParams params);

  /// Returns the repository for this holding type, if configured.
  HoldingRepository<T>? getRepository(OrganismKind organismKind);
}
