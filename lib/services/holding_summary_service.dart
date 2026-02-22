// @tier: community
import 'package:seafoundry_app/models/inventory/holding_summary.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/crab_pond_repository.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/gamete_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/mangrove_plot_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/repositories/inventory/sea_cucumber_tank_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seeded_line_repository.dart';
import 'package:seafoundry_app/repositories/inventory/urchin_tank_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/repositories/registry/registry.dart';

/// Aggregates holdings across arbitrary repositories so surfaces can render
/// measurement/count summaries per organism.
class HoldingSummaryService {
  HoldingSummaryService({
    required RepositoryRegistry registry,
  }) : _registry = registry;

  final RepositoryRegistry _registry;

  bool supports(OrganismKind kind) {
    // Check if any holding repository type is registered for this kind
    return _registry.isRegisteredForKind<SeededLineRepository>(kind) ||
        _registry.isRegisteredForKind<OysterBagRepository>(kind) ||
        _registry.isRegisteredForKind<GameteBatchRepository>(kind) ||
        _registry.isRegisteredForKind<LarvalBatchRepository>(kind) ||
        _registry.isRegisteredForKind<FinfishPenRepository>(kind) ||
        _registry.isRegisteredForKind<CrabPondRepository>(kind) ||
        _registry.isRegisteredForKind<MangrovePlotRepository>(kind) ||
        _registry.isRegisteredForKind<UrchinTankRepository>(kind) ||
        _registry.isRegisteredForKind<SeaCucumberTankRepository>(kind);
  }

  Future<List<HoldingSummary>> fetchSummaries({
    OrganismKind? organismFilter,
  }) async {
    final bucketAggregates = <_HoldingSummaryBucketKey,
        Map<MeasurementUnit, _HoldingSummaryAccumulator>>{};

    Future<void> collectFromRepository(
      HoldingRepository repository,
      OrganismKind? overrideOrganism,
    ) async {
      final targetOrganism = overrideOrganism ?? repository.organismContext.kind;
      final holdings = await repository.fetchHoldings(
        organismKind: targetOrganism,
      );
      for (final holding in holdings) {
        final bucketKey = _HoldingSummaryBucketKey(
          organismKind: holding.organismKind,
          holdingKind: repository.holdingKind,
        );
        final unitMap = bucketAggregates.putIfAbsent(
          bucketKey,
          () => <MeasurementUnit, _HoldingSummaryAccumulator>{},
        );
        final accumulator = unitMap.putIfAbsent(
          holding.measurement.unit,
          () => _HoldingSummaryAccumulator(),
        );
        accumulator.recordCount += 1;
        accumulator.totalQuantity += holding.measurement.value;
      }
    }

    // Collect all holding repository types from the registry
    final allRepositoryMaps = [
      _registry.getAllKinds<SeededLineRepository>(),
      _registry.getAllKinds<OysterBagRepository>(),
      _registry.getAllKinds<GameteBatchRepository>(),
      _registry.getAllKinds<LarvalBatchRepository>(),
      _registry.getAllKinds<FinfishPenRepository>(),
      _registry.getAllKinds<CrabPondRepository>(),
      _registry.getAllKinds<MangrovePlotRepository>(),
      _registry.getAllKinds<UrchinTankRepository>(),
      _registry.getAllKinds<SeaCucumberTankRepository>(),
    ];

    for (final repositoryMap in allRepositoryMaps) {
      if (organismFilter != null) {
        final repository = repositoryMap[organismFilter] as HoldingRepository?;
        if (repository != null) {
          await collectFromRepository(repository, organismFilter);
        }
        continue;
      }
      for (final repository in repositoryMap.values) {
        await collectFromRepository(repository as HoldingRepository, null);
      }
    }

    final summaries = <HoldingSummary>[];
    bucketAggregates.forEach((bucket, unitMap) {
      if (unitMap.length > 1) {
        LoggingService.instance.warning(
          'HoldingSummaryService: mixed units detected for '
          '${bucket.organismKind.name}/${bucket.holdingKind}. '
          'Entries will be emitted per unit.',
        );
      }
      unitMap.forEach((unit, accumulator) {
        summaries.add(
          HoldingSummary(
            organismKind: bucket.organismKind,
            holdingKind: bucket.holdingKind,
            recordCount: accumulator.recordCount,
            totalQuantity: accumulator.totalQuantity,
            measurementUnit: unit,
          ),
        );
      });
    });

    summaries.sort((a, b) {
      final kindCompare = a.organismKind.name.compareTo(b.organismKind.name);
      if (kindCompare != 0) return kindCompare;
      return a.holdingKind.compareTo(b.holdingKind);
    });
    return summaries;
  }
}

class _HoldingSummaryBucketKey {
  const _HoldingSummaryBucketKey({
    required this.organismKind,
    required this.holdingKind,
  });

  final OrganismKind organismKind;
  final String holdingKind;

  @override
  bool operator ==(Object other) =>
      other is _HoldingSummaryBucketKey &&
      other.organismKind == organismKind &&
      other.holdingKind == holdingKind;

  @override
  int get hashCode => Object.hash(organismKind, holdingKind);
}

class _HoldingSummaryAccumulator {
  int recordCount = 0;
  double totalQuantity = 0;
}
