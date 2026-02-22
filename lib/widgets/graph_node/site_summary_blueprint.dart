// @tier: community
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/events/move_out_event.dart';
import 'package:seafoundry_app/models/events/outplant_mortality_event.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/volume_calculation_service.dart';
import 'package:seafoundry_app/widgets/graph_node/site_summary_helpers.dart';
import 'package:seafoundry_app/widgets/graph_node/site_summary_models.dart';

/// Build a UI blueprint for site summary cards based on site capabilities.
SiteSummaryBlueprint buildSiteSummaryBlueprint({
  required SiteLoadedState state,
  required SiteCapabilities capabilities,
}) {
  final siteType = capabilities.siteType;
  final metricGroups = <SiteSummaryMetricGroup>[];

  if (siteType == SiteType.outplanting ||
      siteType == SiteType.fieldCollection) {
    metricGroups.add(_outplantActivityMetrics(state));
  } else if (siteType == SiteType.geneBank) {
    metricGroups.add(_geneBankMetrics(state));
  }

  final heading = _headlineForSiteType(siteType);
  final showStatistics =
      siteType == SiteType.nurseryExSitu ||
      siteType == SiteType.nurseryInSitu ||
      siteType == SiteType.geneBank;

  return SiteSummaryBlueprint(
    heading: heading,
    showOrganismStatistics: showStatistics,
    metricGroups: metricGroups,
  );
}

SiteSummaryMetricGroup _outplantActivityMetrics(SiteLoadedState state) {
  final outplantEvents = state.events.whereType<OutplantEvent>().toList();
  final monitoringEvents = state.events
      .whereType<MonitoringEventRecord>()
      .toList();

  // Calculate total corals ever outplanted to this site
  final totalOutplanted = outplantEvents.fold<int>(
    0,
    (sum, event) => sum + event.totalQuantity,
  );

  // Calculate total mortalities (outplant-specific mortality events)
  final mortalityEvents = state.events.whereType<OutplantMortalityEvent>();
  final totalMortalities = mortalityEvents.fold<int>(
    0,
    (sum, event) => sum + (event.oldPopulation - event.newPopulation),
  );

  // Calculate total corals moved away (MoveOut events from this site or its structures)
  final moveOutEvents = state.events.whereType<MoveOutEvent>();
  final totalMovedAway = moveOutEvents.fold<int>(0, (sum, event) {
    // Count corals moved from this site (recordId is where corals are moving FROM)
    final isFromThisSite =
        event.recordId == state.site.id ||
        state.groupNodes.any((group) => group.id == event.recordId);
    if (isFromThisSite) {
      // Use quantity if available, otherwise count moved coral IDs
      return sum + (event.quantity ?? event.movedCoralIds.length);
    }
    return sum;
  });

  // Calculate surviving corals: total outplanted - mortalities - moved away
  final totalSurviving = totalOutplanted - totalMortalities - totalMovedAway;

  // Calculate species and genotypes from allocations
  final speciesSet = <String>{};
  final speciesGenotypeMap = <String, Set<String>>{};
  double totalVolumeMm3 = 0.0;
  int allocationsWithVolume = 0;

  for (final event in outplantEvents) {
    for (final allocation in event.allocations) {
      // Track species
      if (allocation.speciesId.isNotEmpty) {
        speciesSet.add(allocation.speciesId);
        speciesGenotypeMap.putIfAbsent(allocation.speciesId, () => <String>{});
        final genetId = allocation.genetId;
        if (genetId != null && genetId.isNotEmpty) {
          speciesGenotypeMap[allocation.speciesId]!.add(genetId);
        }
      }

      // Re-implemented volume calculation with OrganismRecord model
      if (allocation.snapshot != null) {
        try {
          // Reconstruct a partial record from the snapshot to resolve size metrics
          final snapshot = allocation.snapshot!;

          // Log snapshot contents before processing
          LoggingService.instance.debug(
            'Processing allocation: ${allocation.organismId}',
            {
              'snapshot_keys': snapshot.keys.toList(),
              'has_size': snapshot.containsKey('size'),
              'has_sizeSpec': snapshot.containsKey('sizeSpec'),
            },
          );

          final record = OrganismRecord.partial(
            id: allocation.organismId,
            organismKind: OrganismKind.values.firstWhere(
              (k) => k.name == snapshot['organismKind'],
              orElse: () => OrganismKind.coral,
            ),
            lifeStage: LifeStageSpec.fromJson(
              snapshot['lifeStage'] is Map<String, dynamic>
                  ? snapshot['lifeStage']
                  : {'id': snapshot['lifeStage']},
            ),
            measurement: PopulationMeasurement.fromJson(
              Map<String, dynamic>.from(snapshot['measurement'] ?? {}),
            ),
            physicalForm: snapshot['physicalForm'] != null
                ? PhysicalFormInstance.fromJson(
                    Map<String, dynamic>.from(snapshot['physicalForm']),
                  )
                : null,
            // Legacy fallback
            metadata: snapshot['metadata'] != null
                ? Map<String, dynamic>.from(snapshot['metadata'])
                : null,
            // Parse sizeSpec for volume calculation
            sizeSpec: snapshot['sizeSpec'] != null
                ? SizeSpec.fromJson(
                    Map<String, dynamic>.from(snapshot['sizeSpec']),
                  )
                : (snapshot['size'] != null
                    ? SizeSpec.fromJson(
                        Map<String, dynamic>.from(snapshot['size']),
                      )
                    : const SizeSpec()),
          );

          final metrics = record.sizeSpec.resolvedMetrics();
          final volumeCm3 = metrics.volumeCm3;

          if (volumeCm3 != null) {
            totalVolumeMm3 += volumeCm3 * 1000.0 * allocation.quantity;
            allocationsWithVolume += allocation.quantity;
          } else {
            LoggingService.instance.warning(
              'Volume calculation returned null',
              {
                'organismId': allocation.organismId,
                'sizeClass': record.sizeSpec.sizeClass,
                'formId': record.physicalForm?.formId,
              },
            );
          }
        } catch (e, stackTrace) {
          // Log parsing errors instead of silently ignoring
          LoggingService.instance.error(
            'Failed to parse allocation snapshot',
            e,
            stackTrace,
          );
          continue;
        }
      }
    }
  }

  // Format volume
  String volumeDisplay = totalVolumeMm3 > 0
      ? VolumeCalculationService.formatVolumeMm3(totalVolumeMm3)
      : 'N/A';
  if (totalVolumeMm3 > 0 && allocationsWithVolume < totalOutplanted) {
    volumeDisplay += ' (estimated)';
  }

  // Build species/genotypes summary
  String speciesGenotypesSummary;
  if (speciesSet.isEmpty) {
    speciesGenotypesSummary = 'No data';
  } else {
    final speciesCount = speciesSet.length;
    final totalGenotypes = speciesGenotypeMap.values.fold<int>(
      0,
      (sum, genets) => sum + genets.length,
    );
    speciesGenotypesSummary = '$speciesCount species';
    if (totalGenotypes > 0) {
      speciesGenotypesSummary += ', $totalGenotypes genotypes';
    }
    // Add breakdown by species if there are multiple species
    if (speciesSet.length <= 5) {
      final breakdown = speciesGenotypeMap.entries
          .map((entry) {
            final speciesId = entry.key;
            final species = SpeciesRegistry.globalById(speciesId);
            final speciesName = species?.name ?? speciesId;
            final genotypeCount = entry.value.length;
            return '$speciesName: $genotypeCount';
          })
          .join(', ');
      if (breakdown.isNotEmpty) {
        speciesGenotypesSummary += '\n$breakdown';
      }
    }
  }

  return SiteSummaryMetricGroup(
    title: 'Outplant Activity',
    metrics: [
      SiteSummaryMetric(
        label: 'Outplant Events',
        value: '${outplantEvents.length}',
      ),
      SiteSummaryMetric(
        label: 'Monitoring Events',
        value: '${monitoringEvents.length}',
      ),
      SiteSummaryMetric(
        label: 'Total Corals Outplanted',
        value: '$totalOutplanted',
      ),
      SiteSummaryMetric(
        label: 'Total Corals Surviving',
        value: '$totalSurviving',
        helper: totalSurviving != totalOutplanted
            ? '$totalMortalities mortalities, $totalMovedAway moved'
            : null,
      ),
      SiteSummaryMetric(
        label: 'Species & Genotypes',
        value: speciesGenotypesSummary.split('\n').first,
        helper: speciesGenotypesSummary.contains('\n')
            ? speciesGenotypesSummary.split('\n').sublist(1).join('\n')
            : null,
      ),
      SiteSummaryMetric(
        label: 'Total Volume Transplanted',
        value: volumeDisplay,
        helper:
            allocationsWithVolume < totalOutplanted && allocationsWithVolume > 0
            ? 'Volume available for $allocationsWithVolume of $totalOutplanted corals'
            : null,
      ),
    ],
  );
}

