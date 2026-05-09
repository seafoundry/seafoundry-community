// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/common/quantity_change_editor.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for recording quantity changes (Census / Adjustment / Mortality)
class QuantityChangeDialog extends StatefulWidget {
  const QuantityChangeDialog({
    super.key,
    required this.organism,
    this.organismNode,
  });

  final OrganismRecord organism;
  final dynamic organismNode; // GraphNode matching interface

  static Future<bool?> show(
    BuildContext context, {
    required OrganismRecord organism,
    dynamic organismNode,
  }) {
    // Pre-read repository before showDialog to ensure it's available in dialog context
    final repository = context.read<OrganismRecordRepository>();

    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => RepositoryProvider<OrganismRecordRepository>.value(
        value: repository,
        child: QuantityChangeDialog(
          organism: organism,
          organismNode: organismNode,
        ),
      ),
    );
  }

  @override
  State<QuantityChangeDialog> createState() => _QuantityChangeDialogState();
}

class _QuantityChangeDialogState extends State<QuantityChangeDialog>
    with SafeDialogMixin<QuantityChangeDialog> {
  late QuantityChangeKind _kind;
  late PopulationMeasurement _pendingMeasurement;

  QuantityChangeReason? _selectedReason;
  PopulationLossReason? _mortalityReason;
  String? _comment;
  String? _validationMessage;
  bool _isSubmitting = false;

  /// Gets the [PopulationLossReason] for the selected reason.
  ///
  /// Delegates to [QuantityChangeReason.toPopulationLossReason] for canonical mapping.
  PopulationLossReason? _getPopulationLossReason() {
    return _selectedReason?.toPopulationLossReason(
      mortalityReason: _mortalityReason,
    );
  }

  @override
  void initState() {
    super.initState();
    _kind = QuantityChangeKind.gain;
    _pendingMeasurement = widget.organism.measurement;
  }

  void _validate() {
    setState(() {
      _validationMessage = null;
      if (_pendingMeasurement.value < 0) {
        _validationMessage = 'Quantity must be ≥ 0.';
        return;
      }
      
      // If loss, cannot exceed current quantity (unless we allow negative? No.)
      // Actually _pendingMeasurement IS the new quantity.
      // So logic: if kind is loss, the NEW quantity should represent that. 
      // But the editor lets you set the NEW TOTAL directly.
      
      if (_selectedReason == null) {
        _validationMessage = 'Select a reason for the change.';
        return;
      }
      
      if (_selectedReason?.id == 'mortality' && _mortalityReason == null) {
        _validationMessage = 'Specify the mortality cause.';
        return;
      }

      // Check for no change
      if (_pendingMeasurement.value == widget.organism.measurement.value &&
          _pendingMeasurement.unit == widget.organism.measurement.unit) {
         _validationMessage = 'No change in quantity.';
      }
    });
  }

  Future<void> _submit() async {
    _validate();
    if (_validationMessage != null) return;

    setState(() => _isSubmitting = true);

    try {
      await _submitOnline();
    } catch (e, stack) {
      LoggingService.instance.error('Failed to update quantity', e, stack);
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _validationMessage = 'Error: $e';
        });
      }
    }
  }

  /// Performs the quantity update when online.
  Future<void> _submitOnline() async {
    final repository = context.read<OrganismRecordRepository>();

    await repository.updateMeasurement(
      organism: widget.organism,
      newMeasurement: _pendingMeasurement,
      lossReason: _getPopulationLossReason(),
      comment: _comment,
    );

    // Event propagation removed - community tier

    LoggingService.instance.info(
      'Updated quantity for ${widget.organism.id}: ${_pendingMeasurement.value} (${_selectedReason?.label})',
    );

    if (!mounted) return;

    _requestReloadAndClose(successMessage: 'Quantity updated successfully');
  }

/// Triggers a reload request if possible and closes the dialog.
  void _requestReloadAndClose({required String successMessage}) {
    // Request reload
    if (widget.organismNode != null) {
      try {
        (widget.organismNode as dynamic).add(GraphNodeReloadRequested());
      } catch (_) {
        // Ignore if not a GraphNode or compatible
      }
    }

    popDialog(true);
    showDialogSnackBar(successMessage, isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          UI.iconMedium(Icons.analytics_outlined), // Using available UI helpers if possible
          const SizedBox(width: 8),
          const Text('Update Quantity'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: DialogScrollView(
          child: QuantityChangeEditor(
            currentMeasurement: widget.organism.measurement,
            kind: _kind,
            onKindChanged: (k) => setState(() {
              _kind = k;
              _selectedReason = null; // Reset reason when kind changes
              _validate();
            }),
            selectedReason: _selectedReason,
            onReasonChanged: (r) => setState(() {
              _selectedReason = r;
              _validate();
            }),
            pendingValue: _pendingMeasurement.value,
            onValueChanged: (v) => setState(() {
              if (v != null) {
                _pendingMeasurement = _pendingMeasurement.copyWith(value: v);
                _validate();
              }
            }),
            mortalityReason: _mortalityReason,
            onMortalityReasonChanged: (m) => setState(() {
              _mortalityReason = m;
              _validate();
            }),
            comment: _comment,
            commentHint: 'e.g., Counted after weekly inventory check.',
            onCommentChanged: (c) => setState(() => _comment = c),
            validationMessage: _validationMessage,
            isBusy: _isSubmitting,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => popDialog(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_isSubmitting || _validationMessage != null && _validationMessage != 'No change in quantity.') 
              ? null // Allow submit if valid, block if error (except maybe "no change" warning shouldn't be blocking? but here it is blocking)
              : _submit,
          child: _isSubmitting 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Update'),
        ),
      ],
    );
  }
}

// Helper for dynamic reload request
class GraphNodeReloadRequested {}