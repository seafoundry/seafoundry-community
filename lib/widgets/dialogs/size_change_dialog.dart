// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/inventory_event/inventory_event_creation_bloc.dart';
import 'package:seafoundry_app/blocs/inventory_event/inventory_event_form_inputs.dart';
import 'package:seafoundry_app/blocs/inventory_event/inventory_event_form_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/models/events/size_change_event.dart';
import 'package:seafoundry_app/models/events/status_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/mixins/event_propagation_mixin.dart';
import 'package:seafoundry_app/widgets/common/size_change_editor.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for recording organism size changes (growth or tissue loss)
///
/// **Migration Status**: Migrated to OrganismRecord (Phase 3)
///
/// **Why StatefulWidget**:
/// - Uses `EventPropagationMixin` which requires StatefulWidget lifecycle hooks
///   (mixin methods like `propagateEvent` need access to mounted state)
/// - Mixin pattern requires widget lifecycle for proper initialization/disposal
/// - Event propagation needs access to widget context and mounted state for
///   navigation protection and error handling
///
/// **Architecture**: Uses BLoC pattern (`InventoryEventCreationBloc`) for form state,
/// but StatefulWidget wrapper required for mixin lifecycle. This is the correct
/// pattern when using mixins that require widget lifecycle.
///
/// **Size Tracking**: Uses SizeSpec (sizeClass) instead
/// of coral-specific CoralSize enum. Works across all organism types.
class SizeChangeDialog extends StatefulWidget {
  final OrganismRecord organism;
  final OrganismNode? organismNode;

  const SizeChangeDialog({
    super.key,
    required this.organism,
    this.organismNode,
  });

  static Future<SizeChangeEvent?> show(
    BuildContext context, {
    required OrganismRecord organism,
    StatusEvent? fragReadyEvent,
    OrganismNode? organismNode,
  }) {
    final organismRepository = context.read<OrganismRecordRepository>();

    return showDialog<SizeChangeEvent>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => RepositoryProvider.value(
        value: organismRepository,
        child: BlocProvider(
          create: (_) => InventoryEventCreationBloc.organismSize(
            organism: organism,
            organismRepository: organismRepository,
            ongoingEvent: fragReadyEvent,
          ),
          child: SizeChangeDialog(
            organism: organism,
            organismNode: organismNode,
          ),
        ),
      ),
    );
  }

  @override
  State<SizeChangeDialog> createState() => _SizeChangeDialogState();
}

