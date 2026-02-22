// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/screens/import/universal_wizard/universal_create_missing_wizard.dart';
import 'package:seafoundry_app/services/csv_import_service.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';
import 'package:seafoundry_app/widgets/dialogs/components/csv_translation_issues_panel.dart';

/// Panel displaying CSV import/validation results with error handling and actions.
class CsvImportResultsPanel extends StatelessWidget {
  const CsvImportResultsPanel({
    super.key,
    required this.result,
    required this.templateKind,
    required this.templateDisplayName,
    required this.validateOnly,
    required this.isLoading,
    required this.onPickAnotherFile,
    required this.onDownloadTranslationIssues,
    required this.onDownloadErrorCsv,
    required this.onLaunchCreateMissingWizard,
  });

  final CSVImportResult result;
  final CsvTemplateKind templateKind;
  final String templateDisplayName;
  final bool validateOnly;
  final bool isLoading;
  final VoidCallback? onPickAnotherFile;
  final void Function(CsvTranslationSummary) onDownloadTranslationIssues;
  final void Function(List<CSVImportError>) onDownloadErrorCsv;
  final void Function(List<MissingEntity>) onLaunchCreateMissingWizard;

  @override
  Widget build(BuildContext context) {
    final hasBlockingErrors = result.hasErrors;
    final hasWarnings = result.hasWarnings;
    final missingEntities = templateKind == CsvTemplateKind.inventory
        ? _collectMissingEntities(result)
        : <MissingEntity>[];

    // Determine icon: error > warning > success
    final IconData statusIcon;
    final Color statusColor;
    if (hasBlockingErrors) {
      statusIcon = Icons.error;
      statusColor = Colors.red;
    } else if (hasWarnings) {
      statusIcon = Icons.warning_amber;
      statusColor = Colors.orange;
    } else {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, size: 64, color: statusColor),
        const SizedBox(height: 16),
        Text(
          validateOnly ? 'Validation Results' : 'Import Complete',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(result.summary),
        if (result.translationSummary?.hasIssues ?? false) ...[
          const SizedBox(height: 12),
          CsvTranslationIssuesPanel(
            summary: result.translationSummary!,
            onDownload: () =>
                onDownloadTranslationIssues(result.translationSummary!),
          ),
        ],
        if (validateOnly && missingEntities.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Before importing, create or map all missing structures referenced '
            'in the CSV.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () => onLaunchCreateMissingWizard(missingEntities),
              icon: const Icon(Icons.workspaces_outline),
              label: const Text('Open Create-Missing Wizard'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (validateOnly)
          Text(
            templateKind == CsvTemplateKind.monitoring
                ? 'Resolve any issues below, then choose Import Data to apply the updates.'
                : 'No changes have been applied yet. Resolve any issues then choose Import Data to apply updates.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          _buildOutcomeSummary(context, result),
        const SizedBox(height: 16),
        // Show blocking errors if any
        if (hasBlockingErrors)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Blocking Errors (${result.blockingErrors.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildErrorList(context, result.blockingErrors, isWarning: false),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onDownloadErrorCsv(result.blockingErrors),
                  icon: const Icon(Icons.download),
                  label: const Text('Download Error CSV'),
                ),
              ),
            ],
          ),
        // Show warnings if any (separate section)
        if (hasWarnings) ...[
          if (hasBlockingErrors) const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warnings (${result.warnings.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'These issues were resolved automatically but may need review.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange[700]),
              ),
              const SizedBox(height: 8),
              _buildErrorList(context, result.warnings, isWarning: true),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onDownloadErrorCsv(result.warnings),
                  icon: const Icon(Icons.download),
                  label: const Text('Download Warnings CSV'),
                ),
              ),
            ],
          ),
        ],
        // Show success message only if no errors AND no warnings
        if (!hasBlockingErrors && !hasWarnings) ...[
          const Text(
            'No validation errors detected.',
            style: TextStyle(color: Colors.green),
          ),
          if (!validateOnly) _buildSuccessDetails(context, result),
        ]
        // Show success details after errors/warnings if import succeeded
        else if (!hasBlockingErrors && !validateOnly)
          _buildSuccessDetails(context, result),
        if (validateOnly && onPickAnotherFile != null) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onPickAnotherFile,
            icon: const Icon(Icons.refresh),
            label: const Text('Validate Another CSV'),
          ),
        ],
      ],
    );
  }

  Widget _buildOutcomeSummary(BuildContext context, CSVImportResult result) {
    switch (templateKind) {
      case CsvTemplateKind.inventory:
      case CsvTemplateKind.inventoryMinimal:
      case CsvTemplateKind.inventoryCoral:
      case CsvTemplateKind.inventoryOyster:
      case CsvTemplateKind.inventoryKelp:
      case CsvTemplateKind.inventorySeagrass:
      case CsvTemplateKind.inventoryMangrove:
      case CsvTemplateKind.inventoryFinfish:
      case CsvTemplateKind.inventoryCrab:
        if (result.updatedOrganisms.isNotEmpty) {
          return Text(
            'Updated ${result.updatedOrganisms.length} organism holding${result.updatedOrganisms.length == 1 ? '' : 's'} with refreshed five-axis (provenance, life stage, physical form, size) metadata.',
            style: Theme.of(context).textTheme.titleMedium,
          );
        }
        return const Text('No inventory changes were required.');
      case CsvTemplateKind.monitoring:
        final created = result.createdMonitoringEvents.length;
        final updated = result.updatedMonitoringEvents.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (created > 0) ...[
              Text(
                'Created $created monitoring record${created == 1 ? '' : 's'}.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...result.createdMonitoringEvents
                  .take(3)
                  .map((event) => _buildMonitoringTile(context, event)),
              if (created > 3)
                Text(
                  '... and ${created - 3} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
            ],
            if (updated > 0) ...[
              Text(
                'Updated $updated monitoring record${updated == 1 ? '' : 's'}.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...result.updatedMonitoringEvents
                  .take(3)
                  .map((event) => _buildMonitoringTile(context, event)),
              if (updated > 3)
                Text(
                  '... and ${updated - 3} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        );
      case CsvTemplateKind.outplanting:
        if (result.updatedOutplantEvents.isNotEmpty) {
          return Text(
            'Updated ${result.updatedOutplantEvents.length} outplant event${result.updatedOutplantEvents.length == 1 ? '' : 's'}.',
            style: Theme.of(context).textTheme.titleMedium,
          );
        }
        return const Text('No outplant event changes were required.');
      case CsvTemplateKind.genetics:
        if (result.importedGenets.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Imported ${result.importedGenets.length} genet record${result.importedGenets.length == 1 ? '' : 's'} with canonical provenance + life-stage metadata.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...result.importedGenets
                  .take(3)
                  .map(
                    (genet) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.science, color: Colors.blue),
                      title: Text(genet.name),
                      subtitle: Text(
                        'ID: ${genet.provenanceId} · ${_provenanceSummary(ProvenanceLifeStageSelection.fromGenet(genet))}',
                      ),
                    ),
                  ),
              if (result.importedGenets.length > 3)
                Text(
                  '... and ${result.importedGenets.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          );
        }
        return const Text('No genetics changes were required.');
      case CsvTemplateKind.husbandryObservations:
      case CsvTemplateKind.husbandryTasks:
      case CsvTemplateKind.outplantAllocations:
      case CsvTemplateKind.outplantConsolidated:
        return const SizedBox.shrink();
      case CsvTemplateKind.siteBaselines:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMonitoringTile(
    BuildContext context,
    MonitoringEventRecord event,
  ) {
    final date = event.monitoringDate ?? DateTime.tryParse(event.createdAt);
    final formattedDate = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : event.createdAt;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_heart, color: Colors.blue),
      title: Text(event.siteNameSnapshot ?? event.recordId),
      subtitle: Text(
        'Date: $formattedDate · Cover: ${event.percentCover?.toStringAsFixed(1) ?? '-'}%',
      ),
    );
  }

  Widget _buildSuccessDetails(BuildContext context, CSVImportResult result) {
    switch (templateKind) {
      case CsvTemplateKind.inventory:
      case CsvTemplateKind.inventoryMinimal:
      case CsvTemplateKind.inventoryCoral:
      case CsvTemplateKind.inventoryOyster:
      case CsvTemplateKind.inventoryKelp:
      case CsvTemplateKind.inventorySeagrass:
      case CsvTemplateKind.inventoryMangrove:
      case CsvTemplateKind.inventoryFinfish:
      case CsvTemplateKind.inventoryCrab:
        if (result.updatedOrganisms.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Updated records:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...result.updatedOrganisms
                  .take(3)
                  .map(
                    (organism) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.check, color: Colors.green),
                      title: Text(organism.name),
                      subtitle: Text(
                        '${_provenanceSummary(_selectionForOrganism(organism))} · Physical Form: ${_physicalFormLabelForOrganism(organism)} · Qty: ${organism.measurement.value.round()}',
                      ),
                    ),
                  ),
              if (result.updatedOrganisms.length > 3)
                Text(
                  '... and ${result.updatedOrganisms.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          );
        }
        return const SizedBox.shrink();
      case CsvTemplateKind.outplanting:
        if (result.updatedOutplantEvents.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Updated events:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...result.updatedOutplantEvents
                  .take(3)
                  .map(
                    (event) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, color: Colors.green),
                      title: Text(event.name),
                      subtitle: Text(
                        'Site: ${event.siteId} · Date: ${event.createdAt}',
                      ),
                    ),
                  ),
              if (result.updatedOutplantEvents.length > 3)
                Text(
                  '... and ${result.updatedOutplantEvents.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          );
        }
        return const SizedBox.shrink();
      case CsvTemplateKind.genetics:
      case CsvTemplateKind.monitoring:
      case CsvTemplateKind.husbandryObservations:
      case CsvTemplateKind.husbandryTasks:
      case CsvTemplateKind.outplantAllocations:
      case CsvTemplateKind.outplantConsolidated:
        return const SizedBox.shrink();
      case CsvTemplateKind.siteBaselines:
        return const SizedBox.shrink();
    }
  }

  Widget _buildErrorList(
    BuildContext context,
    List<CSVImportError> errors, {
    bool isWarning = false,
  }) {
    final borderColor = isWarning ? Colors.orange[300]! : Colors.red[300]!;
    final iconColor = isWarning ? Colors.orange : Colors.red;
    final icon = isWarning ? Icons.warning_amber : Icons.error;

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: errors.length,
        itemBuilder: (context, index) {
          final error = errors[index];
          return ListTile(
            dense: true,
            leading: Icon(icon, color: iconColor, size: 20),
            title: Text('Row ${error.row}: ${error.field}'),
            subtitle: Text(error.message),
          );
        },
      ),
    );
  }

  List<MissingEntity> _collectMissingEntities(CSVImportResult result) {
    final entries = <MissingEntity>[];
    final seen = <String>{};

    // Only consider blocking errors for missing entities, not warnings
    for (final error in result.blockingErrors) {
      final normalizedField = error.field.toLowerCase();
      final normalizedMessage = error.message.toLowerCase();
      final value = error.value.isNotEmpty ? error.value : error.field;

      if (normalizedField.contains('group') &&
          normalizedMessage.contains('unknown')) {
        if (seen.add('group:$value')) {
          entries.add(
            MissingEntity(
              type: MissingEntityType.group,
              value: value,
              message: error.message,
            ),
          );
        }
      } else if (normalizedField.contains('site') &&
          normalizedMessage.contains('unknown')) {
        if (seen.add('site:$value')) {
          entries.add(
            MissingEntity(
              type: MissingEntityType.site,
              value: value,
              message: error.message,
            ),
          );
        }
      } else if (normalizedField.contains('org') &&
          normalizedMessage.contains('unknown')) {
        if (seen.add('org:$value')) {
          entries.add(
            MissingEntity(
              type: MissingEntityType.organization,
              value: value,
              message: error.message,
            ),
          );
        }
      }
    }

    return entries;
  }

  ProvenanceLifeStageSelection _selectionForOrganism(OrganismRecord organism) =>
      buildProvenanceSelection(organism: organism);

  String _physicalFormLabelForOrganism(OrganismRecord organism) {
    // Use the new PhysicalFormInstance if available
    final formId = organism.physicalForm?.formId;
    if (formId != null && formId.isNotEmpty) {
      return formatSnakeCaseToTitleCase(formId);
    }

    return 'Unknown unit';
  }

  String _provenanceSummary(ProvenanceLifeStageSelection selection) =>
      '${selection.provenanceType.displayName} · ${selection.lifeStage.displayName}';
}
