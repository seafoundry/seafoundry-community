// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Lightweight view of organism-specific defaults used by repositories,
/// cubits, and services when choosing measurement units, life stage presets, or
/// site restrictions. This will eventually expand to include permit, MRV, and
/// capability guards; for now it captures the metadata needed to begin
/// threading `OrganismKind` through the DI graph.
class OrganismContext {
  const OrganismContext({
    required this.kind,
    required this.defaultMeasurementUnit,
    required this.lifeStages,
    required this.supportedStructureTypes,
    required this.supportedSiteTypes,
  });

  final OrganismKind kind;
  final String defaultMeasurementUnit;
  final List<String> lifeStages;
  final List<String> supportedStructureTypes;
  final List<String> supportedSiteTypes;

  factory OrganismContext.forKind(OrganismKind kind) {
    final metadata = kind.metadata;
    return OrganismContext(
      kind: kind,
      defaultMeasurementUnit: metadata.defaultMeasurementUnit,
      lifeStages: List<String>.from(metadata.lifeStages),
      supportedStructureTypes: List<String>.from(
        metadata.supportedStructureTypes,
      ),
      supportedSiteTypes: List<String>.from(metadata.defaultSiteTypes),
    );
  }
}
