// @tier: community
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/cubits/environmental_adjustment_event/environmental_adjustment_event_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/services/offline/activity_event_offline_handler.dart';
import 'package:seafoundry_app/utils/permit_metadata_policy.dart';
import 'package:seafoundry_app/widgets/dialogs/components/camera_permission_controls.dart';
import 'package:seafoundry_app/widgets/dialogs/components/observation_target_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/components/observation_target_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/components/permit_selector_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for recording an environmental adjustment event
class EnvironmentalAdjustmentEventDialog extends StatelessWidget {
  final GraphNode node;
  final String? userId;
  final bool isPro;

  const EnvironmentalAdjustmentEventDialog({
    super.key,
    required this.node,
    this.userId,
    this.isPro = false,
  });

  static Future<EnvironmentalAdjustmentEvent?> show(
    BuildContext context, {
    required GraphNode node,
    EnvironmentalAdjustmentEvent? existingEvent,
  }) {
    // Read dependencies BEFORE showDialog to ensure provider scope
    final eventRepository = context.read<EventRepository>();
    final propagationService = context.read<EventPropagationService>();
    final imageService = context.read<ImageService>();
    ActivityEventOfflineHandler? offlineHandler;
    try {
      offlineHandler = context.read<ActivityEventOfflineHandler>();
    } catch (_) {
      offlineHandler = null;
    }

    // Capture userId and isPro from CurrentUser for permit creation
    final currentUserState = context.read<CurrentUser>().state;
    final userId =
        currentUserState is CurrentUserLoaded ? currentUserState.user.id : null;
    final isPro = currentUserState is CurrentUserLoaded &&
        currentUserState.organization.tier.index >= Tier.pro.index;

    return showDialog<EnvironmentalAdjustmentEvent>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false, // Stay in provider scope
      builder: (dialogContext) => MultiProvider(
        providers: [
          RepositoryProvider<EventRepository>.value(value: eventRepository),
          Provider<EventPropagationService>.value(value: propagationService),
          Provider<ImageService>.value(value: imageService),
        ],
        child: BlocProvider(
          create: (_) => EnvironmentalAdjustmentEventCubit(
            eventRepository: eventRepository,
            imageService: imageService,
            existingEvent: existingEvent,
            offlineHandler: offlineHandler,
          )..initializeCameraPermission(),
          child: EnvironmentalAdjustmentEventDialog(
            node: node,
            userId: userId,
            isPro: isPro,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EnvironmentalAdjustmentEventDialogContent(
      node: node,
      userId: userId,
      isPro: isPro,
    );
  }
}

class _EnvironmentalAdjustmentEventDialogContent extends StatefulWidget {
  final GraphNode node;
  final String? userId;
  final bool isPro;

  const _EnvironmentalAdjustmentEventDialogContent({
    required this.node,
    this.userId,
    this.isPro = false,
  });

  @override
  State<_EnvironmentalAdjustmentEventDialogContent> createState() =>
      _EnvironmentalAdjustmentEventDialogContentState();
}

class _EnvironmentalAdjustmentEventDialogContentState
    extends State<_EnvironmentalAdjustmentEventDialogContent>
    with
        SafeDialogMixin<_EnvironmentalAdjustmentEventDialogContent>,
        ObservationTargetMixin<_EnvironmentalAdjustmentEventDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _previousValueController;
  late final TextEditingController _newValueController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  late final TextEditingController _commentController;
  late final ObservationTargetController _targetController;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<EnvironmentalAdjustmentEventCubit>();

    // Initialize controllers with current state
    _previousValueController = TextEditingController(
      text: cubit.state.previousValue,
    );
    _newValueController = TextEditingController(text: cubit.state.newValue);
    _amountController = TextEditingController(text: cubit.state.amount);
    _unitController = TextEditingController(text: cubit.state.unit);
    _commentController = TextEditingController(text: cubit.state.comment);

    _targetController = registerTargetController(
      ObservationTargetController(rootNode: widget.node),
    );

    // Listen to controller changes and update cubit
    _previousValueController.addListener(() {
      cubit.updatePreviousValue(_previousValueController.text);
    });
    _newValueController.addListener(() {
      cubit.updateNewValue(_newValueController.text);
    });
    _amountController.addListener(() {
      cubit.updateAmount(_amountController.text);
    });
    _unitController.addListener(() {
      cubit.updateUnit(_unitController.text);
    });
    _commentController.addListener(() {
      cubit.updateComment(_commentController.text);
    });
  }

  @override
  void dispose() {
    _previousValueController.dispose();
    _newValueController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture Navigator before async operations
    final cubit = context.read<EnvironmentalAdjustmentEventCubit>();
    final result = await cubit.submit(
      () => _targetController.resolveTargetNodes(),
    );

    if (!mounted) return;

    if (result != null) {
      _requestReload(widget.node);

      popDialog(result);
    }
  }

  void _requestReload(GraphNode node) {
    if (!node.isClosed) {
      node.add(const GraphNodeReloadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      EnvironmentalAdjustmentEventCubit,
      EnvironmentalAdjustmentEventState
    >(
      listener: (context, state) {
        if (!mounted) return;
        final notification = state.notification;
        if (notification != null) {
          showDialogSnackBar(
            notification.message,
            isError: notification.isError,
            isSuccess: notification.isSuccess,
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<EnvironmentalAdjustmentEventCubit>();

        return AlertDialog(
          title: const Text('Environmental Adjustment'),
          content: Form(
            key: _formKey,
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Adjustment Type Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: state.adjustmentTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Adjustment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: EnvironmentalAdjustmentType.values.map((type) {
                      return DropdownMenuItem(
                        value: type.id,
                        child: Text(type.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        cubit.updateAdjustmentType(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Previous Value
                  TextFormField(
                    controller: _previousValueController,
                    decoration: const InputDecoration(
                      labelText: 'Previous Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Value
                  TextFormField(
                    controller: _newValueController,
                    decoration: const InputDecoration(
                      labelText: 'New Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount and Unit
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            hintText: '°C, %',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Comment
                  TextFormField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  _buildPermitSection(state),
                  const SizedBox(height: 16),

                  ObservationTargetSelector(
                    controller: _targetController,
                    description: 'Apply to sub-structures',
                    selectAllByDefault: true,
                  ),
                  const SizedBox(height: 16),

                  _buildImagePreview(state, cubit),
                  _buildCameraControls(state, cubit),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.isSubmitting ? null : popDialog,
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: state.isSubmitting ? null : _submitForm,
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreview(
    EnvironmentalAdjustmentEventState state,
    EnvironmentalAdjustmentEventCubit cubit,
  ) {
    final path = state.imagePath;
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final isRemote = path.startsWith('http://') || path.startsWith('https://');

    Widget preview;
    if (isRemote) {
      preview = Image.network(
        path,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 200,
          alignment: Alignment.center,
          color: Colors.black12,
          child: const Text('Unable to load image preview'),
        ),
      );
    } else {
      preview = Image.file(
        File(path),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photo:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Stack(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: preview),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                color: Colors.white,
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => cubit.removeImage(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCameraControls(
    EnvironmentalAdjustmentEventState state,
    EnvironmentalAdjustmentEventCubit cubit,
  ) {
    if (state.imagePath != null) {
      return const SizedBox.shrink();
    }

    return CameraPermissionControls(
      permissionStatus: state.cameraStatus,
      isBusy: state.isCapturingImage || state.isSubmitting,
      enabled: !state.isSubmitting,
      onCapture: cubit.captureImage,
      onRequestPermission: cubit.requestCameraPermission,
      onOpenSettings: openAppSettings,
    );
  }

  Widget _buildPermitSection(EnvironmentalAdjustmentEventState state) {
    final cubit = context.read<EnvironmentalAdjustmentEventCubit>();
    final site = _resolveActiveSite();
    final supportsPermits = PermitMetadataPolicy.siteSupportsPermits(site);
    final siteName = site?.name ?? 'this site';
    final fieldsEnabled = !state.isSubmitting;
    final permitId = state.permitId;
    final permitType = state.permitType;
    final issuingAuthority = state.issuingAuthority;

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
          userId: widget.userId,
          isPro: widget.isPro,
          selectedPermitId: permitId.isNotEmpty ? permitId : null,
          enabled: fieldsEnabled,
          displayOptions: PermitSelectorDisplayOptions.compact,
          onPermitSelected: (permit) {
            if (permit == null) {
              cubit
                ..updatePermitId('')
                ..updatePermitType('')
                ..updateIssuingAuthority('')
                ..updatePermitAttachmentUrls('')
                ..updatePermitValidFrom(null)
                ..updatePermitValidTo(null);
            } else {
              cubit
                ..updatePermitId(permit.permitNumber)
                ..updatePermitType(permit.type.displayName)
                ..updateIssuingAuthority(permit.issuingAuthority)
                ..updatePermitAttachmentUrls(permit.attachmentUrls.join(', '))
                ..updatePermitValidFrom(permit.validFrom)
                ..updatePermitValidTo(permit.validTo);
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
    final siteNode = widget.node.siteNode;
    if (siteNode == null) return null;
    final state = siteNode.state;
    if (state is GraphLoadedState<Site>) {
      return state.record;
    }
    final initialRecord = siteNode.initialRecord;
    return initialRecord;
  }
}