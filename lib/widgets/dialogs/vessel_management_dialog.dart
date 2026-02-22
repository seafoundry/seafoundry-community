// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/vessel/vessel_cubit.dart';
import 'package:seafoundry_app/cubits/vessel/vessel_state.dart';
import 'package:seafoundry_app/models/operations/vessel.dart';
import 'package:seafoundry_app/repositories/vessel_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/components/dialog_message_box.dart';
import '../notifications/toast_overlay.dart';
import 'components/dialog_scroll_view.dart';

/// Mode for vessel management operations
enum VesselManagementMode {
  /// Create a new vessel
  create,

  /// Edit an existing vessel
  edit,

  /// Remove/delete a vessel
  remove,
}

/// Result describing vessel management dialog outcomes
class VesselManagementResult {
  const VesselManagementResult({
    this.createdVessel,
    this.updatedVessel,
    this.deletedVesselId,
  });

  /// The vessel that was created
  final Vessel? createdVessel;

  /// The vessel that was updated
  final Vessel? updatedVessel;

  /// ID of vessel that was deleted
  final String? deletedVesselId;

  bool get hasChanges =>
      createdVessel != null || updatedVessel != null || deletedVesselId != null;
}

/// Unified dialog for vessel management operations
///
/// This dialog consolidates vessel management operations (create, edit, remove)
/// into a single entry point following the ManagementDialog pattern.
///
/// Usage:
/// ```dart
/// // Create new vessel
/// final result = await VesselManagementDialog.show(
///   context,
///   mode: VesselManagementMode.create,
///   organizationId: orgId,
///   userId: currentUser.id,
/// );
///
/// // Edit existing vessel
/// final result = await VesselManagementDialog.show(
///   context,
///   mode: VesselManagementMode.edit,
///   vessel: existingVessel,
///   organizationId: orgId,
///   userId: currentUser.id,
/// );
/// ```
class VesselManagementDialog {
  VesselManagementDialog._();

  /// Show the vessel management dialog
  ///
  /// [mode] determines the operation (create, edit, or remove)
  /// [organizationId] is required for all operations
  /// [vessel] is required for edit and remove operations
  /// [onUpdated] optional callback when vessel is successfully updated
  /// [userId] is required for auditing create/update operations
  ///
  /// Returns a [VesselManagementResult] describing updates or deletion.
  /// Null when the dialog is dismissed without changes.
  static Future<VesselManagementResult?> show(
    BuildContext context, {
    required VesselManagementMode mode,
    required String organizationId,
    required String userId,
    Vessel? vessel,
    VoidCallback? onUpdated,
  }) async {
    if (mode != VesselManagementMode.create && vessel == null) {
      throw ArgumentError('vessel is required for edit and remove modes');
    }

    // Capture repository before showing dialog - dialog context doesn't inherit providers
    final repository = context.read<VesselRepository>();

    switch (mode) {
      case VesselManagementMode.create:
        return showDialog<VesselManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return BlocProvider(
              create: (_) => VesselCubit(
                repository: repository,
                organizationId: organizationId,
              ),
              child: _VesselCreateEditDialog(
                userId: userId,
                organizationId: organizationId,
                isEdit: false,
                onUpdated: onUpdated,
              ),
            );
          },
        );

      case VesselManagementMode.edit:
        return showDialog<VesselManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return BlocProvider(
              create: (_) => VesselCubit(
                repository: repository,
                organizationId: organizationId,
              ),
              child: _VesselCreateEditDialog(
                vessel: vessel,
                userId: userId,
                organizationId: organizationId,
                isEdit: true,
                onUpdated: onUpdated,
              ),
            );
          },
        );

      case VesselManagementMode.remove:
        return showDialog<VesselManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return BlocProvider(
              create: (_) => VesselCubit(
                repository: repository,
                organizationId: organizationId,
              ),
              child: _VesselRemoveDialog(vessel: vessel!, onUpdated: onUpdated),
            );
          },
        );
    }
  }
}

/// Dialog for creating or editing a vessel
class _VesselCreateEditDialog extends StatefulWidget {
  final Vessel? vessel;
  final String organizationId;
  final String userId;
  final bool isEdit;
  final VoidCallback? onUpdated;

  const _VesselCreateEditDialog({
    this.vessel,
    required this.organizationId,
    required this.userId,
    required this.isEdit,
    this.onUpdated,
  });

  @override
  State<_VesselCreateEditDialog> createState() =>
      _VesselCreateEditDialogState();
}

