// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/models.dart' show Organization, Site;
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/outplant/outplant_submission_service.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_archive_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_creation_wizard/organism_creation_wizard.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_merge_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_movement_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_split_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/quantity_change_dialog.dart'
    hide GraphNodeReloadRequested;
import 'package:seafoundry_app/widgets/dialogs/structure_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/genetics/genetics_transfer_coordinator.dart';

/// Bottom sheet presenting context-appropriate inventory actions for a graph node.
class InventoryActionSheet {
  InventoryActionSheet._();

  static void show(BuildContext context, {required GraphNode node}) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => _InventoryActionList(
        node: node,
        parentContext: context,
      ),
    );
  }
}

class _InventoryActionList extends StatelessWidget {
  const _InventoryActionList({
    required this.node,
    required this.parentContext,
  });

  final GraphNode node;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined),
                const SizedBox(width: 8),
                Text(
                  'Inventory Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...actions,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    switch (node.modelType) {
      case ModelType.organization:
        return [
          _actionTile(
            context,
            icon: Icons.add_business,
            label: 'Add Site',
            onTap: () {
              Navigator.pop(context);
              StructureDialog.show(parentContext, type: StructureType.site);
            },
          ),
          _actionTile(
            context,
            icon: Icons.outbox,
            label: 'Send Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.sendTransfer(
                context: parentContext,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.input_rounded,
            label: 'Receive Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.receiveTransfer(
                context: parentContext,
              );
            },
          ),
        ];

      case ModelType.site:
        final siteNode = node as SiteNode;
        final siteId = siteNode.currentRecord.id;
        return [
          _actionTile(
            context,
            icon: Icons.grid_view,
            label: 'Add Structure',
            onTap: () {
              Navigator.pop(context);
              StructureDialog.show(
                parentContext,
                type: StructureType.group,
                parentNode: node,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.add_circle_outline,
            label: 'Add Organism',
            onTap: () {
              Navigator.pop(context);
              OrganismCreationWizard.showAndCreate(parentContext, siteId: siteId);
            },
          ),
          _actionTile(
            context,
            icon: Icons.outbox,
            label: 'Send Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.sendTransfer(
                context: parentContext,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.input_rounded,
            label: 'Receive Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.receiveTransfer(
                context: parentContext,
              );
            },
          ),
        ];

      case ModelType.group:
        final groupNode = node as GroupNode;
        final group = groupNode.currentRecord;
        return [
          _actionTile(
            context,
            icon: Icons.grid_view,
            label: 'Add Sub-structure',
            onTap: () {
              Navigator.pop(context);
              StructureDialog.show(
                parentContext,
                type: StructureType.group,
                parentNode: node,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.add_circle_outline,
            label: 'Add Organism',
            onTap: () {
              Navigator.pop(context);
              OrganismCreationWizard.showAndCreate(
                parentContext,
                siteId: group.siteId,
                groupId: group.id,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.move_down,
            label: 'Move Organisms',
            onTap: () {
              Navigator.pop(context);
              OrganismMovementDialog.show(parentContext, sourceGroupNode: groupNode);
            },
          ),
          _actionTile(
            context,
            icon: Icons.merge,
            label: 'Merge Organisms',
            onTap: () {
              Navigator.pop(context);
              OrganismMergeDialog.show(parentContext, groupNode: groupNode);
            },
          ),
          _actionTile(
            context,
            icon: Icons.outbox,
            label: 'Send Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.sendTransfer(
                context: parentContext,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.input_rounded,
            label: 'Receive Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.receiveTransfer(
                context: parentContext,
              );
            },
          ),
        ];

      case ModelType.organismRecord:
        final organismNode = node as OrganismNode;
        final organism = organismNode.currentRecord;
        final parentGroup = organismNode.parent is GroupNode
            ? organismNode.parent! as GroupNode
            : null;
        return [
          _actionTile(
            context,
            icon: Icons.numbers,
            label: 'Change Quantity',
            onTap: () {
              Navigator.pop(context);
              QuantityChangeDialog.show(
                parentContext,
                organism: organism,
                organismNode: organismNode,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.call_split,
            label: 'Split',
            onTap: () async {
              Navigator.pop(context);
              final newRecord = await OrganismSplitDialog.show(
                parentContext,
                organismNode: organismNode,
              );
              if (newRecord != null &&
                  parentGroup == null &&
                  parentContext.mounted) {
                await _showDestinationPicker(
                  parentContext,
                  record: newRecord,
                  actionLabel: 'split record',
                );
              }
            },
          ),
          _actionTile(
            context,
            icon: Icons.drive_file_move_outline,
            label: 'Move',
            onTap: () {
              Navigator.pop(context);
              if (parentGroup != null) {
                OrganismMovementDialog.show(
                  parentContext,
                  sourceGroupNode: parentGroup,
                  allowedOrganismIds: {organism.id},
                  initialSelectedOrganismIds: {organism.id},
                );
              } else {
                _showSiteLevelMoveDialog(parentContext, organismNode);
              }
            },
          ),
          _actionTile(
            context,
            icon: Icons.nature,
            label: 'Outplant',
            onTap: () async {
              Navigator.pop(context);
              await _showOutplantDialog(parentContext, organismNode);
            },
          ),
          if (parentGroup != null)
            _actionTile(
              context,
              icon: Icons.merge,
              label: 'Merge',
              onTap: () {
                Navigator.pop(context);
                OrganismMergeDialog.show(
                  parentContext,
                  groupNode: parentGroup,
                  filterLocalId: organism.localGenetId,
                );
              },
            ),
          _actionTile(
            context,
            icon: Icons.outbox,
            label: 'Send Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.sendTransfer(
                context: parentContext,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.input_rounded,
            label: 'Receive Transfer',
            onTap: () async {
              Navigator.pop(context);
              await GeneticsTransferCoordinator.receiveTransfer(
                context: parentContext,
              );
            },
          ),
          _actionTile(
            context,
            icon: Icons.archive_outlined,
            label: 'Archive',
            onTap: () {
              Navigator.pop(context);
              OrganismArchiveDialog.show(
                parentContext,
                organismNode: organismNode,
              );
            },
          ),
        ];

      default:
        return [];
    }
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

/// Move dialog for organisms directly under a site (no parent group).
///
/// Shows available groups under the same site and moves the organism
/// into the selected group.
Future<void> _showSiteLevelMoveDialog(
  BuildContext context,
  OrganismNode organismNode,
) async {
  final organism = organismNode.currentRecord;
  final siteId = organism.siteId;
  if (siteId == null) return;

  final groupRepository = context.read<GroupRepository>();
  final organismRepository = context.read<OrganismRecordRepository>();
  final graphRepository = context.read<GraphRepository>();
  final allGroups = await groupRepository.getAll();
  final siteGroups =
      allGroups.where((g) => g.siteId == siteId).toList();

  if (!context.mounted) return;

  if (siteGroups.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No structures available. Create a structure first.'),
      ),
    );
    return;
  }

  final selectedGroup = await showDialog<Group>(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) => _TargetStructurePickerDialog(
      title: 'Move ${organism.name}',
      prompt: 'Select target structure:',
      availableGroups: siteGroups,
    ),
  );

  if (selectedGroup == null || !context.mounted) return;

  final updated = organism.copyWith(
    groupId: selectedGroup.id,
    siteId: selectedGroup.siteId,
    urlPath: '${selectedGroup.urlPath}/${organism.slug}',
    internalPath: '${selectedGroup.internalPath}/${organism.id}',
    updatedAt: DateTime.now().toIso8601String(),
    metadata: {
      ...?organism.metadata,
      'lastMovedAt': DateTime.now().toIso8601String(),
      'lastMovedFromSiteId': siteId,
    },
  );
  await organismRepository.updateRecord(updated);

  if (!context.mounted) return;

  // Reload parent nodes so the graph reflects the change
  final siteNode = organismNode.parent;
  siteNode?.add(const GraphNodeReloadRequested());
  final targetNode =
      await graphRepository.getNodeForUrlPath(selectedGroup.urlPath);
  targetNode?.add(const GraphNodeReloadRequested());

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Moved ${organism.name} to ${selectedGroup.name}'),
    ),
  );
}

