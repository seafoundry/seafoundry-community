// @tier: community
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/cubits/structure_edit_name/structure_edit_name_cubit.dart';
import 'package:seafoundry_app/cubits/structure_edit_name/structure_edit_name_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Dialog for editing structure names with uniqueness validation
class StructureEditNameDialog extends StatelessWidget {
  const StructureEditNameDialog._({
    required this.node,
    required this.record,
    required this.modelType,
  });

  final GraphNode node;
  final GraphNodeRecord record;
  final ModelType modelType;

  static Future<bool?> show(BuildContext context, {required GraphNode node}) {
    // Helper to safely get record from GraphNode state
    GraphNodeRecord getRecord() {
      final state = node.state;
      if (state is! GraphLoadedState) {
        throw StateError('Node must be loaded to edit name');
      }
      return state.record;
    }

    final record = getRecord();
    final modelType = record.modelType;

    // Capture providers before showing dialog - dialog context doesn't inherit providers
    final firestore = context.read<FirebaseService>().firestore;
    final siteRepository = modelType == ModelType.site
        ? context.read<SiteRepository>()
        : null;
    final groupRepository = modelType != ModelType.site
        ? context.read<GroupRepository>()
        : null;
    final providers = [
      if (siteRepository != null)
        RepositoryProvider<SiteRepository>.value(value: siteRepository),
      if (groupRepository != null)
        RepositoryProvider<GroupRepository>.value(value: groupRepository),
    ];

    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        return MultiRepositoryProvider(
          providers: providers,
          child: BlocProvider(
            create: (_) => StructureEditNameCubit(
              initialName: record.name,
              firestore: firestore,
            ),
            child: StructureEditNameDialog._(
              node: node,
              record: record,
              modelType: modelType,
            ),
          ),
        );
      },
    );
  }

  String _getTypeName() {
    if (node is SiteNode) return 'Site';
    if (node is GroupNode) return 'Structure';
    return 'Record';
  }

  @override
  Widget build(BuildContext context) {
    return _StructureEditNameDialogContent(
      node: node,
      record: record,
      modelType: modelType,
      typeName: _getTypeName(),
    );
  }
}

class _StructureEditNameDialogContent extends StatefulWidget {
  const _StructureEditNameDialogContent({
    required this.node,
    required this.record,
    required this.modelType,
    required this.typeName,
  });

  final GraphNode node;
  final GraphNodeRecord record;
  final ModelType modelType;
  final String typeName;

  @override
  State<_StructureEditNameDialogContent> createState() =>
      _StructureEditNameDialogContentState();
}

class _StructureEditNameDialogContentState
    extends State<_StructureEditNameDialogContent>
    with SafeDialogMixin<_StructureEditNameDialogContent> {
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
          title: Text('Edit ${widget.typeName} Name'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a new name for "${widget.record.name}"',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: const OutlineInputBorder(),
                    errorText: cubitState.errorMessage,
                    errorMaxLines: 3,
                  ),
                  autofocus: true,
                  enabled: !cubitState.loading,
                  onSubmitted: (_) => _saveChanges(context),
                ),
                if (cubitState.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cubitState.errorMessage!,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: cubitState.loading ? null : () => popDialog(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: cubitState.loading
                  ? null
                  : () => _saveChanges(context),
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
    final site = _findAncestorSite();
    final siteRepository = widget.modelType == ModelType.site
        ? context.read<SiteRepository>()
        : null;
    final groupRepository = widget.modelType != ModelType.site
        ? context.read<GroupRepository>()
        : null;

    final cubit = context.read<StructureEditNameCubit>();

    final success = await cubit.save(
      record: widget.record,
      site: site,
      siteRepository: siteRepository,
      groupRepository: groupRepository,
      modelType: widget.modelType,
    );

    if (success && context.mounted) {
      if (!widget.node.isClosed) {
        widget.node.add(const GraphNodeReloadRequested());
      }

      popDialog(true);
      showDialogSnackBar(
        '${widget.typeName} renamed to "${cubit.state.name}"',
        isSuccess: true,
      );
    }
  }

  Site? _findAncestorSite() {
    GraphNode? current = widget.node;

    while (current != null) {
      if (current is SiteNode) {
        final state = current.state;
        if (state is GraphLoadedState<Site>) {
          return state.record;
        }
      }
      current = current.parent;
    }

    return null;
  }
}
