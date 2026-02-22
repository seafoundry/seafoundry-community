// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_aware_event_repository.dart';
import 'package:seafoundry_app/widgets/repositories/registry/repository_registry.dart';

/// Convenience extensions for RepositoryRegistry providing
/// organism-specific repository access methods.
extension RepositoryRegistryOrganismExtensions on RepositoryRegistry {
  /// Convenience getter for OrganismRecordRepository.
  OrganismRecordRepository organismRecordRepositoryFor(
    OrganismKind organismKind, {
    bool fallbackToDefault = true,
  }) {
    return getForKind<OrganismRecordRepository>(
      organismKind,
      fallbackToDefault: fallbackToDefault,
    );
  }

  /// Convenience getter for OrganismAwareEventRepository.
  OrganismAwareEventRepository eventRepositoryFor(
    OrganismKind organismKind, {
    bool fallbackToDefault = true,
  }) {
    return getForKind<OrganismAwareEventRepository>(
      organismKind,
      fallbackToDefault: fallbackToDefault,
    );
  }
}