/// After a split/merge at site level, offer to move the resulting record
/// into a structure.
Future<void> _showDestinationPicker(
  BuildContext context, {
  required OrganismRecord record,
  required String actionLabel,
}) async {
  final siteId = record.siteId;
  if (siteId == null) return;

  final groupRepository = context.read<GroupRepository>();
  final organismRepository = context.read<OrganismRecordRepository>();
  final graphRepository = context.read<GraphRepository>();
  final allGroups = await groupRepository.getAll();
  final siteGroups = allGroups.where((g) => g.siteId == siteId).toList();

  if (!context.mounted || siteGroups.isEmpty) return;

  final selectedGroup = await showDialog<Group>(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) => _TargetStructurePickerDialog(
      title: 'Move $actionLabel',
      prompt: 'Select a structure for "${record.name}":',
      availableGroups: siteGroups,
    ),
  );

  if (selectedGroup == null || !context.mounted) return;

  final updated = record.copyWith(
    groupId: selectedGroup.id,
    siteId: selectedGroup.siteId,
    urlPath: '${selectedGroup.urlPath}/${record.slug}',
    internalPath: '${selectedGroup.internalPath}/${record.id}',
    updatedAt: DateTime.now().toIso8601String(),
  );
  await organismRepository.updateRecord(updated);

  if (!context.mounted) return;

  // Reload affected graph nodes
  final parentNode =
      await graphRepository.getNodeForUrlPath(selectedGroup.urlPath);
  parentNode?.add(const GraphNodeReloadRequested());

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Moved ${record.name} to ${selectedGroup.name}'),
    ),
  );
}

