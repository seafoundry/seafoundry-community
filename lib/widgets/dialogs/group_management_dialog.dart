// @tier: community
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/group_removal/group_removal_cubit.dart';
import 'package:seafoundry_app/cubits/group_removal/group_removal_state.dart';
import 'package:seafoundry_app/cubits/structure_edit_name/structure_edit_name_cubit.dart';
import 'package:seafoundry_app/cubits/structure_edit_name/structure_edit_name_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/components/dialog_message_box.dart';
import 'components/dialog_scroll_view.dart';

/// Mode for group management operations
enum GroupManagementMode {
  /// Edit the group's name with uniqueness validation
  editName,

  /// Remove/delete group with validation
  remove,
}

/// Result describing group management dialog outcomes
class GroupManagementResult {
  const GroupManagementResult({
    this.updatedGroup,
    this.deletedGroupId,
  });

  /// The group that was modified in-place (rename)
  final Group? updatedGroup;

  /// ID of group that was deleted
  final String? deletedGroupId;

  bool get hasChanges => updatedGroup != null || deletedGroupId != null;
}

/// Unified dialog for group management operations
///
/// This dialog consolidates group management operations (edit name, remove)
/// into a single entry point. This architecture allows for future expansion.
///
/// **Architecture**:
/// - Uses StructureEditNameCubit for editName mode
/// - Uses GroupRemovalCubit for remove mode
/// - StatefulWidget wrappers required for TextEditingController lifecycle
/// - Follows same pattern as GenetManagementDialog for consistency
///
/// Usage:
/// ```dart
/// // Edit group name
/// final result = await GroupManagementDialog.show(
///   context,
///   mode: GroupManagementMode.editName,
///   group: myGroup,
///   parentSite: site,
/// );
/// final updatedGroup = result?.updatedGroup;
/// ```
class GroupManagementDialog {
  GroupManagementDialog._();

  /// Show the group management dialog
  ///
  /// [mode] determines the operation (editName or remove)
  /// [group] is the group record to manage
  /// [parentSite] is the site containing this group (required for name validation)
  /// [onUpdated] optional callback when group is successfully updated
  ///
  /// Returns a [GroupManagementResult] describing updates or deletion.
  /// Null when the dialog is dismissed without changes.
  static Future<GroupManagementResult?> show(
    BuildContext context, {
    required GroupManagementMode mode,
    required Group group,
    required Site parentSite,
    VoidCallback? onUpdated,
  }) async {
    // Capture providers before showing dialog - dialog context doesn't inherit providers
    final firestore = context.read<FirebaseService>().firestore;
    final groupRepository = context.read<GroupRepository>();

    switch (mode) {
      case GroupManagementMode.editName:
        final providers = [
          RepositoryProvider<GroupRepository>.value(value: groupRepository),
        ];
        return showDialog<GroupManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return MultiRepositoryProvider(
              providers: providers,
              child: BlocProvider(
                create: (_) => StructureEditNameCubit(
                  initialName: group.name,
                  firestore: firestore,
                ),
                child: _GroupEditNameDialog(
                  group: group,
                  parentSite: parentSite,
                  onUpdated: onUpdated,
                ),
              ),
            );
          },
        );

      case GroupManagementMode.remove:
        final organismRepository = context.read<OrganismRecordRepository>();
        final providers = [
          RepositoryProvider<GroupRepository>.value(value: groupRepository),
          RepositoryProvider<OrganismRecordRepository>.value(
            value: organismRepository,
          ),
        ];
        return showDialog<GroupManagementResult>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) {
            return MultiRepositoryProvider(
              providers: providers,
              child: BlocProvider(
                create: (_) => GroupRemovalCubit(),
                child: _GroupRemovalDialog(
                  group: group,
                  onUpdated: onUpdated,
                ),
              ),
            );
          },
        );
    }
  }
}

/// Edit name dialog implementation
class _GroupEditNameDialog extends StatelessWidget {
  const _GroupEditNameDialog({
    required this.group,
    required this.parentSite,
    this.onUpdated,
  });

  final Group group;
  final Site parentSite;
  final VoidCallback? onUpdated;

  @override
  Widget build(BuildContext context) {
    return _GroupEditNameDialogContent(
      group: group,
      parentSite: parentSite,
      onUpdated: onUpdated,
    );
  }
}

