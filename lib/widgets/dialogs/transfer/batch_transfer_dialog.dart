import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_cubit.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/batch_transfer_items_step.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/batch_transfer_progress_step.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/batch_transfer_review_step.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/batch_transfer_target_step.dart';
import 'package:seafoundry_app/widgets/forms/form_step_indicator.dart';

/// Main dialog orchestrator for batch transfers.
///
/// Reads [BatchTransferCubit] from context (provided by `TransferDialog.showBatch()`).
/// Switches between step widgets based on the current [BatchTransferStep] and
/// handles back-button safety via [PopScope].
class BatchTransferDialog extends StatefulWidget {
  const BatchTransferDialog({super.key});

  @override
  State<BatchTransferDialog> createState() => _BatchTransferDialogState();
}

class _BatchTransferDialogState extends State<BatchTransferDialog>
    with SafeDialogMixin<BatchTransferDialog> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchTransferCubit, BatchTransferState>(
      builder: (context, state) {
        return PopScope(
          canPop: _canPop(state),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBackNavigation(state);
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 500,
            ),
            child: AlertDialog(
              title: Text(_titleForStep(state.step)),
              content: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepDots(
                      currentStep: _logicalStepIndex(state.step),
                    ),
                    const SizedBox(height: 16),
                    _buildStepContent(state),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Step content routing
  // ---------------------------------------------------------------------------

  Widget _buildStepContent(BatchTransferState state) => switch (state.step) {
        BatchTransferStep.selectFixed => const BatchTransferTargetStep(),
        BatchTransferStep.addItems => const BatchTransferItemsStep(),
        BatchTransferStep.review => const BatchTransferReviewStep(),
        BatchTransferStep.submitting ||
        BatchTransferStep.complete =>
          const BatchTransferProgressStep(),
      };

  // ---------------------------------------------------------------------------
  // Title per step
  // ---------------------------------------------------------------------------

  String _titleForStep(BatchTransferStep step) => switch (step) {
        BatchTransferStep.selectFixed => 'Select Target',
        BatchTransferStep.addItems => 'Add Items',
        BatchTransferStep.review => 'Review Transfer',
        BatchTransferStep.submitting => 'Submitting...',
        BatchTransferStep.complete => 'Complete',
      };

  // ---------------------------------------------------------------------------
  // Logical step index (for indicator dots)
  // ---------------------------------------------------------------------------

  /// Maps the 5-value enum to 4 visual dots:
  /// 0=Target, 1=Items, 2=Review, 3=Submit/Complete.
  int _logicalStepIndex(BatchTransferStep step) => switch (step) {
        BatchTransferStep.selectFixed => 0,
        BatchTransferStep.addItems => 1,
        BatchTransferStep.review => 2,
        BatchTransferStep.submitting => 3,
        BatchTransferStep.complete => 3,
      };

  // ---------------------------------------------------------------------------
  // PopScope logic
  // ---------------------------------------------------------------------------

  bool _canPop(BatchTransferState state) =>
      state.step != BatchTransferStep.submitting;

  Future<void> _handleBackNavigation(BatchTransferState state) async {
    if (state.step == BatchTransferStep.submitting) return;

    final cubit = context.read<BatchTransferCubit>();

    // During steps 1-3 with items in cart, confirm discard.
    if (state.items.isNotEmpty &&
        state.step != BatchTransferStep.complete) {
      final shouldDiscard = await showSafeDialog<bool>(
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard Cart?'),
          content:
              Text('You have ${state.items.length} items in your cart.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (shouldDiscard == true && mounted) popDialog();
      return;
    }

    // Navigate back through wizard steps or pop dialog.
    switch (state.step) {
      case BatchTransferStep.selectFixed:
        popDialog();
      case BatchTransferStep.addItems:
        cubit.goToStep(BatchTransferStep.selectFixed);
      case BatchTransferStep.review:
        cubit.goToStep(BatchTransferStep.addItems);
      case BatchTransferStep.complete:
        popDialog(state.successCount > 0);
      case BatchTransferStep.submitting:
        break; // Guarded by canPop
    }
  }
}

// ---------------------------------------------------------------------------
// Step dots indicator
// ---------------------------------------------------------------------------

class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return FormStepIndicator(
      totalSteps: 4,
      currentStep: currentStep,
      iconColor: Theme.of(context).colorScheme.primary,
    );
  }
}