SiteSummaryMetricGroup _geneBankMetrics(SiteLoadedState state) {
  final totalStructures = state.children.length;
  final totalEvents = state.events.length;

  // Note: Detailed genotype/redundancy metrics require GeneBankMetricsService
  // This simplified version shows basic structure and event counts

  return SiteSummaryMetricGroup(
    title: 'Gene Bank Activity',
    metrics: [
      SiteSummaryMetric(
        label: 'Storage Structures',
        value: '$totalStructures',
        helper: 'Includes tanks, trays, and life support systems.',
      ),
      // Note: Genotype metrics require GeneBankMetricsService for accurate calculation
      // These would be added when integrating the metrics service
      SiteSummaryMetric(label: 'Lifecycle Events', value: '$totalEvents'),
      SiteSummaryMetric(
        label: 'Last Activity',
        value: formatLatestDate(
          state.events.map((event) => DateTime.tryParse(event.createdAt)),
        ),
      ),
    ],
  );
}

String _headlineForSiteType(SiteType siteType) {
  if (siteType == SiteType.outplanting) {
    return 'Outplant Monitoring Snapshot';
  }
  if (siteType == SiteType.nurseryInSitu) {
    return 'In-Situ Nursery Snapshot';
  }
  if (siteType == SiteType.geneBank) {
    return 'Gene Bank Snapshot';
  }
  if (siteType == SiteType.fieldCollection) {
    return 'Field Collection Snapshot';
  }
  return 'Nursery Health Snapshot';
}