class _GroupEditNameDialogContent extends StatefulWidget {
  const _GroupEditNameDialogContent({
    required this.group,
    required this.parentSite,
    this.onUpdated,
  });

  final Group group;
  final Site parentSite;
  final VoidCallback? onUpdated;

  @override
  State<_GroupEditNameDialogContent> createState() =>
      _GroupEditNameDialogContentState();
}

class _GroupEditNameDialogContentState
    extends State<_GroupEditNameDialogContent>
    with SafeDialogMixin<_GroupEditNameDialogContent> {
  late final TextEditingController _nameController;
  bool _isUpdatingName = false;

  @override
  void initState() {
    super.initState();
    final cubitState = context.read<StructureEditNameCubit>().state;
    _nameController = TextEditingController(text: cubitState.name);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_isUpdatingName) return;
    context.read<StructureEditNameCubit>().nameChanged(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructureEditNameCubit, StructureEditNameState>(
      builder: (context, cubitState) {
        // Sync controller with cubit state if it changed externally
        if (_nameController.text != cubitState.name) {
          _isUpdatingName = true;
          _nameController.value = _nameController.value.copyWith(
            text: cubitState.name,
            selection: TextSelection.collapsed(offset: cubitState.name.length),
          );
          _isUpdatingName = false;
        }

        return AlertDialog(
          title: const Text('Edit Group Name'),
          content: DialogScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DialogMessageBox(
                  tone: DialogMessageTone.info,
                  child: Text(
                    'Editing the group name. Group names must be unique within the parent site.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  enabled: !cubitState.loading,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'Enter new name',
                    border: const OutlineInputBorder(),
                    errorText: cubitState.errorMessage,
                  ),
                  onSubmitted: (_) => _saveChanges(context),
                ),
                if (cubitState.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  DialogMessageBox(
                    tone: DialogMessageTone.error,
                    child: Text(
                      cubitState.errorMessage!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: cubitState.loading ? null : () => popDialog(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  cubitState.loading ? null : () => _saveChanges(context),
              child: cubitState.loading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveChanges(BuildContext context) async {
    if (!context.mounted) return;

    final cubit = context.read<StructureEditNameCubit>();
    final groupRepository = context.read<GroupRepository>();

    final success = await cubit.save(
      record: widget.group,
      site: widget.parentSite, // Group needs parent site for validation
      siteRepository: null,
      groupRepository: groupRepository,
      modelType: ModelType.group,
    );

    if (!context.mounted) return;

    if (success) {
      // Create updated group with new name
      final updatedGroup = widget.group.copyWith(name: cubit.state.name);

      widget.onUpdated?.call();

      popDialog(
        GroupManagementResult(updatedGroup: updatedGroup),
      );
      showDialogSnackBar(
        'Group renamed to "${cubit.state.name}"',
        isSuccess: true,
      );
    }
  }
}

/// Remove/delete group dialog implementation
class _GroupRemovalDialog extends StatelessWidget {
  const _GroupRemovalDialog({
    required this.group,
    this.onUpdated,
  });

  final Group group;
  final VoidCallback? onUpdated;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupRemovalCubit, GroupRemovalState>(
      builder: (context, _) {
        return _GroupRemovalDialogContent(
          group: group,
          onUpdated: onUpdated,
        );
      },
    );
  }
}

class _GroupRemovalDialogContent extends StatefulWidget {
  const _GroupRemovalDialogContent({
    required this.group,
    this.onUpdated,
  });

  final Group group;
  final VoidCallback? onUpdated;

  @override
  State<_GroupRemovalDialogContent> createState() =>
      _GroupRemovalDialogContentState();
}

class _GroupRemovalDialogContentState extends State<_GroupRemovalDialogContent>
    with SafeDialogMixin<_GroupRemovalDialogContent> {
  late final TextEditingController _commentController;
  bool _isUpdatingComment = false;

  @override
  void initState() {
    super.initState();
    final cubitState = context.read<GroupRemovalCubit>().state;
    _commentController = TextEditingController(text: cubitState.comment);
    _commentController.addListener(_onCommentChanged);
    _checkChildHoldings();
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    if (_isUpdatingComment) return;
    context.read<GroupRemovalCubit>().commentChanged(_commentController.text);
  }

  bool _isArchivedData(Map<String, dynamic> data) {
    if (data['archived'] == true || data['isDeleted'] == true) {
      return true;
    }
    final metadata = data['metadata'];
    if (metadata is Map) {
      return metadata['archived'] == true || metadata['isDeleted'] == true;
    }
    return false;
  }

  Future<void> _checkChildHoldings() async {
    try {
      final organismRepository = context.read<OrganismRecordRepository>();

      // Check for organisms in this group
      final organisms = await organismRepository.collectionRef
          .where('groupId', isEqualTo: widget.group.id)
          .get();

      if (mounted) {
        final hasActiveOrganisms = organisms.docs.any(
          (doc) => !_isArchivedData(doc.data()),
        );
        context
            .read<GroupRemovalCubit>()
            .setHasChildHoldings(hasActiveOrganisms);
      }
    } catch (e) {
      LoggingService.instance.error('Failed to check child holdings', e);
      if (mounted) {
        context.read<GroupRemovalCubit>().setError(
              'Failed to validate group: ${e.toString()}',
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupRemovalCubit, GroupRemovalState>(
      builder: (context, cubitState) {
        // Sync controller with cubit state if changed externally
        if (_commentController.text != cubitState.comment) {
          _isUpdatingComment = true;
          _commentController.value = _commentController.value.copyWith(
            text: cubitState.comment,
            selection: TextSelection.collapsed(
              offset: cubitState.comment.length,
            ),
          );
          _isUpdatingComment = false;
        }

        final canSubmit = cubitState.isValid && !cubitState.isSubmitting;

        return AlertDialog(
          title: const Text('Remove Group'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cubitState.error != null) ...[
                    DialogMessageBox(
                      tone: DialogMessageTone.error,
                      child: Text(
                        cubitState.error!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Group Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Type: ${widget.group.groupTypeId}'),
                          if (widget.group.description != null)
                            Text('Description: ${widget.group.description}'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Warning about deletion
                  const DialogMessageBox(
                    tone: DialogMessageTone.warning,
                    child: Text(
                      'This will permanently delete the group record. This action cannot be undone.',
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (cubitState.hasChildHoldings) ...[
                    const DialogMessageBox(
                      tone: DialogMessageTone.error,
                      child: Text(
                        'Cannot delete group with existing organisms. Please remove all holdings first.',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const DialogMessageBox(
                      tone: DialogMessageTone.info,
                      child: Text(
                        'Removal reason and comment will appear in the activity history.',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Removal Reason
                    const Text(
                      'Removal Reason',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<PopulationLossReason>(
                      initialValue: cubitState.selectedReason,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select reason',
                      ),
                      items: PopulationLossReason.nurseryLossReasons.map((
                        reason,
                      ) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason.name),
                        );
                      }).toList(),
                      onChanged: cubitState.isSubmitting
                          ? null
                          : (reason) {
                              context.read<GroupRemovalCubit>().reasonChanged(
                                reason,
                              );
                            },
                    ),

                    const SizedBox(height: 16),

                    // Comment
                    const Text(
                      'Comment (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      enabled: !cubitState.isSubmitting,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Additional notes...',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: cubitState.isSubmitting ? null : () => popDialog(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: canSubmit ? () => _submit(context) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: cubitState.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<GroupRemovalCubit>();
    final state = cubit.state;

    if (!cubit.validate()) {
      return;
    }

    cubit.setSubmitting(true);
    cubit.clearError();

    try {
      final groupRepo = context.read<GroupRepository>();

      // Delete the group (structures don't use archival pattern)
      await groupRepo.deleteRecord(widget.group);

      LoggingService.instance.info(
        'Deleted group ${widget.group.id} (${widget.group.name}): '
        'reason=${state.selectedReason!.name} comment=${state.comment.trim()}',
      );

      cubit.setSubmitting(false);
      if (!mounted) return;

      widget.onUpdated?.call();

      if (!context.mounted) return;
      popDialog(
        GroupManagementResult(deletedGroupId: widget.group.id),
      );
      showDialogSnackBar(
        'Group "${widget.group.name}" deleted successfully',
        isSuccess: true,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to delete group', e, stackTrace);
      if (mounted) {
        cubit.setError('Failed to delete group: ${e.toString()}');
      }
    }
  }
}