/// Simple outplant dialog for a single organism.
Future<void> _showOutplantDialog(
  BuildContext context,
  OrganismNode organismNode,
) async {
  final organism = organismNode.currentRecord;
  final siteRepository = context.read<SiteRepository>();
  final eventRepository = context.read<EventRepository>();
  final organismRepository = context.read<OrganismRecordRepository>();
  final organization = context.read<Organization>();

  final allSites = await siteRepository.getAll();
  final outplantingSites = allSites
      .where((s) => SiteType.fromId(s.siteTypeId).isOutplanting)
      .toList();

  if (!context.mounted) return;

  if (outplantingSites.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No outplanting sites available. Create one first.'),
      ),
    );
    return;
  }

  final result = await showDialog<_OutplantResult>(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) => _OutplantQuickDialog(
      organismName: organism.name,
      maxQuantity: organism.measurement.value.toInt(),
      availableSites: outplantingSites,
    ),
  );

  if (result == null || !context.mounted) return;

  try {
    final service = OutplantSubmissionService(
      eventRepository: eventRepository,
      organismRecordRepository: organismRepository,
    );
    await service.createOutplantEvent(
      site: result.site,
      eventName: service.generateDefaultEventName(DateTime.now(), result.site),
      selectedOrganisms: [
        OutplantSelectedOrganism(
          organismId: organism.id,
          quantity: result.quantity,
          currentQuantity: organism.measurement.value.toInt(),
          tagId: organism.name,
          speciesId: organism.speciesId,
          genetRecordId: organism.genetRecordId,
          sourcePath: organism.urlPath,
        ),
      ],
      deductFromInventory: result.deductFromInventory,
      organizationId: organization.id,
      userId: organismRepository.user.id,
    );

    if (!context.mounted) return;

    organismNode.add(const GraphNodeReloadRequested());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Outplanted ${result.quantity} of ${organism.name} to ${result.site.name}',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Outplant failed: $e')),
    );
  }
}

class _OutplantResult {
  const _OutplantResult({
    required this.site,
    required this.quantity,
    required this.deductFromInventory,
  });

  final Site site;
  final int quantity;
  final bool deductFromInventory;
}

class _OutplantQuickDialog extends StatefulWidget {
  const _OutplantQuickDialog({
    required this.organismName,
    required this.maxQuantity,
    required this.availableSites,
  });

  final String organismName;
  final int maxQuantity;
  final List<Site> availableSites;

  @override
  State<_OutplantQuickDialog> createState() => _OutplantQuickDialogState();
}

class _OutplantQuickDialogState extends State<_OutplantQuickDialog> {
  Site? _selectedSite;
  late int _quantity = widget.maxQuantity;
  bool _deductFromInventory = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Outplant ${widget.organismName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Outplanting site:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<Site>(
            initialValue: _selectedSite,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Select outplanting site',
            ),
            items: widget.availableSites
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (value) => setState(() => _selectedSite = value),
          ),
          const SizedBox(height: 16),
          const Text('Quantity:'),
          const SizedBox(height: 8),
          if (widget.maxQuantity > 1)
            Row(
              children: [
                IconButton(
                  onPressed:
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Text(
                    '$_quantity of ${widget.maxQuantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  onPressed: _quantity < widget.maxQuantity
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            )
          else
            Text('1 of ${widget.maxQuantity}'),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _deductFromInventory,
            onChanged: (v) =>
                setState(() => _deductFromInventory = v ?? true),
            title: const Text('Deduct from inventory'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedSite != null
              ? () => Navigator.pop(
                    context,
                    _OutplantResult(
                      site: _selectedSite!,
                      quantity: _quantity,
                      deductFromInventory: _deductFromInventory,
                    ),
                  )
              : null,
          child: const Text('Outplant'),
        ),
      ],
    );
  }
}

/// Reusable target structure picker dialog.
class _TargetStructurePickerDialog extends StatefulWidget {
  const _TargetStructurePickerDialog({
    required this.title,
    required this.prompt,
    required this.availableGroups,
  });

  final String title;
  final String prompt;
  final List<Group> availableGroups;

  @override
  State<_TargetStructurePickerDialog> createState() =>
      _TargetStructurePickerDialogState();
}

class _TargetStructurePickerDialogState
    extends State<_TargetStructurePickerDialog> {
  Group? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.prompt),
          const SizedBox(height: 12),
          DropdownButtonFormField<Group>(
            initialValue: _selected,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Select structure',
            ),
            items: widget.availableGroups
                .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                .toList(),
            onChanged: (value) => setState(() => _selected = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected != null
              ? () => Navigator.pop(context, _selected)
              : null,
          child: const Text('Move'),
        ),
      ],
    );
  }
}