class _SizeChangeDialogState extends State<SizeChangeDialog>
    with EventPropagationMixin, SafeDialogMixin<SizeChangeDialog> {
  final bool _propagateEvent = true;
  PhysicalFormConfig? _physicalFormConfig;
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final formId = widget.organism.physicalForm?.formId;
    if (formId == null) {
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
        });
      }
      return;
    }

    try {
      final config = await PhysicalFormRegistry.instance.getFormConfig(
        widget.organism.organismKind,
        widget.organism.lifeStage.stage,
        formId,
      );
      if (mounted) {
        setState(() {
          _physicalFormConfig = config;
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        LoggingService.instance.error('Failed to load physical form config', e);
        setState(() {
          _isLoadingConfig = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InventoryEventCreationBloc, InventoryEventFormState>(
      listener: (context, state) async {
        if (state.submissionStatus == FormzSubmissionStatus.success) {
          // Propagate event if enabled
          if (_propagateEvent && state.createdRecord != null) {
            final organismKind = widget.organism.organismKind;
            try {
              await propagateEvent(
                event: state.createdRecord!,
                activityType: '${organismKind.metadata.displayName} Size Update',
                description: '${widget.organism.name} size updated',
              );
              if (!mounted) {
                return;
              }
            } catch (error, stackTrace) {
              // Propagation is best-effort; log and continue closing the dialog.
              LoggingService.instance.error(
                'Failed to propagate size change event ${state.createdRecord?.id}',
                error,
                stackTrace,
              );
            }
          }
          if (mounted) {
            // Stream subscription handles updates automatically - reload causes race condition
            popDialog(state.createdRecord);
          }
        }
      },
      builder: (context, state) {
        if (state.submissionStatus == FormzSubmissionStatus.inProgress) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildDialog(context, state);
      },
    );
  }

  Widget _buildDialog(BuildContext context, InventoryEventFormState state) {
    final bloc = context.read<InventoryEventCreationBloc>();
    final isSubmitting =
        state.submissionStatus == FormzSubmissionStatus.inProgress;
    final hasExistingSize = widget.organism.sizeSpec.hasSize;
    final isFirstStep = state.currentStepIndex == 0;
    final isSecondStep = state.currentStepIndex == 1;
    final organismKind = widget.organism.organismKind;

    return AlertDialog(
      title: Row(
        children: [
          UI.iconMedium(Icons.straighten, color: Colors.blue),
          UI.spacingHorizontalSm,
          Text(hasExistingSize ? 'Size Change' : 'Track Size'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: DialogScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show submission error if any
              if (state.submissionError != null) ...[
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
                          state.submissionError!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                UI.spacingVerticalMd,
              ],

              // Organism info
              Card(
                child: Padding(
                  padding: UI.paddingSm,
                  child: Row(
                    children: [
                      UI.iconSmall(Icons.biotech, color: Colors.blue),
                      UI.spacingHorizontalSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UIText.bodyMedium(widget.organism.name),
                            if (widget.organism.sizeSpec.hasSize) ...[
                              UIText.caption(
                                'Current size: ${_getSizeLabel(widget.organism.sizeSpec)}',
                              ),
                            ] else ...[
                              UIText.caption('Size not tracked'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              UI.spacingVerticalMd,

              // Step 1: Change type selection (only if organism has size)
              if (hasExistingSize && isFirstStep) ...[
                UIText.bodyMedium('What are you reporting?'),
                UI.spacingVerticalSm,
                Column(
                  children: [
                    Card(
                      color: state.eventType?.value == CoralSizeEventType.growth
                          ? Colors.green.withValues(alpha: 0.1)
                          : null,
                      child: ListTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.green.shade600,
                            ),
                            UI.spacingHorizontalSm,
                            const Text('Growth'),
                          ],
                        ),
                        subtitle: Text(
                          'The ${organismKind.metadata.displayName.toLowerCase()} has grown larger',
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color:
                              state.eventType?.value ==
                                  CoralSizeEventType.growth
                              ? Colors.green.shade600
                              : null,
                        ),
                        onTap: isSubmitting
                            ? null
                            : () {
                                bloc.add(
                                  EventTypeSelected(CoralSizeEventType.growth),
                                );
                                bloc.add(const RecordFormNextStep());
                              },
                      ),
                    ),
                    UI.spacingVerticalXs,
                    Card(
                      color:
                          state.eventType?.value ==
                              CoralSizeEventType.tissueLoss
                          ? Colors.orange.withValues(alpha: 0.1)
                          : null,
                      child: ListTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons.trending_down,
                              color: Colors.orange.shade600,
                            ),
                            UI.spacingHorizontalSm,
                            const Text('Tissue Loss / Size Reduction'),
                          ],
                        ),
                        subtitle: Text(
                          'The ${organismKind.metadata.displayName.toLowerCase()} has experienced size reduction',
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color:
                              state.eventType?.value ==
                                  CoralSizeEventType.tissueLoss
                              ? Colors.orange.shade600
                              : null,
                        ),
                        onTap: isSubmitting
                            ? null
                            : () {
                                bloc.add(
                                  EventTypeSelected(
                                    CoralSizeEventType.tissueLoss,
                                  ),
                                );
                                bloc.add(const RecordFormNextStep());
                              },
                      ),
                    ),
                  ],
                ),
              ],

              // Step 2 (or only step): Size input
              if (!hasExistingSize || isSecondStep) ...[
                UIText.bodyMedium(
                  hasExistingSize ? 'Enter New Size' : 'Enter Size',
                ),
                UI.spacingVerticalSm,

                Builder(
                  builder: (context) {
                    return SizeChangeEditor(
                      // We don't show current size in editor (handled by dialog header),
                      // but we pass currentSize just in case or for consistency.
                      currentSize: widget.organism.sizeSpec,
                      showCurrentSize: false,
                      sizeBandConfigs: _physicalFormConfig?.sizeBands ?? [],
                      selectedSizeClass: state.sizeClass?.value,
                      onSizeClassChanged: (value) =>
                          bloc.add(SizeClassChanged(value)),
                      isBusy: isSubmitting || _isLoadingConfig,
                      placeholderLabel: hasExistingSize ? 'New Size Class' : 'Size Class',
                      // Not wiring up volume/tissue area yet as Bloc doesn't expose them
                    );
                  },
                ),
                UI.spacingVerticalMd,

                // Comment field
                TextFormField(
                  initialValue: state.comment?.value,
                  onChanged: isSubmitting
                      ? null
                      : (value) {
                          bloc.add(InventoryEventCommentChanged(value));
                        },
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    hintText: 'Add notes about this size change...',
                    prefixIcon: Icon(Icons.comment),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !isSubmitting,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => popDialog(),
          child: const Text('Cancel'),
        ),
        if (hasExistingSize && isFirstStep) ...[
          ElevatedButton(
            onPressed: state.eventType?.value != null && !isSubmitting
                ? () => bloc.add(const RecordFormNextStep())
                : null,
            child: const Text('Next'),
          ),
        ] else ...[
          if (hasExistingSize && isSecondStep) ...[
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => bloc.add(const RecordFormPreviousStep()),
              child: const Text('Back'),
            ),
          ],
          ElevatedButton(
            onPressed: state.isValid && !isSubmitting
                ? () => bloc.add(const RecordFormSubmit())
                : null,
            child: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm'),
          ),
        ],
      ],
    );
  }

  String _getSizeLabel(SizeSpec sizeSpec) {
    if (sizeSpec.sizeClass != null && sizeSpec.measuredDimension != null) {
      return '${sizeSpec.sizeClass} (${sizeSpec.measuredDimension} ${sizeSpec.dimensionUnit?.label ?? ''})';
    } else if (sizeSpec.sizeClass != null) {
      return sizeSpec.sizeClass!;
    } else if (sizeSpec.measuredDimension != null) {
      return '${sizeSpec.measuredDimension} ${sizeSpec.dimensionUnit?.label ?? ''}';
    }
    return 'Unknown';
  }

}
