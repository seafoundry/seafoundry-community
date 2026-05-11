import 'package:equatable/equatable.dart';

/// The type/source context of a provenance alias suggestion.
enum ProvenanceAliasType {
  clonalId,
  accessionNumber,
  universalId,
  internalId,
  snpId,
  partnerId,
  fieldId,
  primary,
  legacy,
  tracks,
  zims,
  csr,
  galaxyStag,
  batch,
  local,
  transfer,
  unknown;

  /// Parse a raw string (e.g., from crosswalk `orgType`) into an enum value.
  ///
  /// Matches both the snake_case values written to Firestore by crosswalk
  /// scripts (e.g. `universal_id`, `internal_id`) and camelCase equivalents.
  static ProvenanceAliasType fromString(String value) {
    final lower = value.trim().toLowerCase();
    return switch (lower) {
      'clonalid' || 'clonal_id' || 'clonal id' => clonalId,
      'accessionnumber' ||
      'accession_number' ||
      'accession number' ||
      'accession' ||
      'accession #' =>
        accessionNumber,
      'universalid' || 'universal_id' || 'universal id' => universalId,
      'internalid' || 'internal_id' || 'internal id' => internalId,
      'snpid' || 'snp_id' || 'snp id' => snpId,
      'partnerid' || 'partner_id' || 'partner id' => partnerId,
      'fieldid' || 'field_id' || 'field id' => fieldId,
      'primary' => primary,
      'legacy' => legacy,
      'tracks' || 'aza tracks' => tracks,
      'zims' => zims,
      'csr' || 'coral sample registry' => csr,
      'galaxystag' || 'galaxy stag' || 'galaxy_stag' => galaxyStag,
      'batch' || 'batch / lot' => batch,
      'local' || 'local identifier' => local,
      'transfer' => transfer,
      _ => unknown,
    };
  }
}

/// Represents a matched alias from the provenance crosswalk.
/// Used in autocomplete suggestions when linking genets to existing PIDs.
class ProvenanceSuggestion extends Equatable {
  const ProvenanceSuggestion({
    required this.provenanceId,
    required this.aliasValue,
    required this.aliasType,
    required this.speciesCode,
    this.organizationName,
    this.otherAliases = const [],
    this.masterClonalId,
    this.resolvedClonalId,
    this.resolvedAccessionNumber,
    this.resolvedAlias,
  });

  /// Construct from a [CommunityProvenanceRecord] and one of its aliases.
  /// [aliasTypeOverride] lets the BLoC specify which field the user typed into.
  /// [otherAliases] can be passed to show alternative names.
  factory ProvenanceSuggestion.fromRecordAlias({
    required String provenanceId,
    required String speciesCode,
    required String aliasId,
    required String aliasOrg,
    required String aliasOrgType,
    ProvenanceAliasType? aliasTypeOverride,
    List<String> otherAliases = const [],
    String? masterClonalId,
    String? resolvedClonalId,
    String? resolvedAccessionNumber,
    String? resolvedAlias,
  }) {
    return ProvenanceSuggestion(
      provenanceId: provenanceId,
      aliasValue: aliasId,
      aliasType: aliasTypeOverride ?? ProvenanceAliasType.fromString(aliasOrgType),
      speciesCode: speciesCode,
      organizationName: aliasOrg,
      otherAliases: otherAliases,
      masterClonalId: masterClonalId,
      resolvedClonalId: resolvedClonalId,
      resolvedAccessionNumber: resolvedAccessionNumber,
      resolvedAlias: resolvedAlias,
    );
  }

  /// The provenance ID (e.g., "PID-APAL-0007")
  final String provenanceId;

  /// The matched alias value (e.g., "Apal-025")
  final String aliasValue;

  /// The type/source of the alias
  final ProvenanceAliasType aliasType;

  /// The species code this PID belongs to (e.g., "APAL")
  final String speciesCode;

  /// Optional organization name the alias came from
  final String? organizationName;

  /// Other aliases for the same record (to help user confirm match)
  final List<String> otherAliases;

  /// The master Clonal ID/Local ID for this record, if any.
  final String? masterClonalId;

  /// Pre-resolved clonalId from the crosswalk (if found in aliases).
  final String? resolvedClonalId;

  /// Pre-resolved accession number from the crosswalk (if found in aliases).
  final String? resolvedAccessionNumber;

  /// Pre-resolved primary alias from the crosswalk (if found in aliases).
  final String? resolvedAlias;

  @override
  List<Object?> get props => [
    provenanceId,
    aliasValue,
    aliasType,
    speciesCode,
    organizationName,
    otherAliases,
    masterClonalId,
    resolvedClonalId,
    resolvedAccessionNumber,
    resolvedAlias,
  ];

  @override
  String toString() =>
      'ProvenanceSuggestion(${aliasType.name}: $aliasValue -> $provenanceId)';
}
