// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/move_node/move_node.dart';
import 'package:seafoundry_app/constants/schema.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/utils/permit_metadata_policy.dart';
import 'package:seafoundry_app/widgets/components/structure_capacity_banner.dart';
import 'package:seafoundry_app/widgets/dialogs/components/permit_selector_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/new_parent_selector.dart';
import 'package:seafoundry_app/widgets/partial_move_selector.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_primary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_text_form_field.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class MoveNodeDialog extends StatelessWidget {
  final GraphNode nodeToMove;
  final String? userId;
  final bool isPro;

  const MoveNodeDialog({
    super.key,
    required this.nodeToMove,
    this.userId,
    this.isPro = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required GraphNode nodeToMove,
  }) {
    final graphRepository = _resolveGraphRepository(context, nodeToMove);

    if (nodeToMove.parent == null) {
      return _showMoveRestrictionDialog(
        context,
        'This node cannot be moved because it has no parent in the graph hierarchy.',
      );
    }

    if (graphRepository == null) {
      return _showMoveRestrictionDialog(
        context,
        'Move requires the graph workspace. Open the Graph view (org → nursery → structure → coral) and launch Move from there.',
      );
    }

    // Capture userId and isPro from CurrentUser for permit creation
    final currentUserState = context.read<CurrentUser>().state;
    final userId = currentUserState is CurrentUserLoaded
        ? currentUserState.user.id
        : null;
    final isPro =
        currentUserState is CurrentUserLoaded &&
        currentUserState.organization.tier.index >= Tier.pro.index;

    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider(
        create: (_) =>
            MoveNode(graphRepository: graphRepository)..start(nodeToMove),
        child: MoveNodeDialog(
          nodeToMove: nodeToMove,
          userId: userId,
          isPro: isPro,
        ),
      ),
    );
  }

  static Future<bool?> _showMoveRestrictionDialog(
    BuildContext context,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move unavailable'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => popSafeDialogContext(context, false),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  static GraphRepository? _resolveGraphRepository(
    BuildContext context,
    GraphNode nodeToMove,
  ) {
    try {
      return context.read<GraphRepository>();
    } catch (_) {
      return _graphRepositoryFromNode(nodeToMove);
    }
  }

  static GraphRepository? _graphRepositoryFromNode(GraphNode node) {
    try {
      // ignore: invalid_use_of_protected_member
      return node.graphRepository;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MoveNode, MoveNodeState>(
      listener: (context, state) {
        if (state is MoveNodeSuccess && context.mounted) {
          popSafeDialogContext(context, true);
        }
      },
      builder: (context, state) {
        final titleData = _getTitleData(state);
        return OceanicDialog(
          title: titleData.title,
          icon: titleData.icon,
          iconColor: titleData.iconColor,
          content: _buildContent(context, state),
          actions: _buildActions(context, state),
        );
      },
    );
  }

  ({String title, IconData? icon, Color? iconColor}) _getTitleData(
    MoveNodeState state,
  ) {
    if (state is MoveNodeMoving) {
      return (
        title: 'Moving ${state.nodeToMove.initialRecord.name}...',
        icon: Icons.sync,
        iconColor: AppColors.primary,
      );
    }

    if (state is MoveNodeConfirmation) {
      return (
        title: 'Confirm Move',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.warning,
      );
    }

    if (state is MoveNodeSelection) {
      return (
        title: 'Move ${state.nodeToMove.initialRecord.name}',
        icon: Icons.drive_file_move_rounded,
        iconColor: AppColors.primary,
      );
    }

    return (title: 'Move Node', icon: null, iconColor: null);
  }

  Widget _buildContent(BuildContext context, MoveNodeState state) {
    if (state is MoveNodeError) {
      return SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(state.error),
          ],
        ),
      );
    }

    if (state is MoveNodeMoving) {
      return const SizedBox(
        width: 400,
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state is MoveNodeConfirmation) {
      return _buildConfirmationContent(context, state);
    }

    if (state is MoveNodeSelection) {
      return _buildSelectionContent(context, state);
    }

    return const SizedBox(
      width: 400,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSelectionContent(BuildContext context, MoveNodeSelection state) {
    final reasonError = state.moveReason.trim().isEmpty
        ? 'Reason is required'
        : null;
    return SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Partial move selector
          PartialMoveSelector(
            nodeToMove: state.nodeToMove,
            initialSelection: state.partialSelection,
            onSelectionChanged: (selection) {
              context.read<MoveNode>().updatePartialSelection(selection);
            },
          ),
          const SizedBox(height: 20),

          UIText.bodyMedium('Select a new parent location:'),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.disabled.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current: ${state.nodeToMove.parent?.initialRecord.name ?? "Unknown"}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.disabled.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: NewParentSelector(
              nodeToMove: state.nodeToMove,
              selectedParent: state.selectedParent,
              organizationNode: nodeToMove.organizationNode,
              onParentSelected: (parent) {
                context.read<MoveNode>().selectParent(parent);
              },
            ),
          ),
          StructureCapacityBanner(
            result: state.capacityResult,
            isLoading: state.isCapacityCheckInProgress,
            margin: const EdgeInsets.only(top: 12),
          ),

          const SizedBox(height: 16),
          OceanicTextFormField(
            label: 'Reason',
            hint: moveReasonCorrection,
            initialValue: state.moveReason,
            errorText: reasonError,
            onChanged: (value) {
              context.read<MoveNode>().updateMoveReason(value);
            },
          ),
          const SizedBox(height: 8),
          UIText.bodySmall(
            'Use "${moveReasonCorrection.toLowerCase()}" when fixing mis-entered inventory data.',
            color: AppColors.textSecondary,
          ),

          if (state.selectedParent != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New parent: ${state.selectedParent!.initialRecord.name}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartialMoveInfo(
    BuildContext context,
    MoveNodeConfirmation state,
  ) {
    final nodeId = state.nodeToMove.id;
    final partialQuantity = state.partialSelection.partialQuantities[nodeId];

    // Check if this is an organism node with partial quantity
    if (partialQuantity != null && state.nodeToMove is OrganismNode) {
      final nodeState = state.nodeToMove.state;
      if (nodeState is GraphLoadedState<OrganismRecord>) {
        final organism = nodeState.record;
        return Text(
          'Moving: $partialQuantity of ${organism.measurement.value.toInt()} ${organism.name}',
          style: TextStyle(fontSize: 13, color: Theme.of(context).primaryColor),
        );
      }
    }

    // OrganismNode partial quantity support (no legacy CoralNode needed)

    // Otherwise show selected children count
    final selectedCount = state.partialSelection.selectedChildIds.length;
    return Text(
      'Moving: $selectedCount selected item${selectedCount == 1 ? '' : 's'}',
      style: TextStyle(fontSize: 13, color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildConfirmationContent(
    BuildContext context,
    MoveNodeConfirmation state,
  ) {
    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIText.bodyMedium(
            'Are you sure you want to move this ${state.nodeToMove.modelType.name}?',
          ),
          const SizedBox(height: 16),

          StructureCapacityBanner(result: state.capacityResult),
          if (state.capacityResult?.isOverCapacity == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: UIText.bodySmall(
                'Resolve the capacity issue to continue.',
                color: AppColors.error,
              ),
            ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.nodeToMove.initialRecord.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (!state.partialSelection.moveAll) ...[
                  const SizedBox(height: 8),
                  _buildPartialMoveInfo(context, state),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('From: '),
                    Text(
                      state.nodeToMove.parent?.initialRecord.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('To: '),
                    Text(
                      state.selectedParent.initialRecord.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Reason: '),
                    Text(
                      state.moveReason,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _buildPermitSection(context, state),
        ],
      ),
    );
  }

  Widget _buildPermitSection(BuildContext context, MoveNodeConfirmation state) {
    final moveNodeBloc = context.read<MoveNode>();
    final site =
        _resolveSiteForNode(state.selectedParent) ??
        _resolveSiteForNode(state.nodeToMove);
    final supportsPermits = PermitMetadataPolicy.siteSupportsPermits(site);

    final isMoving = moveNodeBloc.state is MoveNodeMoving;
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
                  site == null
                      ? 'Permit metadata is disabled for this move.'
                      : 'Permit metadata is disabled for ${site.name}.',
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
          enabled: !isMoving,
          displayOptions: PermitSelectorDisplayOptions.compact,
          onPermitSelected: (permit) {
            if (permit == null) {
              moveNodeBloc
                ..updatePermitId('')
                ..updatePermitType('')
                ..updateIssuingAuthority('')
                ..updatePermitAttachmentUrls('')
                ..updatePermitValidFrom(null)
                ..updatePermitValidTo(null);
            } else {
              moveNodeBloc
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

  Site? _resolveSiteForNode(GraphNode node) {
    final siteNode = node.siteNode;
    if (siteNode != null) {
      final siteState = siteNode.state;
      if (siteState is GraphLoadedState<Site>) {
        return siteState.record;
      }
      final Site initial = siteNode.initialRecord;
      return initial;
    }
    final initialRecord = node.initialRecord;
    if (initialRecord is Site) {
      return initialRecord;
    }
    return null;
  }

  List<Widget> _buildActions(BuildContext context, MoveNodeState state) {
    if (state is MoveNodeError) {
      return [
        OceanicSecondaryButton(
          onPressed: () => popSafeDialogContext(context, false),
          label: 'Close',
        ),
      ];
    }

    if (state is MoveNodeMoving) {
      return [];
    }

    if (state is MoveNodeConfirmation) {
      return [
        OceanicSecondaryButton(
          onPressed: () {
            context.read<MoveNode>().back();
          },
          label: 'Back',
        ),
        OceanicPrimaryButton(
          onPressed: state.capacityResult?.isOverCapacity == true
              ? null
              : () {
                  context.read<MoveNode>().execute();
                },
          label: 'Confirm Move',
        ),
      ];
    }

    if (state is MoveNodeSelection) {
      return [
        OceanicSecondaryButton(
          onPressed: () => popSafeDialogContext(context, false),
          label: 'Cancel',
        ),
        OceanicPrimaryButton(
          onPressed: state.canProceed
              ? () {
                  context.read<MoveNode>().confirm();
                }
              : null,
          label: 'Next',
        ),
      ];
    }

    return [
      OceanicSecondaryButton(
        onPressed: () => popSafeDialogContext(context, false),
        label: 'Cancel',
      ),
    ];
  }
}
