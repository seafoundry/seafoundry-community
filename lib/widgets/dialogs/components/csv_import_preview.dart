import 'package:flutter/material.dart';
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/services/csv/v2/csv_v2_spec_extensions.dart';

/// Preview widget shown before CSV import, explaining the process and showing template.
class CsvImportPreview extends StatelessWidget {
  const CsvImportPreview({
    super.key,
    required this.templateKind,
    required this.templateDisplayName,
    required this.onDownloadTemplate,
  });

  final CsvTemplateKind templateKind;
  final String templateDisplayName;
  final VoidCallback onDownloadTemplate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.upload_file, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          'Import ${templateDisplayName.toLowerCase()} updates from CSV',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Text(
            'Validate your CSV first to review proposed changes, then apply them once you are ready.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (templateKind == CsvTemplateKind.inventory) ...[
          const SizedBox(height: 16),
          _buildStepRow(
            context: context,
            icon: Icons.rule_folder,
            title: '1. Validate the CSV',
            description:
                'Select "Select CSV File" to run validation. We highlight schema mismatches, missing references, and adapter translation issues.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            context: context,
            icon: Icons.fact_check,
            title: '2. Review results',
            description:
                'Resolve any blocking issues, download error reports, or launch the create-missing wizard to add referenced structures.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            context: context,
            icon: Icons.cloud_upload,
            title: '3. Import updates',
            description:
                'When validation passes, the "Import Data" button becomes available to apply inventory changes.',
          ),
        ],
        if (templateKind == CsvTemplateKind.inventory) ...[
          const SizedBox(height: 16),
          _buildInventoryMetadataCallout(context),
        ],
        if (templateKind == CsvTemplateKind.genetics) ...[
          const SizedBox(height: 16),
          _buildGeneticsMetadataCallout(context),
        ],
        const SizedBox(height: 16),
        _buildTemplatePreview(context, templateKind),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onDownloadTemplate,
          icon: const Icon(Icons.description),
          label: const Text('Download Template CSV'),
        ),
      ],
    );
  }

  Widget _buildInventoryMetadataCallout(BuildContext context) {
    final theme = Theme.of(context);
    final axisFields =
        CsvV2SpecExtensions.axisColumns.take(4).join(', ');
    final provenanceFields =
        CsvV2SpecExtensions.provenanceColumns.join(', ');
    final siteFields =
        CsvV2SpecExtensions.siteColumns.take(3).join(', ');
    final permitFields =
        CsvV2SpecExtensions.permitColumns.take(3).join(', ');
    final geometryFields =
        CsvV2SpecExtensions.geometryColumns.take(2).join(', ');
    final metadataFields = [
      'Canonical axes • $axisFields',
      'Provenance • $provenanceFields',
      'Site context • $siteFields',
      'Permits • $permitFields',
      'Geometry • $geometryFields',
    ];
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.map_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Universal CSV v2 inventory rows capture the canonical five-axis organism metadata (provenance type, life stage, physical form, size spec) alongside provenance, site, permit, and geometry columns so compliance context travels with every holding.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metadataFields
                  .map(
                    (field) => Chip(
                      label: Text(field),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.upgrade, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Legacy “Universal CSV v1” files are automatically upgraded and tagged with the original version (`provenance_csv_upgraded_from`). Download a fresh template to populate the new site + permit columns before importing.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blueGrey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatePreview(BuildContext context, CsvTemplateKind kind) {
    final schema = CsvSchemas.schemaForKind(kind);
    final sample = <String>[
      'provenance_csv_version,${schema.version}',
      'org_domain,your-org-domain',
      schema.allColumns.join(','),
    ].join('\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        sample,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  Widget _buildGeneticsMetadataCallout(BuildContext context) {
    final theme = Theme.of(context);
    final identityFields =
        CsvV2SpecExtensions.identityColumns.take(5).join(', ');
    final provenanceFields =
        CsvV2SpecExtensions.provenanceColumns.join(', ');
    final aliasFields = CsvV2SpecExtensions.aliasColumns.join(', ');
    final axisFields =
        CsvV2SpecExtensions.axisColumns.take(4).join(', ');

    final chips = [
      'Identity • $identityFields',
      'Canonical axes • $axisFields',
      'Provenance • $provenanceFields',
      'Aliases • $aliasFields',
    ];

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.category_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Genetics exports/imports bundle each genet\'s canonical identifiers, provenance type + life stage, physical form/size snapshots, and alias sets so downstream pipelines no longer rely on legacy genet-type enums.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (field) => Chip(
                      label: Text(field),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
