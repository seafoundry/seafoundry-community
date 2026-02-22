// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/historical/nomenclature_system.dart';
import 'package:seafoundry_app/models/historical/provenance_id.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/historical_nomenclature_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Modal dialog showing detailed provenance information for a genotype,
/// including all organization aliases and collection/outplant metadata.
///
/// Usage:
/// ```dart
/// showProvenanceDetailModal(
///   context: context,
///   genotypeId: 'PID-APAL-001',
/// );
/// ```
Future<void> showProvenanceDetailModal({
  required BuildContext context,
  required String genotypeId,
}) async {
  // Capture messenger before async gap per SafeDialogMixin pattern
  final messenger = ScaffoldMessenger.of(context);

  final nomenclatureService = HistoricalNomenclatureService.instance;
  if (!nomenclatureService.isInitialized) {
    final success = await nomenclatureService.initialize();
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to load provenance data'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }

  final provenance = nomenclatureService.getProvenanceDetails(genotypeId);
  if (provenance == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('No provenance details found for $genotypeId'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => ProvenanceDetailModal(provenance: provenance),
  );
}

/// Modal widget displaying provenance details and aliases.
class ProvenanceDetailModal extends StatelessWidget {
  const ProvenanceDetailModal({
    super.key,
    required this.provenance,
  });

  final ProvenanceId provenance;

  static const Color _accentColor = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    final clonalId = ClonalIdDisplayService.resolveForProvenanceId(provenance);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: _buildHeader(context),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSpeciesSection(),
            const SizedBox(height: 16),
            if (provenance.firstOutplantDate != null ||
                provenance.collectionDate != null)
              _buildDatesSection(),
            if (provenance.accessionNumber != null || clonalId != null)
              _buildMoteDataSection(clonalId),
            _buildAliasesSection(),
            if (provenance.totalOutplantEvents > 0) _buildStatsSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fingerprint, color: _accentColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Provenance ID',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SelectableText(
                  provenance.pid,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (provenance.hasGeneticData)
            Tooltip(
              message: 'Has genetic analysis data',
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.biotech, color: Colors.green, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeciesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Species'),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                provenance.species,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                provenance.speciesName,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        if (provenance.speciesCommonName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            provenance.speciesCommonName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        _buildBadgesRow(),
      ],
    );
  }

  Widget _buildBadgesRow() {
    final badges = <Widget>[];

    if (provenance.isFounder) {
      badges.add(_buildBadge('Founder', Colors.purple));
    }
    if (provenance.isSexualRecruit) {
      badges.add(_buildBadge('Sexual Recruit', Colors.pink));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, children: badges),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDatesSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Timeline'),
          const SizedBox(height: 4),
          if (provenance.collectionDate != null)
            _buildDateRow(
              icon: Icons.nature_people,
              label: 'Collected',
              date: provenance.collectionDate!,
              site: provenance.collectionSite,
              region: provenance.collectionRegion,
            ),
          if (provenance.firstOutplantDate != null)
            _buildDateRow(
              icon: Icons.sailing,
              label: 'First Outplant',
              date: provenance.firstOutplantDate!,
              site: provenance.firstOutplantSite,
            ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required IconData icon,
    required String label,
    required String date,
    String? site,
    String? region,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(date),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                if (site != null || region != null)
                  Text(
                    [site, region].whereType<String>().join(', '),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoteDataSection(String? clonalId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Mote HOG Data'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (provenance.accessionNumber != null)
                _buildLabeledValue('Accession #', provenance.accessionNumber!),
              if (clonalId != null)
                _buildLabeledValue('Clonal ID', clonalId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAliasesSection() {
    final aliases = <MapEntry<NomenclatureSystem, String>>[];

    for (final system in NomenclatureSystem.organizations) {
      final alias = provenance.aliases[system.aliasKey];
      if (alias != null) {
        aliases.add(MapEntry(system, alias));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Also Known As'),
        const SizedBox(height: 4),
        if (aliases.isEmpty)
          Text(
            'No organization aliases recorded',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...aliases.map((entry) => _buildAliasRow(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildAliasRow(NomenclatureSystem system, String alias) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              system.displayName,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _accentColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  alias,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  system.fullName,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              Icons.event,
              '${provenance.totalOutplantEvents}',
              'Outplant Events',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _accentColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLabeledValue(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    // Handle both YYYY-MM-DD and YYYY formats
    if (dateStr.length == 4) {
      return dateStr; // Just year
    }
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        final month = int.tryParse(parts[1]) ?? 1;
        final day = int.tryParse(parts[2]) ?? 1;
        // Validate month is within bounds
        if (month < 1 || month > 12) {
          return dateStr;
        }
        return '${months[month - 1]} $day, ${parts[0]}';
      }
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to format provenance date',
        {
          'input': dateStr,
          'error': e.toString(),
        },
      );
    }
    return dateStr;
  }
}
