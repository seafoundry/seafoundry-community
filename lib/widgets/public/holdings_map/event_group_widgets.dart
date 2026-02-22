// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/historical/provenance_id.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/historical_data_service.dart';
import 'package:seafoundry_app/widgets/historical/provenance_detail_modal.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Expandable group for a single event date.
class EventDateGroup extends StatelessWidget {
  const EventDateGroup({
    super.key,
    required this.date,
    required this.events,
    required this.isExpanded,
    required this.onToggle,
    required this.getProvenanceDetails,
  });

  final String date;
  final List<OutplantEventSummary> events;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ProvenanceId? Function(String) getProvenanceDetails;

  @override
  Widget build(BuildContext context) {
    final totalColonies =
        events.fold<int>(0, (total, e) => total + e.colonies);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildHeader(totalColonies),
          if (isExpanded) ...[
            const Divider(height: 1),
            EventGenotypeTable(
              events: events,
              getProvenanceDetails: getProvenanceDetails,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(int totalColonies) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              formatEventDate(date),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: crcAccentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${events.length} genotype${events.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 10, color: crcAccentColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$totalColonies colonies',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Genotype table within an expanded event.
class EventGenotypeTable extends StatelessWidget {
  const EventGenotypeTable({
    super.key,
    required this.events,
    required this.getProvenanceDetails,
  });

  final List<OutplantEventSummary> events;
  final ProvenanceId? Function(String) getProvenanceDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          _buildHeader(),
          ...events.map((e) => EventGenotypeRow(
                event: e,
                getProvenanceDetails: getProvenanceDetails,
              )),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Local ID',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Alias',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'PID',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Clonal ID',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Species',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              'Count',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row in the event genotype table.
class EventGenotypeRow extends StatelessWidget {
  const EventGenotypeRow({
    super.key,
    required this.event,
    required this.getProvenanceDetails,
  });

  final OutplantEventSummary event;
  final ProvenanceId? Function(String) getProvenanceDetails;

  @override
  Widget build(BuildContext context) {
    final provenance = getProvenanceDetails(event.genotypeName);
    final aliasLabel = resolveAliasLabel(provenance, localId: event.genotypeName);
    // If the resolved alias matches the local ID (case-insensitive), show a dash
    final alias = aliasLabel.toLowerCase() == event.genotypeName.toLowerCase()
        ? '-'
        : aliasLabel;
    final clonalId = provenance == null
        ? null
        : ClonalIdDisplayService.resolveForProvenanceId(provenance);

    return InkWell(
      onTap: () => showProvenanceDetailModal(
        context: context,
        genotypeId: event.genotypeName,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                event.genotypeName,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                alias,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                provenance?.pid ?? '-',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: provenance?.pid != null ? crcAccentColor : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                clonalId ?? '-',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                abbreviateSpecies(event.speciesName),
                style:
                    const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 45,
              child: Text(
                '${event.colonies}',
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
