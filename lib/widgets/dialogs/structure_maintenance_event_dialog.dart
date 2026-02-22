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
import 'package:seafoundry_app/cubits/structure_maintenance_event/structure_maintenance_event_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/services/offline/activity_event_offline_handler.dart';
import 'package:seafoundry_app/utils/permit_metadata_policy.dart';
import 'package:seafoundry_app/widgets/dialogs/components/camera_permission_controls.dart';
import 'package:seafoundry_app/widgets/dialogs/components/permit_selector_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for recording a structure maintenance event
class StructureMaintenanceEventDialog extends StatelessWidget {
  final GraphNode node;

  const StructureMaintenanceEventDialog({super.key, required this.node});

  static Future<StructureMaintenanceEvent?> show(
    BuildContext context, {
    required GraphNode node,
    StructureMaintenanceEvent? existingEvent,
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

    // Resolve site environment for filtering maintenance types
    final siteEnvironment = _resolveSiteEnvironment(node);

    return showDialog<StructureMaintenanceEvent>(
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
          create: (_) => StructureMaintenanceEventCubit(
            node: node,
            eventRepository: eventRepository,
            imageService: imageService,
            existingEvent: existingEvent,
            siteEnvironment: siteEnvironment,
            offlineHandler: offlineHandler,
          )..initializeCameraPermission(),
          child: StructureMaintenanceEventDialog(node: node),
        ),
      ),
    );
  }

  /// Resolve the site environment from the node
  static SiteEnvironment? _resolveSiteEnvironment(GraphNode node) {
    final siteNode = node.siteNode;
    if (siteNode == null) return null;
    final state = siteNode.state;
    if (state is GraphLoadedState<Site>) {
      return state.record.siteType.environment;
    }
    return siteNode.initialRecord.siteType.environment;
  }

  @override
  Widget build(BuildContext context) {
    return _StructureMaintenanceEventDialogContent(node: node);
  }
}

class _StructureMaintenanceEventDialogContent extends StatefulWidget {
  final GraphNode node;

  const _StructureMaintenanceEventDialogContent({required this.node});

  @override
  State<_StructureMaintenanceEventDialogContent> createState() =>
      _StructureMaintenanceEventDialogContentState();
}

class _StructureMaintenanceEventDialogContentState
    extends State<_StructureMaintenanceEventDialogContent>
    with SafeDialogMixin<_StructureMaintenanceEventDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _durationController;
  late final TextEditingController _equipmentController;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<StructureMaintenanceEventCubit>();

    // Initialize controllers with current state
    _durationController = TextEditingController(text: cubit.state.duration);
    _equipmentController = TextEditingController(text: cubit.state.equipment);
    _commentController = TextEditingController(text: cubit.state.comment);

    // Listen to controller changes and update cubit
    _durationController.addListener(() {
      cubit.updateDuration(_durationController.text);
    });
    _equipmentController.addListener(() {
      cubit.updateEquipment(_equipmentController.text);
    });
    _commentController.addListener(() {
      cubit.updateComment(_commentController.text);
    });
  }

  @override
  void dispose() {
    _durationController.dispose();
    _equipmentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<StructureMaintenanceEventCubit>();
    final result = await cubit.submit();

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
      StructureMaintenanceEventCubit,
      StructureMaintenanceEventState
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
        final cubit = context.read<StructureMaintenanceEventCubit>();

        return AlertDialog(
          title: const Text('Structure Maintenance'),
          content: Form(
            key: _formKey,
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Maintenance Type Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: state.maintenanceTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Maintenance Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _getApplicableMaintenanceTypes().map((type) {
                      return DropdownMenuItem(
                        value: type.id,
                        child: Text(type.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        cubit.updateMaintenanceType(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Equipment Name
                  TextFormField(
                    controller: _equipmentController,
                    decoration: const InputDecoration(
                      labelText: 'Equipment/Structure Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Duration
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Resolved Checkbox
                  CheckboxListTile(
                    title: const Text('Issue Resolved'),
                    value: state.resolved,
                    onChanged: (value) {
                      cubit.updateResolved(value ?? true);
                    },
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

                  // Image Preview
                  if (state.imagePath != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photo:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(state.imagePath!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                color: Colors.white,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                onPressed: () => cubit.removeImage(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  // Camera Button
                  if (state.imagePath == null)
                    CameraPermissionControls(
                      permissionStatus: state.cameraStatus,
                      isBusy: state.isCapturingImage || state.isSubmitting,
                      enabled: !state.isSubmitting,
                      onCapture: cubit.captureImage,
                      onRequestPermission: cubit.requestCameraPermission,
                      onOpenSettings: openAppSettings,
                    ),
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

  Widget _buildPermitSection(StructureMaintenanceEventState state) {
    final cubit = context.read<StructureMaintenanceEventCubit>();
    final site = _resolveActiveSite();
    final supportsPermits = PermitMetadataPolicy.siteSupportsPermits(site);
    final siteName = site?.name ?? 'this site';
    final fieldsEnabled = !state.isSubmitting;
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

  /// Get maintenance types applicable to the current site environment
  List<StructureMaintenanceType> _getApplicableMaintenanceTypes() {
    final site = _resolveActiveSite();
    if (site == null) {
      // Default to all types if site is unknown
      return StructureMaintenanceType.values;
    }
    final environment = site.siteType.environment;
    return StructureMaintenanceType.valuesFor(environment);
  }
}