class _VesselCreateEditDialogState extends State<_VesselCreateEditDialog>
    with SafeDialogMixin<_VesselCreateEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _registrationController;
  late TextEditingController _crewCapacityController;
  late TextEditingController _maxSpeedController;
  late TextEditingController _fuelCapacityController;
  late TextEditingController _rangeController;
  late TextEditingController _homePortController;
  late TextEditingController _capabilitiesController;
  late VesselStatus _status;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vessel?.name ?? '');
    _registrationController = TextEditingController(
      text: widget.vessel?.registrationNumber ?? '',
    );
    _crewCapacityController = TextEditingController(
      text: widget.vessel != null ? widget.vessel!.crewCapacity.toString() : '',
    );
    _maxSpeedController = TextEditingController(
      text: widget.vessel != null
          ? widget.vessel!.maxSpeedKnots.toString()
          : '',
    );
    _fuelCapacityController = TextEditingController(
      text: widget.vessel != null
          ? widget.vessel!.fuelCapacityGallons.toString()
          : '',
    );
    _rangeController = TextEditingController(
      text: widget.vessel != null
          ? widget.vessel!.rangeNauticalMiles.toString()
          : '',
    );
    _homePortController = TextEditingController(
      text: widget.vessel?.homePortSiteId ?? '',
    );
    _capabilitiesController = TextEditingController(
      text: widget.vessel?.capabilities.join(', ') ?? '',
    );
    _status = widget.vessel?.status ?? VesselStatus.available;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _crewCapacityController.dispose();
    _maxSpeedController.dispose();
    _fuelCapacityController.dispose();
    _rangeController.dispose();
    _homePortController.dispose();
    _capabilitiesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<VesselCubit>();
    final name = _nameController.text.trim();
    final registration = _registrationController.text.trim();
    final crewCapacity = int.tryParse(_crewCapacityController.text) ?? 0;
    final maxSpeed = double.tryParse(_maxSpeedController.text) ?? 0.0;
    final fuelCapacity = double.tryParse(_fuelCapacityController.text) ?? 0.0;
    final range = double.tryParse(_rangeController.text) ?? 0.0;
    final homePortSiteId = _homePortController.text.trim().isEmpty
        ? null
        : _homePortController.text.trim();
    final capabilities = _capabilitiesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (name.isEmpty) {
      ToastOverlay.showSnackBar(
        context,
        const SnackBar(content: Text('Vessel name is required')),
      );
      return;
    }

    if (registration.isEmpty) {
      ToastOverlay.showSnackBar(context,
        const SnackBar(content: Text('Registration number is required')),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();
    final createdBy = widget.vessel?.createdById ?? widget.userId;
    final createdAt = widget.vessel?.createdAt ?? now;
    final generatedId =
        widget.vessel?.id ??
        FirestoreCollectionResolver.instance.generateId(
          context.read<FirebaseService>().firestore,
        );

    final vessel = Vessel(
      id: generatedId,
      name: name,
      registrationNumber: registration,
      crewCapacity: crewCapacity,
      maxSpeedKnots: maxSpeed,
      homePortSiteId: homePortSiteId,
      capabilities: capabilities,
      fuelCapacityGallons: fuelCapacity,
      rangeNauticalMiles: range,
      status: _status,
      organizationId: widget.organizationId,
      createdAt: createdAt,
      createdById: createdBy,
      updatedAt: now,
      updatedById: widget.userId,
    );

    bool success;
    if (widget.isEdit) {
      success = await cubit.updateVessel(vessel);
    } else {
      success = await cubit.createVessel(vessel);
    }

    if (success && mounted) {
      widget.onUpdated?.call();
      popDialog(
        VesselManagementResult(
          createdVessel: widget.isEdit ? null : vessel,
          updatedVessel: widget.isEdit ? vessel : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VesselCubit, VesselState>(
      builder: (context, state) {
        return AlertDialog(
          title: Text(widget.isEdit ? 'Edit Vessel' : 'Create Vessel'),
          content: DialogScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.errorMessage != null)
                  DialogMessageBox.error(state.errorMessage!),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Vessel Name *'),
                  enabled: !state.loading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _registrationController,
                  decoration: const InputDecoration(
                    labelText: 'Registration Number *',
                  ),
                  enabled: !state.loading,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<VesselStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: VesselStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: state.loading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _status = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _homePortController,
                  decoration: const InputDecoration(
                    labelText: 'Home Port Site ID',
                    helperText: 'Optional: site ID for home port',
                  ),
                  enabled: !state.loading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _crewCapacityController,
                  decoration: const InputDecoration(labelText: 'Crew Capacity'),
                  keyboardType: TextInputType.number,
                  enabled: !state.loading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maxSpeedController,
                  decoration: const InputDecoration(
                    labelText: 'Max Speed (knots)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !state.loading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _fuelCapacityController,
                  decoration: const InputDecoration(
                    labelText: 'Fuel Capacity (gallons)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !state.loading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rangeController,
                  decoration: const InputDecoration(
                    labelText: 'Range (nautical miles)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !state.loading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _capabilitiesController,
                  decoration: const InputDecoration(
                    labelText: 'Capabilities',
                    helperText: 'Comma separated (e.g., diving, towing)',
                  ),
                  enabled: !state.loading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.loading
                  ? null
                  : () => popDialog(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: state.loading ? null : _save,
              child: state.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEdit ? 'Save' : 'Create'),
            ),
          ],
        );
      },
    );
  }
}

/// Dialog for removing a vessel
class _VesselRemoveDialog extends StatelessWidget {
  final Vessel vessel;
  final VoidCallback? onUpdated;

  const _VesselRemoveDialog({required this.vessel, this.onUpdated});

  Future<void> _confirmRemove(BuildContext context) async {
    final cubit = context.read<VesselCubit>();
    final success = await cubit.deleteVessel(vessel.id);

    if (success && context.mounted) {
      onUpdated?.call();
      if (context.mounted) {
        popSafeDialogContext(
          context,
          VesselManagementResult(deletedVesselId: vessel.id),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VesselCubit, VesselState>(
      builder: (context, state) {
        return AlertDialog(
          title: const Text('Remove Vessel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.errorMessage != null)
                DialogMessageBox.error(state.errorMessage!),
              Text('Are you sure you want to remove "${vessel.name}"?'),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: state.loading
                  ? null
                  : () => popSafeDialogContext(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: state.loading ? null : () => _confirmRemove(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: state.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}
