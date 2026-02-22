// @tier: community
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Metrics for gene bank collections
class GeneBankMetrics {
  const GeneBankMetrics({
    required this.totalGenotypes,
    required this.totalSpecimens,
    required this.redundancyMetrics,
    required this.structureCount,
    this.completenessPercentage,
  });

  /// Total unique genotypes (genets) held in the gene bank
  final int totalGenotypes;

  /// Total number of specimens (corals) in storage
  final int totalSpecimens;

  /// Map of genet ID to number of structures where it's stored
  final Map<String, int> redundancyMetrics;

  /// Number of storage structures (groups/tanks) in the gene bank
  final int structureCount;

  /// Collection completeness as percentage (if target defined)
  final double? completenessPercentage;

  /// Average redundancy (average copies per genotype)
  double get averageRedundancy {
    if (totalGenotypes == 0) return 0.0;
    return redundancyMetrics.values.fold<int>(0, (sum, count) => sum + count) /
        totalGenotypes;
  }

  /// Genotypes with redundancy >= 2
  int get redundantGenotypes =>
      redundancyMetrics.values.where((count) => count >= 2).length;
}

/// Service for calculating gene bank metrics
///
/// Provides analytics for gene bank collections including:
/// - Total genotypes held
/// - Redundancy metrics (copies across structures)
/// - Collection completeness
class GeneBankMetricsService {
  GeneBankMetricsService({
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
  }) : _organismRecordRepository = organismRecordRepository,
       _groupRepository = groupRepository;

  final OrganismRecordRepository _organismRecordRepository;
  final GroupRepository _groupRepository;
  final LoggingService _logger = LoggingService.instance;

  /// Calculate metrics for a gene bank site
  Future<GeneBankMetrics> calculateMetrics({
    required String organizationId,
    required String siteId,
  }) async {
    try {
      // Fetch full collections and filter in memory to avoid emulator/index quirks.
      final allGroups = await _groupRepository.getAll();
      final geneBankGroups = allGroups
          .where(
            (group) =>
                group.organizationId == organizationId &&
                group.siteId == siteId,
          )
          .toList();

      final allOrganisms = await _organismRecordRepository.getAll();
      final geneBankOrganisms = allOrganisms
          .where(
            (organism) =>
                organism.organizationId == organizationId &&
                organism.siteId == siteId,
          )
          .toList();

      // Calculate unique genotypes and redundancy metrics
      final uniqueGenetIds = <String>{};
      final genetStructureMap = <String, Set<String>>{};
      var specimenCount = 0;

      for (final organism in geneBankOrganisms) {
        specimenCount += organism.measurement.value.toInt();
        final genetId = GenetIdResolver.resolve(organism);
        if (genetId == null || genetId.isEmpty) {
          _logger.warning(
            'Organism ${organism.id} has no resolvable genetId; '
            'excluded from genotype metrics',
          );
        }
        if (genetId != null && genetId.isNotEmpty) {
          uniqueGenetIds.add(genetId);
          genetStructureMap
              .putIfAbsent(genetId, () => <String>{})
              .add(organism.groupId ?? '');
        }
      }

      // Build redundancy metrics (genet ID -> number of structures)
      final redundancyMetrics = <String, int>{};
      for (final entry in genetStructureMap.entries) {
        redundancyMetrics[entry.key] = entry.value.length;
      }

      return GeneBankMetrics(
        totalGenotypes: uniqueGenetIds.length,
        totalSpecimens: specimenCount,
        redundancyMetrics: redundancyMetrics,
        structureCount: geneBankGroups.length,
        // Completeness would require a target collection definition
        completenessPercentage: null,
      );
    } catch (e, stackTrace) {
      _logger.error('Error calculating gene bank metrics', e, stackTrace);
      rethrow;
    }
  }
}
