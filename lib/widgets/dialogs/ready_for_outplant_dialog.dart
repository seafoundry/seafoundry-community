// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/mixins/event_propagation_mixin.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'components/dialog_scroll_view.dart';

class ReadyForOutplantDialog extends StatefulWidget {
  final OrganismRecord organism;
  final OrganismNode? organismNode;

  const ReadyForOutplantDialog({
    super.key,
    required this.organism,
    this.organismNode,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OrganismRecord organism,
    OrganismNode? organismNode,
  }) {
    final organismRepository = context.read<OrganismRecordRepository>();

    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => RepositoryProvider.value(
        value: organismRepository,
        child: ReadyForOutplantDialog(
          organism: organism,
          organismNode: organismNode,
        ),
      ),
    );
  }

  @override
  State<ReadyForOutplantDialog> createState() => _ReadyForOutplantDialogState();
}

class _ReadyForOutplantDialogState extends State<ReadyForOutplantDialog>
    with EventPropagationMixin, SafeDialogMixin<ReadyForOutplantDialog> {
  final bool _propagateEvent = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _comment = '';

  @override
  Widget build(BuildContext context) {
    final organismRepository = context.read<OrganismRecordRepository>();
    final isClearing = widget.organism.readyForOutplant;
    final recordName = widget.organism.organismKind.metadata.displayName;

    return AlertDialog(
      title: Row(
        children: [
          UI.iconMedium(
            Icons.nature,
            color: isClearing ? Colors.orange : Colors.green,
          ),
          UI.spacingHorizontalSm,
          Text(
            isClearing
                ? 'Clear Ready for Outplant'
                : 'Mark as Ready for Outplant',
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: DialogScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show error if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      UI.spacingHorizontalSm,
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                UI.spacingVerticalMd,
              ],

              // Organism info card
              Card(
                child: Padding(
                  padding: UI.paddingSm,
                  child: Row(
                    children: [
                      UI.iconSmall(Icons.water_drop, color: Colors.blue),
                      UI.spacingHorizontalSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UIText.bodyMedium(widget.organism.name),
                            UIText.caption(
                              isClearing
                                  ? 'Currently marked as ready for outplanting'
                                  : 'Not marked as ready for outplanting',
                              color: isClearing ? Colors.green : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              UI.spacingVerticalMd,

              // Status action card
              Card(
                color: isClearing
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: UI.paddingMd,
                  child: Row(
                    children: [
                      UI.iconMedium(
                        isClearing ? Icons.close : Icons.check_circle,
                        color: isClearing ? Colors.orange : Colors.green,
                      ),
                      UI.spacingHorizontalSm,
                      Expanded(
                        child: UIText.bodyMedium(
                          isClearing
                              ? 'This will clear the ready for outplant status'
                              : 'This $recordName will be marked as ready for outplanting',
                          color: isClearing
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              UI.spacingVerticalMd,

              // Comment field
              TextFormField(
                initialValue: _comment,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _comment = value;
                        });
                      },
                decoration: InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: isClearing
                      ? 'Add notes about clearing outplant status...'
                      : 'Add notes about marking as ready...',
                  prefixIcon: const Icon(Icons.comment),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_isSubmitting,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => popDialog(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () => _handleSubmit(context, organismRepository, isClearing),
          style: ElevatedButton.styleFrom(
            backgroundColor: isClearing ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isClearing ? 'Clear Status' : 'Mark Ready'),
        ),
      ],
    );
  }

  Future<void> _handleSubmit(
    BuildContext context,
    OrganismRecordRepository organismRepository,
    bool isClearing,
  ) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final newReadyForOutplant = !isClearing;

      // Only update if there's a change
      if (widget.organism.readyForOutplant == newReadyForOutplant) {
        if (mounted) {
          popDialog(false);
        }
        return;
      }

      final updatedOrganism = widget.organism.copyWith(
        metadata: {
          ...widget.organism.metadata ?? {},
          'readyForOutplant': newReadyForOutplant,
        },
        updatedAt: DateTime.now().toIso8601String(),
        updatedById: organismRepository.user.id,
      );

      // Update the organism record and create an observation event
      final eventId = generateId(firestore: organismRepository.firestore); // Generate unique ID
      final eventSlug = await organismRepository.nextSlugForModelType(
        ModelType.event,
      );
      await organismRepository.snapshotService.createBeforeSnapshot(
        record: widget.organism,
        eventId: eventId,
      );
      final now = DateTime.now().toIso8601String();

      final observationEvent = ObservationEvent(
        id: eventId,
        createdById: organismRepository.user.id,
        createdAt: now,
        updatedAt: now,
        updatedById: organismRepository.user.id,
        organizationId: organismRepository.organization.id,
        recordId: widget.organism.id,
        urlPath: '${widget.organism.urlPath}/$eventSlug',
        internalPath: '${widget.organism.internalPath}/$eventId',
        slug: eventSlug,
        recordModelType: ModelType.organismRecord,
        comment: _comment.isEmpty
            ? (isClearing
                  ? 'Cleared ready for outplant status'
                  : 'Marked as ready for outplant')
            : _comment,
      );

      final batch = organismRepository.db.batch();
      await organismRepository.updateRecord(updatedOrganism, batch: batch);
      await organismRepository.eventRepository.createEvent(
        observationEvent,
        batch: batch,
      );
      await batch.commit();

      await organismRepository.snapshotService.createAfterSnapshot(
        record: updatedOrganism,
        eventId: eventId,
      );

      // Propagate event if enabled
      if (_propagateEvent) {
        await propagateEvent(
          event: observationEvent,
          activityType: 'Outplant Status Update',
          description: isClearing
              ? 'Outplant status cleared for ${widget.organism.name}'
              : '${widget.organism.name} marked as ready for outplant',
        );
      }

      if (mounted) {
        _requestGraphReloads();
        popDialog(true);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update ready for outplant status',
        e,
        stackTrace,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to update status: ${e.toString()}';
        });
      }
    }
  }

  void _requestGraphReloads() {
    final nodes = <GraphNode?>{widget.organismNode, widget.organismNode?.parent};
    for (final node in nodes) {
      if (node != null && !node.isClosed) {
        node.add(const GraphNodeReloadRequested());
      }
    }
  }
}