// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/constants/data_import_config.dart';
import 'package:seafoundry_app/theme/spacing.dart';

/// A card representing a single step in the data import workflow.
///
/// Shows step number, status icon, title, description, and action buttons
/// for template download and CSV import.
class DataImportStepCard extends StatelessWidget {
  const DataImportStepCard({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.isAvailable,
    required this.isComplete,
    required this.onDownloadTemplate,
    required this.onImportCsv,
    this.onOpenGoogleSheet,
  });

  final DataImportStep step;
  final int stepNumber;
  final bool isAvailable;
  final bool isComplete;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onImportCsv;
  final VoidCallback? onOpenGoogleSheet;

  IconData get _statusIcon {
    if (isComplete) return Icons.check_circle;
    if (isAvailable) return Icons.radio_button_unchecked;
    return Icons.lock;
  }

  Color _statusColor(BuildContext context) {
    if (isComplete) return Colors.green;
    if (isAvailable) return Theme.of(context).colorScheme.primary;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = !isAvailable && !isComplete;

    return Card(
      elevation: isLocked ? 0 : 2,
      color: isLocked ? Colors.grey[100] : null,
      child: Padding(
        padding: EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStepIndicator(context),
                SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.grey : null,
                        ),
                      ),
                      SizedBox(height: Spacing.xs),
                      Text(
                        step.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isLocked ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _statusIcon,
                  color: _statusColor(context),
                  size: 28,
                ),
              ],
            ),
            if (!isLocked) ...[
              SizedBox(height: Spacing.md),
              _buildActions(context),
            ],
            if (isLocked) ...[
              SizedBox(height: Spacing.sm),
              Text(
                'Complete previous steps to unlock',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final isLocked = !isAvailable && !isComplete;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLocked
            ? Colors.grey[300]
            : isComplete
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
      ),
      child: Center(
        child: Text(
          '$stepNumber',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        if (onOpenGoogleSheet != null)
          OutlinedButton.icon(
            onPressed: onOpenGoogleSheet,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Google Sheet'),
          ),
        OutlinedButton.icon(
          onPressed: onDownloadTemplate,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download Template'),
        ),
        FilledButton.icon(
          onPressed: onImportCsv,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Import CSV'),
        ),
      ],
    );
  }
}
