import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/inventory/local_id_edit_scope.dart';

export 'package:seafoundry_community/models/inventory/local_id_edit_scope.dart';

/// Dialog for choosing the scope of a localID edit.
///
/// When a user edits the localID field for an organism that shares a genet
/// with other organism records, this dialog prompts them to choose whether
/// to update only the current record or all records sharing the genet.
class LocalIdEditScopeDialog extends StatelessWidget {
  const LocalIdEditScopeDialog({
    super.key,
    required this.currentLocalId,
    required this.newLocalId,
    required this.recordCount,
  });

  /// The current localID value being changed from.
  final String currentLocalId;

  /// The new localID value being changed to.
  final String newLocalId;

  /// The number of organism records sharing this genet.
  final int recordCount;

  /// Shows the dialog and returns the selected scope, or null if cancelled.
  static Future<LocalIdEditScope?> show(
    BuildContext context, {
    required String currentLocalId,
    required String newLocalId,
    required int recordCount,
  }) {
    return showDialog<LocalIdEditScope>(
      context: context,
      builder: (_) => LocalIdEditScopeDialog(
        currentLocalId: currentLocalId,
        newLocalId: newLocalId,
        recordCount: recordCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Update Local ID'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changing Local ID from "$currentLocalId" to "$newLocalId".',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This genet has $recordCount organism record(s).',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How should this change apply?',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, LocalIdEditScope.recordOnly),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('This record only'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, LocalIdEditScope.genetWide),
          icon: const Icon(Icons.group_work, size: 18),
          label: Text('All $recordCount records'),
        ),
      ],
    );
  }
}
