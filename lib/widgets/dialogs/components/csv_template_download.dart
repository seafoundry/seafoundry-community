// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/constants/csv_schema.dart';

/// Widget for downloading CSV templates (primarily for husbandry workflows).
class CsvTemplateDownload extends StatelessWidget {
  const CsvTemplateDownload({
    super.key,
    required this.templateKinds,
    required this.onDownloadTemplate,
    required this.templateIconFor,
    required this.templateTitleFor,
    required this.templateDescriptionFor,
  });

  final List<CsvTemplateKind> templateKinds;
  final void Function(CsvTemplateKind kind) onDownloadTemplate;
  final IconData Function(CsvTemplateKind) templateIconFor;
  final String Function(CsvTemplateKind) templateTitleFor;
  final String Function(CsvTemplateKind) templateDescriptionFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.table_view, size: 64, color: Colors.blueGrey),
        const SizedBox(height: 16),
        Text(
          'Download CSV templates for husbandry workflows.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        ...templateKinds.map(
          (kind) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TemplateCard(
              icon: templateIconFor(kind),
              title: templateTitleFor(kind),
              description: templateDescriptionFor(kind),
              onPressed: () => onDownloadTemplate(kind),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.download),
                label: const Text('Download Template'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
