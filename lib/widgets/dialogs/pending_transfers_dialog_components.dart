import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/services/species_registry.dart';
import 'package:seafoundry_community/utils/date_formatter.dart';
import 'package:seafoundry_community/utils/provenance_selection_utils.dart';
import 'package:seafoundry_community/widgets/common/alias_badges.dart';
import 'package:seafoundry_community/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Card widget for displaying a transfer summary with action buttons.
class PendingTransferCard extends StatelessWidget {
  const PendingTransferCard({
    super.key,
    required this.transfer,
    this.genet,
    required this.counterpartyLabel,
    required this.counterpartyName,
    this.showActions = true,
    this.statusLabel,
    this.actions,
    this.onAccept,
    this.onReject,
  });

  final TransferEvent transfer;
  final ProvenanceRecord? genet;
  final String counterpartyLabel;
  final String counterpartyName;
  final bool showActions;
  final String? statusLabel;
  final Widget? actions;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final species = genet != null
        ? SpeciesRegistry.globalById(genet!.speciesId)
        : null;
    final provenanceSelection = buildTransferProvenanceSelection(
      transfer: transfer,
      provenance: genet,
    );

    final actionWidget =
        actions ??
        (showActions
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            : null);
    final hasActions = actionWidget != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        genet?.displayName ?? 'Unknown Genet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      _metadataWrap(
                        context: context,
                        species: species,
                        selection: provenanceSelection,
                        provenanceId: genet?.provenanceId,
                      ),
                      if ((genet?.aliasEntries ?? const []).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AliasBadges(
                            aliases: genet!.aliasEntries,
                            showPlaceholderWhenEmpty: false,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Quantity: ${transfer.quantity}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormatter.formatChatTime(
                        DateTime.parse(transfer.createdAt),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '$counterpartyLabel: $counterpartyName',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (transfer.comment != null && transfer.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transfer.comment!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (statusLabel != null || hasActions) ...[
              const SizedBox(height: 16),
            ],
            if (statusLabel != null) ...[
              Row(
                children: [
                  const Icon(Icons.timelapse, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Status: $statusLabel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (hasActions) actionWidget,
          ],
        ),
      ),
    );
  }
}

Widget _metadataWrap({
  required BuildContext context,
  Species? species,
  required ProvenanceLifeStageSelection selection,
  String? provenanceId,
}) {
  final widgets = <Widget>[];
  void addBullet() {
    if (widgets.isNotEmpty) {
      widgets.add(const Text('•'));
    }
  }

  final textStyle = Theme.of(context).textTheme.bodySmall;

  if (species != null) {
    widgets.add(Text(species.name, style: textStyle));
  }
  addBullet();
  widgets.add(Text(selection.provenanceType.displayName, style: textStyle));
  addBullet();
  widgets.add(Text(selection.lifeStage.displayName, style: textStyle));
  if (provenanceId != null) {
    addBullet();
    widgets.add(
      Text(
        provenanceId,
        style: textStyle?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  if (widgets.isEmpty) {
    return const SizedBox.shrink();
  }

  return Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: widgets,
  );
}

class RejectTransferDialog extends StatefulWidget {
  const RejectTransferDialog({
    super.key,
    required this.transfer,
    required this.genet,
    required this.fromOrganization,
  });

  final TransferEvent transfer;
  final ProvenanceRecord? genet;
  final Organization? fromOrganization;

  @override
  State<RejectTransferDialog> createState() => _RejectTransferDialogState();
}

class _RejectTransferDialogState extends State<RejectTransferDialog>
    with SafeDialogMixin<RejectTransferDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Transfer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this transfer?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.transfer.quantity} × ${widget.genet?.displayName ?? 'Unknown Genet'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${widget.fromOrganization?.name ?? 'Unknown'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((widget.genet?.aliasEntries ?? const []).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AliasBadges(
                          aliases: widget.genet!.aliasEntries,
                          showPlaceholderWhenEmpty: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                helperText: 'Provide a reason for rejecting this transfer',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => popDialog(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            popDialog(_reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reject Transfer'),
        ),
      ],
    );
  }
}

class CancelTransferDialog extends StatefulWidget {
  const CancelTransferDialog({
    super.key,
    required this.transfer,
    required this.recipientName,
    this.genet,
  });

  final TransferEvent transfer;
  final ProvenanceRecord? genet;
  final String recipientName;

  @override
  State<CancelTransferDialog> createState() => _CancelTransferDialogState();
}

class _CancelTransferDialogState extends State<CancelTransferDialog>
    with SafeDialogMixin<CancelTransferDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Transfer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this transfer?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.transfer.quantity} × ${widget.genet?.displayName ?? 'Unknown Genet'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To: ${widget.recipientName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((widget.genet?.aliasEntries ?? const []).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AliasBadges(
                          aliases: widget.genet!.aliasEntries,
                          showPlaceholderWhenEmpty: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                helperText: 'Add a note about why this transfer was cancelled',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => popDialog(),
          child: const Text('Keep Transfer'),
        ),
        ElevatedButton(
          onPressed: () {
            popDialog(_reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Cancel Transfer'),
        ),
      ],
    );
  }
}
