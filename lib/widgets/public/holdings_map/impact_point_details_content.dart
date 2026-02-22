// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/public_read_models/impact_cluster.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/details_shared_widgets.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/impact_point_breakdown_table.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Scrollable content for the public impact point details sheet.
class ImpactPointDetailsContent extends StatelessWidget {
  const ImpactPointDetailsContent({
    super.key,
    required this.cluster,
    required this.scrollController,
  });

  final ImpactCluster cluster;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final breakdown = _resolveBreakdown(cluster);
    final speciesBreakdown = _resolveSpeciesBreakdown(cluster);
    final idLabel = cluster.provenanceIdBreakdown.isNotEmpty
        ? 'PID'
        : 'Genet ID';
    final idLabelPlural =
        cluster.provenanceIdBreakdown.isNotEmpty ? 'PIDs' : 'Genotypes';
    final missingLabel =
        cluster.provenanceIdBreakdown.isNotEmpty ? 'PID' : 'genotype';
    final totalColonies = cluster.magnitude;
    final totalKnown =
        breakdown.values.fold<int>(0, (sum, value) => sum + value);
    final missing =
        (totalColonies - totalKnown).clamp(0, totalColonies).toInt();
    final hasSpecies = speciesBreakdown.isNotEmpty;
    final hasGenotypes = breakdown.isNotEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _StatsRow(
          totalColonies: totalColonies,
          totalSites: cluster.siteCount,
          totalIds: breakdown.length,
          idLabel: idLabelPlural,
        ),
        const SizedBox(height: 24),
        if (!hasSpecies && !hasGenotypes)
          _EmptyState(pointType: cluster.pointType)
        else ...[
          if (hasSpecies) ...[
            HoldingsMapSectionHeader(
              title: 'Species Breakdown (${speciesBreakdown.length})',
              icon: Icons.eco,
            ),
            const SizedBox(height: 8),
            ImpactPointBreakdownTable(
              breakdown: speciesBreakdown,
              totalColonies: totalColonies,
              idLabel: 'Species',
              idTextStyle: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (hasGenotypes) ...[
            HoldingsMapSectionHeader(
              title: _breakdownTitle(cluster, breakdown.length),
              icon: Icons.fingerprint,
            ),
            const SizedBox(height: 8),
            ImpactPointBreakdownTable(
              breakdown: breakdown,
              totalColonies: totalColonies,
              idLabel: idLabel,
            ),
            if (missing > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Missing $missingLabel data for ${formatNumber(missing)} colonies.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalColonies,
    required this.totalSites,
    required this.totalIds,
    required this.idLabel,
  });

  final int totalColonies;
  final int totalSites;
  final int totalIds;
  final String idLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: HoldingsMapStatCard(
            label: 'Total Colonies',
            value: formatNumber(totalColonies),
            icon: Icons.grass,
            color: crcAccentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: HoldingsMapStatCard(
            label: 'Sites',
            value: totalSites.toString(),
            icon: Icons.public,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: HoldingsMapStatCard(
            label: idLabel,
            value: totalIds.toString(),
            icon: Icons.fingerprint,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.pointType});

  final PublicImpactPointType pointType;

  @override
  Widget build(BuildContext context) {
    final label =
        pointType == PublicImpactPointType.holding ? 'holdings' : 'outplants';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'No genotype data available for these $label yet.',
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

Map<String, int> _resolveBreakdown(ImpactCluster cluster) {
  if (cluster.provenanceIdBreakdown.isNotEmpty) {
    return cluster.provenanceIdBreakdown;
  }
  return cluster.genetBreakdown;
}

Map<String, int> _resolveSpeciesBreakdown(ImpactCluster cluster) {
  if (cluster.speciesBreakdown.isEmpty) return const {};
  final mapped = <String, int>{};
  cluster.speciesBreakdown.forEach((id, count) {
    final species = SpeciesRegistry.globalById(id);
    final label = abbreviateSpecies(species?.name ?? id);
    if (label.isEmpty) return;
    mapped[label] = (mapped[label] ?? 0) + count;
  });
  return mapped;
}

String _breakdownTitle(ImpactCluster cluster, int count) {
  final label = cluster.provenanceIdBreakdown.isNotEmpty
      ? 'PID Summary'
      : 'Genotype Summary';
  return '$label ($count)';
}
