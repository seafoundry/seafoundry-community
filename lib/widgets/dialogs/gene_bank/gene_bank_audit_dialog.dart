// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/cubits/gene_bank/gene_bank_audit_cubit.dart';
import 'package:seafoundry_app/models/events/gene_bank_audit_event.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import '../components/dialog_scroll_view.dart';
import '../../notifications/toast_overlay.dart';

/// Dialog for recording gene bank audit events
///
/// **Architecture**: Uses GeneBankAuditCubit for state management.
class GeneBankAuditDialog extends StatelessWidget {
  final GraphNode targetNode;
  final GeneBankAuditEvent? existingEvent;

  const GeneBankAuditDialog({
    super.key,
    required this.targetNode,
    this.existingEvent,
  });

  static Future<GeneBankAuditEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
    GeneBankAuditEvent? existingEvent,
  }) {
    final eventRepository = context.read<EventRepository>();

    return showDialog<GeneBankAuditEvent>(
      context: context,
      useRootNavigator: false,
      builder: (context) => BlocProvider(
        create: (_) => GeneBankAuditCubit(
          eventRepository: eventRepository,
          targetNode: targetNode,
          existingEvent: existingEvent,
        ),
        child: GeneBankAuditDialog(
          targetNode: targetNode,
          existingEvent: existingEvent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GeneBankAuditCubit, GeneBankAuditState>(
      listener: (context, state) {
        if (state.createdEvent != null && context.mounted) {
          popSafeDialogContext(context, state.createdEvent);
        }
        if (state.errorMessage != null) {
          showSafeDialogSnackBar(
            context,
            state.errorMessage!,
            isError: true,
          );
        }
      },
      builder: (context, state) {
        return AlertDialog(
          title: const Text('Gene Bank Audit'),
          content: SizedBox(
            width: 400,
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Audit type
                  DropdownButtonFormField<String>(
                    initialValue: state.auditType,
                    decoration: const InputDecoration(
                      labelText: 'Audit Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'routine',
                        child: Text('Routine'),
                      ),
                      DropdownMenuItem(
                        value: 'comprehensive',
                        child: Text('Comprehensive'),
                      ),
                      DropdownMenuItem(
                        value: 'spot_check',
                        child: Text('Spot Check'),
                      ),
                    ],
                    onChanged: state.isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              context
                                  .read<GeneBankAuditCubit>()
                                  .auditTypeChanged(value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),

                  // Items verified (optional)
                  TextFormField(
                    initialValue: state.itemsVerified?.toString() ?? '',
                    enabled: !state.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Items Verified',
                      hintText: 'Number of items checked (optional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final count = int.tryParse(value);
                      context.read<GeneBankAuditCubit>().itemsVerifiedChanged(
                        count == null || count <= 0 ? null : count,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Has discrepancies
                  CheckboxListTile(
                    title: const Text('Discrepancies Found'),
                    value: state.hasDiscrepancies,
                    onChanged: state.isLoading
                        ? null
                        : (value) {
                            context
                                .read<GeneBankAuditCubit>()
                                .hasDiscrepanciesChanged(value ?? false);
                          },
                  ),

                  // Discrepancy notes (if discrepancies found)
                  if (state.hasDiscrepancies) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: state.discrepancyNotes ?? '',
                      enabled: !state.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Discrepancy Notes',
                        hintText: 'Describe any discrepancies found',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        context
                            .read<GeneBankAuditCubit>()
                            .discrepancyNotesChanged(
                              value.isEmpty ? null : value,
                            );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Comment
                  TextFormField(
                    initialValue: state.comment,
                    enabled: !state.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Additional notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (value) {
                      context.read<GeneBankAuditCubit>().commentChanged(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.isLoading ? null : () => popSafeDialogContext(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: state.isLoading || !state.canSubmit
                  ? null
                  : () => _submit(context),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(state.isEditing ? 'Update' : 'Record Audit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit(BuildContext context) async {
    try {
      await context.read<GeneBankAuditCubit>().submit();
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to save gene bank audit',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      ToastOverlay.showSnackBar(context,
        SnackBar(content: Text('Failed to save audit: $error')),
      );
    }
  }
}
