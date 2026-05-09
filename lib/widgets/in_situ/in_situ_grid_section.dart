// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/cubits/in_situ_grid/in_situ_grid_cubit.dart';
import 'package:seafoundry_app/cubits/in_situ_grid/in_situ_grid_state.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/dialogs/structure_dialog.dart';
import 'package:seafoundry_app/widgets/in_situ/grid_cell_menu.dart';
import 'package:seafoundry_app/widgets/in_situ/grid_layout_builder.dart';
import 'package:seafoundry_app/widgets/in_situ/grid_renderer.dart';

class InSituGridSection extends StatelessWidget {
  const InSituGridSection({
    super.key,
    required this.state,
    required this.siteNode,
  });

  final SiteLoadedState state;
  final SiteNode siteNode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InSituGridCubit(),
      child: _InSituGridSectionView(state: state, siteNode: siteNode),
    );
  }
}

class _InSituGridSectionView extends StatefulWidget {
  const _InSituGridSectionView({required this.state, required this.siteNode});

  final SiteLoadedState state;
  final SiteNode siteNode;

  @override
  State<_InSituGridSectionView> createState() => _InSituGridSectionViewState();
}

class _InSituGridSectionViewState extends State<_InSituGridSectionView> {
  SiteLoadedState? _previousState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cubit = context.read<InSituGridCubit>();
    // Clear selection when state record changes
    if (_previousState != null &&
        _previousState!.record != widget.state.record) {
      cubit.clearSelection();
    }
    _previousState = widget.state;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InSituGridCubit, InSituGridState>(
      builder: (context, cubitState) {
        final layout = buildGridLayoutFromSiteState(widget.state);
        final selectedSummary = cubitState.selectedCoordinate != null
            ? layout.cells[cubitState.selectedCoordinate] ??
                  InSituGridCellSummary.empty(cubitState.selectedCoordinate!)
            : null;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nursery Grid',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Zoom out',
                      onPressed: cubitState.zoom <= 0.5
                          ? null
                          : () => context.read<InSituGridCubit>().zoomOut(),
                      icon: const Icon(Icons.zoom_out),
                    ),
                    IconButton(
                      tooltip: 'Zoom in',
                      onPressed: cubitState.zoom >= 2.5
                          ? null
                          : () => context.read<InSituGridCubit>().zoomIn(),
                      icon: const Icon(Icons.zoom_in),
                    ),
                    const Spacer(),
                    if (cubitState.isUpdating)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: Spacing.sm),
                _buildGrid(context, layout, cubitState),
                SizedBox(height: Spacing.sm),
                if (selectedSummary != null)
                  _SelectedCellDetails(summary: selectedSummary)
                else
                  Text(
                    'Select a cell to view coral details.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    InSituGridLayout layout,
    InSituGridState cubitState,
  ) {
    final canAddRow = layout.rowCount < kInSituMaxRows;
    final canAddColumn = layout.colCount < kInSituMaxColumns;

    final grid = InSituGridRenderer(
      rowCount: layout.rowCount,
      columnCount: layout.colCount,
      cells: layout.cells,
      selectedCoordinate: cubitState.selectedCoordinate,
      onCellSelected: (summary) {
        context.read<InSituGridCubit>().selectCoordinate(summary.coordinate);
        if (summary.hasStructure && summary.structure != null) {
          // Navigate to the structure's graph node
          _navigateToStructure(context, summary.structure!);
        } else if (!summary.hasStructure && !summary.hasCorals) {
          _handleEmptyCellTap(context, summary);
        }
      },
      scale: cubitState.zoom,
    );

    final scrollable = ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: grid,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        scrollable,
        Positioned(
          bottom: -Spacing.md,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _EdgeIconButton(
              tooltip: 'Add row',
              onPressed: !cubitState.isUpdating && canAddRow
                  ? () => _adjustDimensions(context, rowDelta: 1)
                  : null,
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: -Spacing.md,
          child: Align(
            alignment: Alignment.centerRight,
            child: _EdgeIconButton(
              tooltip: 'Add column',
              onPressed: !cubitState.isUpdating && canAddColumn
                  ? () => _adjustDimensions(context, columnDelta: 1)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _adjustDimensions(
    BuildContext context, {
    int rowDelta = 0,
    int columnDelta = 0,
  }) async {
    if (rowDelta == 0 && columnDelta == 0) return;

    final layout = buildGridLayoutFromSiteState(widget.state);
    final currentSite = widget.state.site;
    final currentRows = currentSite.rowCount ?? layout.rowCount;
    final currentCols = currentSite.colCount ?? layout.colCount;

    final targetRows = (currentRows + rowDelta).clamp(
      kInSituMinDimension,
      kInSituMaxRows,
    );
    final targetCols = (currentCols + columnDelta).clamp(
      kInSituMinDimension,
      kInSituMaxColumns,
    );

    if (rowDelta != 0 && targetRows == currentRows) {
      _showSnack(
        context,
        rowDelta > 0
            ? 'Maximum rows reached for this nursery.'
            : 'Cannot reduce rows further.',
      );
      return;
    }
    if (columnDelta != 0 && targetCols == currentCols) {
      _showSnack(
        context,
        columnDelta > 0
            ? 'Maximum columns reached for this nursery.'
            : 'Cannot reduce columns further.',
      );
      return;
    }

    final cubit = context.read<InSituGridCubit>();
    cubit.setUpdating(true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final repo = context.read<SiteRepository>();
      await repo.updateGridDimensions(
        site: currentSite,
        rowCount: targetRows,
        colCount: targetCols,
      );
      if (!widget.siteNode.isClosed) {
        widget.siteNode.add(GraphNodeReloadRequested());
      }
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to update grid: $error')),
      );
    } finally {
      cubit.setUpdating(false);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _navigateToStructure(
    BuildContext context,
    Group structure,
  ) async {
    try {
      final graphRepository = context.read<GraphRepository>();
      final navigationCubit = context.read<NavigationCubit>();

      LoggingService.instance.info(
        'Navigating to structure: ${structure.name} (${structure.urlPath})',
      );

      final node = await graphRepository.getNodeForUrlPath(structure.urlPath);
      if (node == null) {
        LoggingService.instance.error(
          'Failed to find graph node for structure ${structure.id}',
          null,
        );
        if (context.mounted) {
          _showSnack(
            context,
            'Could not find structure node: ${structure.name}',
          );
        }
        return;
      }

      if (context.mounted) {
        await navigationCubit.navigateTo(node);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error navigating to structure ${structure.id}',
        e,
        stackTrace,
      );
      if (context.mounted) {
        _showSnack(context, 'Failed to navigate to structure: ${e.toString()}');
      }
    }
  }

  Future<void> _handleEmptyCellTap(
    BuildContext context,
    InSituGridCellSummary summary,
  ) async {
    final action = await showModalBottomSheet<_EmptyCellAction>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Populate with existing structure'),
              onTap: () =>
                  Navigator.of(context).pop(_EmptyCellAction.assignExisting),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Create new structure'),
              onTap: () =>
                  Navigator.of(context).pop(_EmptyCellAction.createNew),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _EmptyCellAction.assignExisting:
        await _selectExistingStructure(context, summary.coordinate);
        break;
      case _EmptyCellAction.createNew:
        await _createStructure(context, summary.coordinate);
        break;
    }
  }

  Future<void> _selectExistingStructure(
    BuildContext context,
    InSituGridCoordinate coordinate,
  ) async {
    final unplaced = widget.state.groupNodes
        .where(
          (node) =>
              node.initialRecord.rowIndex == null ||
              node.initialRecord.colIndex == null,
        )
        .toList();

    if (unplaced.isEmpty) {
      _showSnack(
        context,
        'No unassigned structures available. Create one first.',
      );
      return;
    }

    final selected = await showDialog<Group?>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select structure'),
        content: SizedBox(
          width: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: unplaced.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final groupNode = unplaced[index];
              final group = groupNode.initialRecord;
              return ListTile(
                title: Text(group.name),
                subtitle: Text(group.groupType.name),
                onTap: () => Navigator.of(context).pop(group),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;

    final cubit = context.read<InSituGridCubit>();
    cubit.setUpdating(true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final repo = context.read<GroupRepository>();
      final updatedGroup = selected.copyWith(
        rowIndex: coordinate.rowIndex,
        colIndex: coordinate.columnIndex,
      );
      await repo.updateRecord(updatedGroup);
      if (!widget.siteNode.isClosed) {
        widget.siteNode.add(GraphNodeReloadRequested());
        // Wait for the site node to fully reload with updated data
        // This ensures the grid rebuilds with fresh data from Firestore
        await widget.siteNode.awaitLoaded();
        // Small additional delay to ensure stream subscriptions have propagated
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to assign structure: $error')),
      );
    } finally {
      if (context.mounted) {
        cubit.setUpdating(false);
      }
    }
  }

  Future<void> _createStructure(
    BuildContext context,
    InSituGridCoordinate coordinate,
  ) async {
    await StructureDialog.show(
      context,
      type: StructureType.group,
      parentNode: widget.siteNode,
    );
    if (!widget.siteNode.isClosed) {
      widget.siteNode.add(GraphNodeReloadRequested());
    }

    // After reload, prompt user to assign the newly created structure if any
    await Future.delayed(const Duration(milliseconds: 200));
    if (context.mounted) {
      await _selectExistingStructure(context, coordinate);
    }
  }
}

enum _EmptyCellAction { assignExisting, createNew }

class _EdgeIconButton extends StatelessWidget {
  const _EdgeIconButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: IconButton.filledTonal(
        icon: const Icon(Icons.add),
        onPressed: onPressed,
      ),
    );
  }
}

class _SelectedCellDetails extends StatelessWidget {
  const _SelectedCellDetails({required this.summary});

  final InSituGridCellSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Cell ${summary.coordinate.displayLabel}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (summary.hasStructure)
                InSituGridCellMenu(
                  summary: summary,
                  onSelected: (action, _) {
                    final message = switch (action) {
                      InSituGridCellMenuAction.depopulate =>
                        'Use Move · Move Out to clear this structure.',
                      InSituGridCellMenuAction.markMaintenance =>
                        'Log an observation to flag maintenance requirements.',
                      InSituGridCellMenuAction.repopulate =>
                        'Use Move · Move In when you restock this position.',
                    };
                    ScaffoldMessenger.maybeOf(
                      context,
                    )?.showSnackBar(SnackBar(content: Text(message)));
                  },
                  child: const Icon(Icons.more_horiz),
                ),
            ],
          ),
          SizedBox(height: Spacing.sm),
          if (summary.hasStructure) ...[
            Text(
              summary.structureName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (summary.structureTypeLabel != null) ...[
              SizedBox(height: Spacing.xs),
              Text(
                summary.structureTypeLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ] else ...[
            Text(
              'No structure assigned to this position yet.',
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: Spacing.xs),
            Text(
              'Tap the grid to populate this location with a structure.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          SizedBox(height: Spacing.sm),
          Text(
            'Status: ${summary.statusLabel}',
            style: theme.textTheme.bodySmall,
          ),
          SizedBox(height: Spacing.xs),
          Text(summary.occupancyLabel, style: theme.textTheme.bodyMedium),
          if (summary.hasCorals) ...[
            SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: summary.healthBreakdown.entries
                  .map(
                    (entry) => Chip(
                      label: Text('${entry.key.displayName}: ${entry.value}'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
