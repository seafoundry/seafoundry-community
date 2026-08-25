import 'package:flutter/material.dart';
import 'package:seafoundry_community/services/csv/adapters/csv_translation_adapter.dart';
import 'package:seafoundry_community/services/csv/import/csv_import_models.dart';

class CsvTranslationIssuesPanel extends StatelessWidget {
  const CsvTranslationIssuesPanel({
    super.key,
    required this.summary,
    this.onDownload,
    this.maxIssues = 3,
  });

  final CsvTranslationSummary summary;
  final VoidCallback? onDownload;
  final int maxIssues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBlocking = summary.hasBlockingIssues;
    final warningColor = hasBlocking ? Colors.deepOrange : Colors.amber[700]!;
    final background = hasBlocking ? Colors.deepOrange[50] : Colors.amber[50];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warningColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasBlocking ? Icons.error_outline : Icons.warning_amber,
                color: warningColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adapter translation issues detected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _buildIssueSummary(),
            style: theme.textTheme.bodyMedium,
          ),
          ..._buildIssueList(theme),
          if (summary.adapterId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Adapter: ${summary.adapterId}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (summary.blockedRowCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${summary.blockedRowCount} row(s) were skipped before validation.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hasBlocking ? warningColor : Colors.brown[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (onDownload != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download Adapter Issues'),
              ),
            ),
        ],
      ),
    );
  }

  String _buildIssueSummary() {
    final issues = summary.totalIssues;
    final warnings = summary.warningCount;
    final errors = summary.errorCount;

    final parts = <String>[];
    if (errors > 0) {
      parts.add('$errors blocking');
    }
    if (warnings > 0) {
      parts.add('$warnings warning${warnings == 1 ? '' : 's'}');
    }
    final descriptor = parts.isEmpty ? 'issues reported' : parts.join(', ');
    return '$issues adapter issue${issues == 1 ? '' : 's'} ($descriptor).';
  }

  List<Widget> _buildIssueList(ThemeData theme) {
    if (summary.issues.isEmpty) {
      return const [];
    }

    final issuesToShow = summary.issues.take(maxIssues).toList(growable: false);
    final remaining = summary.issues.length - issuesToShow.length;

    final entries = <Widget>[
      const SizedBox(height: 12),
      ...issuesToShow.map(
        (issue) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _IssueRow(issue: issue),
        ),
      ),
    ];

    if (remaining > 0) {
      entries.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '+$remaining additional issue${remaining == 1 ? '' : 's'} — download the adapter CSV for the complete list.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return entries;
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final CsvTranslationIssue issue;

  Color _severityColor(BuildContext context) {
    switch (issue.severity) {
      case CsvTranslationIssueSeverity.error:
        return Colors.deepOrange;
      case CsvTranslationIssueSeverity.warning:
        return Colors.amber.shade800;
    }
  }

  IconData _severityIcon() {
    switch (issue.severity) {
      case CsvTranslationIssueSeverity.error:
        return Icons.error_outline;
      case CsvTranslationIssueSeverity.warning:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_severityIcon(), color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(
                  text: 'Row ${issue.rowNumber}: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '${issue.field} – ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: issue.message),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
