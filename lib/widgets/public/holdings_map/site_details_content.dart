// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/historical/provenance_id.dart';
import 'package:seafoundry_app/services/historical_data_service.dart';
import 'package:seafoundry_app/services/historical_nomenclature_service.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/details_shared_widgets.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/event_group_widgets.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/genotype_table_widgets.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Content widget for the site details bottom sheet.
///
/// Displays site statistics, species breakdown, genotype summary table,
/// and outplant events grouped by date.
class SiteDetailsContent extends StatefulWidget {
  const SiteDetailsContent({
    super.key,
    required this.details,
    required this.scrollController,
  });

  final SiteOutplantDetails details;
  final ScrollController scrollController;

  @override
  State<SiteDetailsContent> createState() => _SiteDetailsContentState();
}

class _SiteDetailsContentState extends State<SiteDetailsContent> {
  final Set<String> _expandedEvents = {};

  ProvenanceId? _getProvenanceDetails(String genotypeId) {
    final nomenclatureService = HistoricalNomenclatureService.instance;
    if (!nomenclatureService.isInitialized || nomenclatureService.hasError) {
      return null;
    }
    return nomenclatureService.getProvenanceDetails(genotypeId);
  }

  @override
  Widget build(BuildContext context) {
    // Group events by date for display
    final eventsByDate = <String, List<OutplantEventSummary>>{};
    for (final event in widget.details.events) {
      final dateKey = event.eventDate ?? 'Unknown';
      eventsByDate.putIfAbsent(dateKey, () => []).add(event);
    }
    final sortedDates = eventsByDate.keys.toList()
      ..sort((a, b) {
        // Push "Unknown" to end of list
        if (a == 'Unknown') return 1;
        if (b == 'Unknown') return -1;
        return b.compareTo(a); // Descending
      });

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _StatsRow(details: widget.details),
        const SizedBox(height: 24),
        if (widget.details.species.isNotEmpty) ...[
          HoldingsMapSectionHeader(title: 'Species Breakdown', icon: Icons.eco),
          const SizedBox(height: 8),
          ...widget.details.species.map(
            (s) => _SpeciesRow(
              species: s,
              totalColonies: widget.details.totalColonies,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (widget.details.genotypes.isNotEmpty) ...[
          HoldingsMapSectionHeader(
            title: 'Genotype Summary (${widget.details.genotypes.length})',
            icon: Icons.fingerprint,
          ),
          const SizedBox(height: 8),
          GenotypeSummaryTable(
            genotypes: widget.details.genotypes,
            getProvenanceDetails: _getProvenanceDetails,
          ),
          const SizedBox(height: 24),
        ],
        if (eventsByDate.isNotEmpty) ...[
          HoldingsMapSectionHeader(
            title: 'Outplant Events (${sortedDates.length} dates)',
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 8),
          ...sortedDates.take(30).map(
                (date) => EventDateGroup(
                  date: date,
                  events: eventsByDate[date]!,
                  isExpanded: _expandedEvents.contains(date),
                  onToggle: () => setState(() {
                    if (_expandedEvents.contains(date)) {
                      _expandedEvents.remove(date);
                    } else {
                      _expandedEvents.add(date);
                    }
                  }),
                  getProvenanceDetails: _getProvenanceDetails,
                ),
              ),
          if (sortedDates.length > 30)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '...and ${sortedDates.length - 30} more event dates',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.details});

  final SiteOutplantDetails details;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: HoldingsMapStatCard(
            label: 'Total Colonies',
            value: formatNumber(details.totalColonies),
            icon: Icons.grass,
            color: crcAccentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: HoldingsMapStatCard(
            label: 'Outplant Events',
            value: details.totalEvents.toString(),
            icon: Icons.event,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: HoldingsMapStatCard(
            label: 'Genotypes',
            value: details.genotypes.length.toString(),
            icon: Icons.fingerprint,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({required this.species, required this.totalColonies});

  final SpeciesCount species;
  final int totalColonies;

  @override
  Widget build(BuildContext context) {
    final percentage =
        totalColonies > 0 ? (species.colonies / totalColonies * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              species.name,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage / 100,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: crcAccentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '${formatNumber(species.colonies)} (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
