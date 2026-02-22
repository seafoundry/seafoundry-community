// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_cubit.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_item.dart';

/// Step 4-5: Submission progress and completion summary.
///
/// Shows per-item status with icons, a summary banner, and action buttons
/// for stopping, retrying failed items, or dismissing the dialog.
class BatchTransferProgressStep extends StatelessWidget {
  const BatchTransferProgressStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchTransferCubit, BatchTransferState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryBanner(state: state),
            const SizedBox(height: 12),
            ...state.items.map((item) => _ItemRow(item: item)),
            const SizedBox(height: 16),
            _ActionButtons(state: state),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Summary banner
// ---------------------------------------------------------------------------

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.state});
  final BatchTransferState state;

  @override
  Widget build(BuildContext context) {
    final isSubmitting = state.step == BatchTransferStep.submitting;
    final text = isSubmitting
        ? 'Submitting...'
        : '${state.successCount} of ${state.items.length} transfers succeeded';
    final color = isSubmitting
        ? Colors.blue.shade50
        : state.hasFailures
            ? Colors.orange.shade50
            : Colors.green.shade50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-item row
// ---------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final BatchTransferItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusIcon(item.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayLabel(item),
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'x${item.quantity}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (item.status == BatchItemStatus.failure &&
              item.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: Text(
                item.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  String _displayLabel(BatchTransferItem item) =>
      '${item.genetLocalId} → ${item.toOrganizationName}';

  Widget _statusIcon(BatchItemStatus status) => switch (status) {
        BatchItemStatus.pending => const Icon(
            Icons.hourglass_empty,
            size: 18,
            color: Colors.grey,
          ),
        BatchItemStatus.submitting => const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        BatchItemStatus.success => const Icon(
            Icons.check_circle,
            size: 18,
            color: Colors.green,
          ),
        BatchItemStatus.failure => const Icon(
            Icons.error,
            size: 18,
            color: Colors.red,
          ),
      };
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.state});
  final BatchTransferState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BatchTransferCubit>();
    final isSubmitting = state.step == BatchTransferStep.submitting;
    final isComplete = state.step == BatchTransferStep.complete;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isSubmitting)
          TextButton(
            onPressed: cubit.cancelSubmission,
            child: const Text('Stop'),
          ),
        if (isComplete && state.hasFailures) ...[
          TextButton(
            onPressed: cubit.retryFailed,
            child: const Text('Retry Failed'),
          ),
          const SizedBox(width: 8),
        ],
        if (isComplete)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(state.successCount > 0),
            child: const Text('Done'),
          ),
      ],
    );
  }
}
