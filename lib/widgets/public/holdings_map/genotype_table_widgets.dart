// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/historical/provenance_id.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/historical_data_service.dart';
import 'package:seafoundry_app/widgets/historical/provenance_detail_modal.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Summary table showing all genotypes with their local IDs and aliases.
class GenotypeSummaryTable extends StatelessWidget {
  const GenotypeSummaryTable({
    super.key,
    required this.genotypes,
    required this.getProvenanceDetails,
  });

  final List<GenotypeCount> genotypes;
  final ProvenanceId? Function(String) getProvenanceDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildHeader(),
          ...genotypes.map((g) => GenotypeTableRow(
                genotype: g,
                getProvenanceDetails: getProvenanceDetails,
              )),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: crcAccentColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Local ID',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Alias',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Species',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'PID',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Clonal ID',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Accession #',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              'Count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row in the genotype summary table.
class GenotypeTableRow extends StatelessWidget {
  const GenotypeTableRow({
    super.key,
    required this.genotype,
    required this.getProvenanceDetails,
  });

  final GenotypeCount genotype;
  final ProvenanceId? Function(String) getProvenanceDetails;

  @override
  Widget build(BuildContext context) {
    final provenance = getProvenanceDetails(genotype.name);
    final aliasLabel = resolveAliasLabel(provenance, localId: genotype.name);
    // If the resolved alias matches the local ID (case-insensitive), show a dash
    final alias = aliasLabel.toLowerCase() == genotype.name.toLowerCase()
        ? '-'
        : aliasLabel;
    final clonalId = provenance == null
        ? null
        : ClonalIdDisplayService.resolveForProvenanceId(provenance);

    return InkWell(
      onTap: () => showProvenanceDetailModal(
        context: context,
        genotypeId: genotype.name,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                genotype.name,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                alias,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                abbreviateSpecies(genotype.speciesName),
                style:
                    const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                provenance?.pid ?? '-',
                style: TextStyle(
                  fontSize: 11,
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
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                provenance?.accessionNumber ?? '-',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                '${genotype.colonies}',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
