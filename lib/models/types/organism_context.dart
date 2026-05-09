// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Lightweight view of organism-specific defaults used by repositories,
/// cubits, and services. Simplified for coral-only build.
class OrganismContext {
  const OrganismContext({
    required this.kind,
    required this.defaultMeasurementUnit,
    required this.lifeStages,
  });

  final OrganismKind kind;
  final String defaultMeasurementUnit;
  final List<String> lifeStages;

  factory OrganismContext.forKind(OrganismKind kind) {
    final metadata = kind.metadata;
    return OrganismContext(
      kind: kind,
      defaultMeasurementUnit: metadata.defaultMeasurementUnit,
      lifeStages: List<String>.from(metadata.lifeStages),
    );
  }
}
