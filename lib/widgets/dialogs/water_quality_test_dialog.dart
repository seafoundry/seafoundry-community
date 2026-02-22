// @tier: community
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/water_quality/water_quality_test_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/types/water_quality_parameter.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/permit_metadata_policy.dart';
import 'package:seafoundry_app/widgets/dialogs/components/observation_target_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/components/observation_target_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/components/permit_selector_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for recording water quality test parameters
///
/// **Architecture**: Uses WaterQualityTestCubit for state management. The StatefulWidget
/// wrapper (_WaterQualityTestDialogContent) is required for TextEditingController lifecycle
/// management (comment field and parameter value fields).
class WaterQualityTestDialog extends StatelessWidget {
  final GraphNode targetNode;
  final WaterQualityTestEvent? existingTest;

  const WaterQualityTestDialog({
    super.key,
    required this.targetNode,
    this.existingTest,
  });

  static Future<WaterQualityTestEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
    WaterQualityTestEvent? existingTest,
  }) {
    final eventRepository = context.read<EventRepository>();

    return showDialog<WaterQualityTestEvent>(
      context: context,
      useRootNavigator: false,
      builder: (context) => BlocProvider(
        create: (_) => WaterQualityTestCubit(
          eventRepository: eventRepository,
          targetNode: targetNode,
          existingTest: existingTest,
        ),
        child: WaterQualityTestDialog(
          targetNode: targetNode,
          existingTest: existingTest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _WaterQualityTestDialogContent(
      targetNode: targetNode,
      existingTest: existingTest,
    );
  }
}

class _WaterQualityTestDialogContent extends StatefulWidget {
  const _WaterQualityTestDialogContent({
    required this.targetNode,
    this.existingTest,
  });

  final GraphNode targetNode;
  final WaterQualityTestEvent? existingTest;

  @override
  State<_WaterQualityTestDialogContent> createState() =>
      _WaterQualityTestDialogContentState();
}

class _WaterQualityTestDialogContentState
    extends State<_WaterQualityTestDialogContent>
    with
        SafeDialogMixin<_WaterQualityTestDialogContent>,
        ObservationTargetMixin<_WaterQualityTestDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final Map<String, TextEditingController> _parameterControllers = {};
  ObservationTargetController? _targetController;
  bool _isUpdatingComment = false;

  // List of parameters to display
  final List<WaterQualityParameter> _availableParameters =
      WaterQualityParameter.builtInParameters;

  @override
  void initState() {
    super.initState();
    final cubitState = context.read<WaterQualityTestCubit>().state;
    _commentController.text = cubitState.comment;
    _commentController.addListener(_onCommentChanged);

    // Initialize parameter controllers from state
    for (final parameterId in cubitState.selectedParameterIds) {
      final value = cubitState.parameterValues[parameterId];
      _parameterControllers[parameterId] = TextEditingController(
        text: value?.toString() ?? '',
      );
    }

    // Initialize target controller if not editing
    if (!cubitState.isEditing) {
      _targetController = registerTargetController(
        ObservationTargetController(rootNode: widget.targetNode),
      );
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    for (final controller in _parameterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onCommentChanged() {
    if (_isUpdatingComment) return;
    context.read<WaterQualityTestCubit>().commentChanged(
      _commentController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WaterQualityTestCubit, WaterQualityTestState>(
      listener: (context, state) {
        if (!mounted) return;

        // Sync comment controller with cubit state
        if (_commentController.text != state.comment) {
          _isUpdatingComment = true;
          _commentController.value = _commentController.value.copyWith(
            text: state.comment,
            selection: TextSelection.collapsed(offset: state.comment.length),
          );
          _isUpdatingComment = false;
        }

        // Handle success - close dialog
        if (state.createdEvent != null) {
          popDialog(state.createdEvent);
        }

        // Show error messages
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          showDialogSnackBar(
            state.errorMessage!,
            isError: true,
            duration: const Duration(seconds: 5),
          );
        }
      },
      builder: (context, state) {
        final size = MediaQuery.sizeOf(context);
        final maxWidth = (size.width - 32).clamp(0.0, size.width);
        final dialogWidth = math.min(500.0, maxWidth);
        final maxHeight = size.height * 0.9;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      state.isEditing
                          ? 'Edit Water Quality Test'
                          : 'Record Water Quality Test',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: DialogScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_targetController != null) ...[
                              ObservationTargetSelector(
                                controller: _targetController!,
                                description: 'Apply to sub-structures',
                                selectAllByDefault: true,
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Parameter selection
                            const Text(
                              'Parameters',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Scrollable list of parameter inputs
                            Container(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: DialogScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Selected parameters
                                    ...state.selectedParameterIds.map((
                                      parameterId,
                                    ) {
                                      final parameter =
                                          WaterQualityParameter.fromId(
                                            parameterId,
                                          );
                                      if (parameter == null) {
                                        return const SizedBox.shrink();
                                      }

                                      return _buildParameterInput(
                                        context,
                                        parameter,
                                        state,
                                      );
                                    }),

                                    // Add parameter button
                                    if (state.selectedParameterIds.length <
                                        _availableParameters.length)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        title: const Text('Add Parameter'),
                                        onTap: () => _showAddParameterDialog(
                                          context,
                                          state,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Comment
                            TextFormField(
                              controller: _commentController,
                              enabled: !state.isLoading,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                hintText: 'Add any additional notes (optional)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            _buildPermitSection(state),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: state.isLoading ? null : popDialog,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: state.isLoading
                              ? null
                              : () => _submitForm(context),
                          child: state.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(state.isEditing ? 'Update' : 'Record'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build an input field for a parameter
  Widget _buildParameterInput(
    BuildContext context,
    WaterQualityParameter parameter,
    WaterQualityTestState state,
  ) {
    final cubit = context.read<WaterQualityTestCubit>();
    final textController = _parameterControllers.putIfAbsent(
      parameter.id,
      () => TextEditingController(
        text: state.parameterValues[parameter.id]?.toString() ?? '',
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: textController,
              enabled: !state.isLoading,
              decoration: InputDecoration(
                labelText: parameter.label,
                hintText: 'Enter ${parameter.label.toLowerCase()}',
                suffixText: parameter.unit,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null; // Optional field
                }

                final parsedValue = double.tryParse(value);
                if (parsedValue == null) {
                  return 'Enter a valid number';
                }

                return null;
              },
              onChanged: (value) {
                final parsedValue = double.tryParse(value);
                cubit.parameterValueChanged(parameter.id, parsedValue);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: state.isLoading
                ? null
                : () => cubit.removeParameter(parameter.id),
            tooltip: 'Remove parameter',
          ),
        ],
      ),
    );
  }

  /// Show dialog to add a new parameter
  void _showAddParameterDialog(
    BuildContext context,
    WaterQualityTestState state,
  ) {
    final cubit = context.read<WaterQualityTestCubit>();
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Parameter'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._availableParameters
                  .where(
                    (param) => !state.selectedParameterIds.contains(param.id),
                  )
                  .map(
                    (param) => ListTile(
                      title: Text(param.label),
                      subtitle: Text('Unit: ${param.unit}'),
                      onTap: () {
                        popSafeDialogContext(dialogContext);
                        cubit.addParameter(param.id);
                      },
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => popSafeDialogContext(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Submit the form
  Future<void> _submitForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<WaterQualityTestCubit>();
    final state = cubit.state;

    // Ensure at least one parameter is selected and has a value
    if (!state.canSubmit) {
      showDialogSnackBar(
        'Please enter at least one parameter value',
        isError: true,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final controller = _targetController;
    final targets = controller == null
        ? <GraphNode>[widget.targetNode]
        : await controller.resolveTargetNodes();

    if (!mounted) return;

    if (targets.isEmpty) {
      showDialogSnackBar(
        'Unable to determine observation targets',
        isError: true,
      );
      return;
    }

    await cubit.submit(
      targetNodes: targets,
      onSuccess: (event) {
        if (!mounted) return;
        LoggingService.instance.info(
          state.isEditing
              ? 'Water quality test updated: ${event.id}'
              : 'Water quality test recorded successfully: ${event.id}',
        );
        showDialogSnackBar(
          state.isEditing
              ? 'Water quality test updated successfully'
              : 'Water quality test recorded successfully',
          isSuccess: true,
        );
      },
      onError: (error) {
        // Error is already shown via BlocListener
        LoggingService.instance.error('Error saving water quality test', error);
      },
    );
  }

  Widget _buildPermitSection(WaterQualityTestState state) {
    final cubit = context.read<WaterQualityTestCubit>();
    final site = _resolveActiveSite();
    final supportsPermits = PermitMetadataPolicy.siteSupportsPermits(site);
    final siteName = site?.name ?? 'this site';
    final fieldsEnabled = !state.isLoading;
    final permitId = state.permitId;
    final permitType = state.permitType;
    final issuingAuthority = state.issuingAuthority;

    // Capture user context for permit creation
    final currentUserState = context.read<CurrentUser>().state;
    final userId = currentUserState is CurrentUserLoaded
        ? currentUserState.user.id
        : null;
    final isPro = currentUserState is CurrentUserLoaded &&
        (currentUserState.organization.tier == Tier.pro ||
            currentUserState.organization.tier == Tier.scale);

    if (!supportsPermits) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permit metadata is disabled for $siteName.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permit (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        PermitSelectorWidget(
          organizationId: context.read<Organization>().id,
          userId: userId,
          isPro: isPro,
          selectedPermitId: permitId.isNotEmpty ? permitId : null,
          enabled: fieldsEnabled,
          displayOptions: PermitSelectorDisplayOptions.compact,
          onPermitSelected: (permit) {
            if (permit == null) {
              cubit
                ..permitIdChanged('')
                ..permitTypeChanged('')
                ..issuingAuthorityChanged('')
                ..permitAttachmentUrlsChanged('')
                ..permitValidFromChanged(null)
                ..permitValidToChanged(null);
            } else {
              cubit
                ..permitIdChanged(permit.permitNumber)
                ..permitTypeChanged(permit.type.displayName)
                ..issuingAuthorityChanged(permit.issuingAuthority)
                ..permitAttachmentUrlsChanged(permit.attachmentUrls.join(', '))
                ..permitValidFromChanged(permit.validFrom)
                ..permitValidToChanged(permit.validTo);
            }
          },
        ),
        if (permitId.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedPermitDetails(
            permitId: permitId,
            permitType: permitType,
            issuingAuthority: issuingAuthority,
            validFrom: state.permitValidFrom,
            validTo: state.permitValidTo,
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedPermitDetails({
    required String permitId,
    required String permitType,
    required String issuingAuthority,
    required DateTime? validFrom,
    required DateTime? validTo,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(4),
        color: Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Selected Permit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPermitDetailRow('Permit #', permitId),
          if (permitType.isNotEmpty) _buildPermitDetailRow('Type', permitType),
          if (issuingAuthority.isNotEmpty)
            _buildPermitDetailRow('Authority', issuingAuthority),
          if (validFrom != null && validTo != null)
            _buildPermitDetailRow(
              'Valid',
              '${_formatPermitDate(validFrom)} - ${_formatPermitDate(validTo)}',
            ),
        ],
      ),
    );
  }

  Widget _buildPermitDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatPermitDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Site? _resolveActiveSite() {
    final siteNode = widget.targetNode.siteNode;
    if (siteNode == null) return null;
    final state = siteNode.state;
    if (state is GraphLoadedState<Site>) {
      return state.record;
    }
    final initialRecord = siteNode.initialRecord;
    return initialRecord;
  }
}