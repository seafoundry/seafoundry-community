// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Confirmation dialog for archiving (soft-deleting) an organism record.
class OrganismArchiveDialog extends StatefulWidget {
  const OrganismArchiveDialog({
    super.key,
    required this.organism,
    required this.organismNode,
  });

  final OrganismRecord organism;
  final OrganismNode organismNode;

  static Future<bool?> show(
    BuildContext context, {
    required OrganismNode organismNode,
  }) {
    final repository = context.read<OrganismRecordRepository>();
    final organism = organismNode.currentRecord;

    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => RepositoryProvider<OrganismRecordRepository>.value(
        value: repository,
        child: OrganismArchiveDialog(
          organism: organism,
          organismNode: organismNode,
        ),
      ),
    );
  }

  @override
  State<OrganismArchiveDialog> createState() => _OrganismArchiveDialogState();
}

class _OrganismArchiveDialogState extends State<OrganismArchiveDialog>
    with SafeDialogMixin<OrganismArchiveDialog> {
  bool _isSubmitting = false;

  String get _displayName {
    final name = widget.organism.tagId.trim();
    if (name.isNotEmpty) return name;
    final localId = widget.organism.localId?.trim();
    if (localId != null && localId.isNotEmpty) return localId;
    return 'this organism';
  }

  Future<void> _archive() async {
    setState(() => _isSubmitting = true);

    try {
      final repository = context.read<OrganismRecordRepository>();
      await repository.archiveOrganismRecord(widget.organism.id);

      LoggingService.instance.info(
        'Archived organism record ${widget.organism.id}',
      );

      // Reload the parent node to reflect the removal
      final parent = widget.organismNode.parent;
      if (parent != null) {
        parent.add(const GraphNodeReloadRequested());
      }

      if (!mounted) return;

      popDialog(true);
      showDialogSnackBar('Record archived', isSuccess: true);
    } catch (e, stack) {
      LoggingService.instance.error('Failed to archive organism record', e, stack);
      if (mounted) {
        setState(() => _isSubmitting = false);
        showDialogSnackBar('Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = widget.organism.measurement.value.toInt();

    return AlertDialog(
      icon: Icon(Icons.archive_outlined, color: theme.colorScheme.error),
      title: const Text('Archive Record'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to archive "$_displayName"?',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantity: $quantity',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (widget.organism.localId != null)
                    Text(
                      'Local ID: ${widget.organism.localId}',
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Archived records are removed from active inventory but can be restored later.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => popDialog(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _archive,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Archive'),
        ),
      ],
    );
  }
}
