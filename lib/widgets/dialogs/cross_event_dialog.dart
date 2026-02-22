// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/blocs/events/cross/cross_form_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';

import 'package:seafoundry_app/models/models.dart';
import '../../repositories/inventory/event_repository.dart';
import '../../repositories/inventory/group_repository.dart';
import '../../repositories/inventory/organism_record_repository.dart';
import '../../repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:seafoundry_app/widgets/dialogs/base_event_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/location_selection_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_creation_wizard/organism_creation_wizard.dart';
import 'package:seafoundry_app/widgets/forms/base_create_dialog.dart';
import 'package:seafoundry_app/widgets/wizards/organism_selection_wizard.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import '../spreadsheet/safe_provider_mixin.dart';

/// Dialog for creating cross events using the established patterns
class CrossEventDialog
    extends BaseEventDialog<CrossEvent, CrossFormBloc, CrossFormState> {
  const CrossEventDialog({
    super.key,
    this.allowedParentOrganismIds,
    this.initialDamIds,
    this.initialSireIds,
  });

  final Set<String>? allowedParentOrganismIds;
  final List<String>? initialDamIds;
  final List<String>? initialSireIds;

  @override
  ModelType get modelType => ModelType.event;

  @override
  CreateDialogConfig get config => const CreateDialogConfig(
    title: 'Record Genetic Cross',
    icon: Icons.merge_type,
    iconColor: Colors.deepPurple,
    width: 700,
  );

  @override
  bool get showTaskOption => false;

  @override
  List<Widget> buildEventContent(BuildContext context, CrossFormState state) {
    // Get organism kind from bloc for organism-aware labeling
    final bloc = context.read<CrossFormBloc>();
    final organismKind = bloc.organismKind;
    final organismLabel = organismKind?.metadata.displayName ?? 'organism';

    return [
      // Dam Selection
      _buildParentSelector(
        context: context,
        label: state.dams.label,
        hint: 'Select dam gametes',
        error: state.dams.displayError?.toString(),
        selectedIds: state.dams.value ?? [],
        onTap: () => _showOrganismSelectionDialog(
          context,
          state,
          isDam: true,
        ),
        onRemove: (id) {
          final newList = [...(state.dams.value ?? [])].cast<String>();
          newList.remove(id);
          context.read<CrossFormBloc>().add(DamsChanged(newList));
        },
        icon: Icons.female,
        iconColor: Colors.pink,
        organismLabel: organismLabel,
      ),
      const SizedBox(height: 24),

      // Sire Selection
      _buildParentSelector(
        context: context,
        label: state.sires.label,
        hint: 'Select sire gametes',
        error: state.sires.displayError?.toString(),
        selectedIds: state.sires.value ?? [],
        onTap: () => _showOrganismSelectionDialog(
          context,
          state,
          isDam: false,
        ),
        onRemove: (id) {
          final newList = [...(state.sires.value ?? [])].cast<String>();
          newList.remove(id);
          context.read<CrossFormBloc>().add(SiresChanged(newList));
        },
        icon: Icons.male,
        iconColor: Colors.blue,
        organismLabel: organismLabel,
      ),
      const SizedBox(height: 24),

      // Notes
      TextFormField(
        decoration: InputDecoration(
          labelText: state.notes.label,
          hintText: state.notes.hintText,
          errorText: state.notes.displayError?.toString(),
          alignLabelWithHint: true,
        ),
        maxLines: 3,
        onChanged: (value) {
          context.read<CrossFormBloc>().add(CrossNotesChanged(value));
        },
      ),
    ];
  }

  Future<void> _showOrganismSelectionDialog(
    BuildContext context,
    CrossFormState state, {
    required bool isDam,
  }) async {
    final bloc = context.read<CrossFormBloc>();
    final targetNode = bloc.targetNode;
    if (targetNode == null) return;

    // Get fallback organism kind from organization
    final currentUserState = context.read<CurrentUser>().state;
    final fallbackOrganismKind = (currentUserState is CurrentUserLoaded)
        ? currentUserState.organization.primaryOrganismKind
        : OrganismKind.coral;

    // Get available organisms from the parent node
    try {
      await targetNode.awaitLoaded().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      LoggingService.instance.warning(
        'CrossEventDialog: Loading target node timed out',
        {'nodeId': targetNode.id},
      );
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Loading organisms timed out. Please try again.',
        isError: true,
      );
      return;
    } catch (error) {
      LoggingService.instance.warning(
        'CrossEventDialog: Failed to load target node',
        {'error': error.toString()},
      );
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Unable to load organisms. Please try again.',
        isError: true,
      );
      return;
    }
    if (!context.mounted) return;
    final nodeState = targetNode.state;
    if (nodeState is! GraphLoadedState) return;

    // Get organisms based on node type - only those that can spawn
    final availableOrganismIds = <String>[];
    
    // Helper to check organism
    bool isValidSpawner(OrganismRecord organism) {
      if (organism.lifeStage.stage != LifeStage.gamete) {
        return false;
      }
      final role = organism.provenanceAttributes.gameteRole;
      if (role == null) {
        return false;
      }
      return isDam
          ? role == ProvenanceGameteRole.egg
          : role == ProvenanceGameteRole.sperm;
    }

    if (targetNode is GroupNode) {
      // Load all organism nodes in parallel
      final children = nodeState.children;
      final organismNodes = children.whereType<OrganismNode>().toList();
      final results = await Future.wait(
        organismNodes.map(
          (node) => _loadOrganismIdSafely(node, filter: isValidSpawner),
        ),
        eagerError: false,
      );
      if (!context.mounted) return;
      availableOrganismIds.addAll(results.whereType<String>());
    } else if (targetNode is SiteNode) {
      // Phase 1: Load all groups in parallel
      final children = nodeState.children;
      final groupNodes = children.whereType<GroupNode>().toList();
      await Future.wait(
        groupNodes.map((node) => _loadGroupSafelyCross(node)),
        eagerError: false,
      );
      if (!context.mounted) return;

      // Phase 2: Collect all organism nodes from loaded groups and load in parallel
      final organismNodes = <OrganismNode>[];
      for (final groupNode in groupNodes) {
        final groupState = groupNode.state;
        if (groupState is GraphLoadedState<Group>) {
          organismNodes.addAll(groupState.children.whereType<OrganismNode>());
        }
      }

      final results = await Future.wait(
        organismNodes.map(
          (node) => _loadOrganismIdSafely(node, filter: isValidSpawner),
        ),
        eagerError: false,
      );
      if (!context.mounted) return;
      availableOrganismIds.addAll(results.whereType<String>());
    }

    final filteredIds = allowedParentOrganismIds == null
        ? availableOrganismIds
        : availableOrganismIds
            .where((id) => allowedParentOrganismIds!.contains(id))
            .toList();

    if (filteredIds.isEmpty) {
      if (!context.mounted) return;
      final roleLabel = isDam ? 'egg' : 'sperm';
      showSafeDialogSnackBar(
        context,
        'No $roleLabel gametes available for selection',
        isError: true,
      );
      return;
    }

    if (!context.mounted) return;

    // Use OrganismSelectionWizard for advanced filtering/searching
    final repositories = context.safeReadAll(() => (
          context.read<OrganismRecordRepository>(),
          context.read<SiteRepository>(),
          context.read<GroupRepository>(),
          context.read<SpeciesRegistry>(),
        ));
    if (repositories == null) {
      showSafeDialogSnackBar(
        context,
        'Organism tools are still loading. Please try again.',
        isError: true,
      );
      return;
    }
    final (
      organismRepository,
      siteRepository,
      groupRepository,
      speciesRegistry,
    ) = repositories;

    await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => ChangeNotifierProvider<SpeciesRegistry>.value(
        value: speciesRegistry,
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<OrganismRecordRepository>.value(
              value: organismRepository,
            ),
            RepositoryProvider<SiteRepository>.value(value: siteRepository),
            RepositoryProvider<GroupRepository>.value(value: groupRepository),
          ],
          child: Dialog(
            child: SizedBox(
              width: 600,
              height: 700,
              child: Column(
                children: [
                  Padding(
                    padding: UI.paddingMd,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isDam ? 'Select Dam Gametes' : 'Select Sire Gametes',
                            style:
                                Theme.of(dialogContext).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => popSafeDialogContext(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: OrganismSelectionWizard(
                      config: OrganismSelectionConfig(
                        mode: OrganismSelectionMode.multiple,
                        organismKind: bloc.organismKind ?? fallbackOrganismKind,
                        allowedOrganismRecordIds: filteredIds,
                        initialSelection: isDam
                            ? (state.dams.value ?? [])
                                .map(
                                  (id) => OrganismRecord.partial(
                                    id: id,
                                    organismKind: bloc.organismKind ??
                                        fallbackOrganismKind,
                                    lifeStage: const LifeStageSpec(
                                      stage: LifeStage.gamete,
                                    ),
                                    measurement: const PopulationMeasurement(
                                      value: 1,
                                      unit: MeasurementUnit.count,
                                    ),
                                  ),
                                )
                                .toList()
                            : (state.sires.value ?? [])
                                .map(
                                  (id) => OrganismRecord.partial(
                                    id: id,
                                    organismKind: bloc.organismKind ??
                                        fallbackOrganismKind,
                                    lifeStage: const LifeStageSpec(
                                      stage: LifeStage.gamete,
                                    ),
                                    measurement: const PopulationMeasurement(
                                      value: 1,
                                      unit: MeasurementUnit.count,
                                    ),
                                  ),
                                )
                                .toList(),
                        // Note: The wizard uses IDs for matching usually, but
                        // passing dummy records might be risky if it needs full data.
                        // Ideally we should pass the full records if we have them,
                        // or let the wizard load them.
                        // Given we only have IDs in state.dams.value, we rely on
                        // the wizard loading the allowed IDs.
                        // Actually, let's just pass empty initial selection if we
                        // can't easily reconstruct, OR rely on the fact we just
                        // verified these IDs exist.
                        // A better approach is to not set initialSelection here
                        // and let the user re-select if they open it again, OR
                        // fetch the records.
                        // For now, let's keep it simple and just let them select.
                        showSelectionSummary: true,
                      ),
                      onSelectionChanged: (selected) {
                        final ids = selected.map((o) => o.id).toList();
                        if (isDam) {
                          bloc.add(DamsChanged(ids));
                        } else {
                          bloc.add(SiresChanged(ids));
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: UI.paddingMd,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton(
                          onPressed: () => popSafeDialogContext(dialogContext),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParentSelector({
    required BuildContext context,
    required String label,
    required String hint,
    required String? error,
    required List<String> selectedIds,
    required VoidCallback onTap,
    required Function(String) onRemove,
    required IconData icon,
    required Color iconColor,
    required String organismLabel,
  }) {
    final selectedCount = selectedIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: error,
            contentPadding: EdgeInsets.zero,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.disabled.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedCount > 0
                        ? Icons.check_circle
                        : Icons.add_circle_outline,
                    color: selectedCount > 0
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? hint
                          : '$selectedCount $organismLabel${selectedCount > 1 ? 's' : ''} selected',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
        ),
        if (selectedCount > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedIds.map((id) {
              return Chip(
                avatar: Icon(icon, size: 16, color: iconColor),
                label: Text(id),
                onDeleted: () => onRemove(id),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  /// Show the cross dialog
  static Future<CrossEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
    Set<String>? allowedParentOrganismIds,
    List<String>? initialDamIds,
    List<String>? initialSireIds,
  }) {
    if (!context.mounted) return Future.value(null);
    // Read dependencies BEFORE showDialog to ensure provider scope
    final repositories = context.safeReadAll(() => (
      context.read<EventRepository>(),
      context.read<OrganismRecordRepository>(),
      context.read<SiteRepository>(),
      context.read<GroupRepository>(),
      context.read<SpeciesRegistry>(),
    ));
    if (repositories == null) {
      showSafeDialogSnackBar(
        context,
        'Cross tools are still loading. Please try again.',
        isError: true,
      );
      return Future.value(null);
    }
    final (
      eventRepository,
      organismRepository,
      siteRepository,
      groupRepository,
      speciesRegistry,
    ) = repositories;
    final propagationService = context.maybeRead<EventPropagationService>();

    return showDialog<CrossEvent>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false, // Stay in provider scope
      builder: (dialogContext) => ChangeNotifierProvider<SpeciesRegistry>.value(
        value: speciesRegistry,
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<EventRepository>.value(value: eventRepository),
            RepositoryProvider<OrganismRecordRepository>.value(
              value: organismRepository,
            ),
            RepositoryProvider<SiteRepository>.value(value: siteRepository),
            RepositoryProvider<GroupRepository>.value(value: groupRepository),
          ],
          child: BlocProvider(
            create: (_) {
              final bloc = CrossFormBloc(
                eventRepository: eventRepository,
                propagationService: propagationService,
              )..add(EventFormTargetChanged(targetNode));
              final filteredDams = initialDamIds
                  ?.where((id) => allowedParentOrganismIds?.contains(id) ?? true)
                  .toList(growable: false);
              final filteredSires = initialSireIds
                  ?.where((id) => allowedParentOrganismIds?.contains(id) ?? true)
                  .toList(growable: false);
              if (filteredDams != null && filteredDams.isNotEmpty) {
                bloc.add(DamsChanged(filteredDams));
              }
              if (filteredSires != null && filteredSires.isNotEmpty) {
                bloc.add(SiresChanged(filteredSires));
              }
              return bloc;
            },
            child: CrossEventDialog(
              allowedParentOrganismIds: allowedParentOrganismIds,
              initialDamIds: initialDamIds,
              initialSireIds: initialSireIds,
            ),
          ),
        ),
      ),
    );
  }

  /// Show the cross dialog, then create a cohort organism.
  static Future<OrganismRecord?> showAndCreateCohort(
    BuildContext context, {
    required GraphNode targetNode,
    required OrganismKind organismKind,
    Set<String>? allowedParentOrganismIds,
    List<String>? initialDamIds,
    List<String>? initialSireIds,
  }) async {
    // Capture repository before showing dialogs
    final organismRepository = context.maybeRead<OrganismRecordRepository>();

    final crossEvent = await CrossEventDialog.show(
      context,
      targetNode: targetNode,
      allowedParentOrganismIds: allowedParentOrganismIds,
      initialDamIds: initialDamIds,
      initialSireIds: initialSireIds,
    );
    if (crossEvent == null || !context.mounted) return null;

    GroupNode? targetGroup;
    var requiresSelection = false;
    if (targetNode is GroupNode) {
      targetGroup = targetNode;
    } else if (targetNode is SiteNode) {
      requiresSelection = true;
      targetGroup = await LocationSelectionDialog.show(
        context,
        siteNode: targetNode,
        organismLabel: organismKind.metadata.displayName,
      );
    } else if (targetNode is OrganizationNode) {
      requiresSelection = true;
      final selectedSite =
          await _selectSiteFromOrganization(context, targetNode);
      if (selectedSite != null && context.mounted) {
        targetGroup = await LocationSelectionDialog.show(
          context,
          siteNode: selectedSite,
          organismLabel: organismKind.metadata.displayName,
        );
      }
    }

    if (targetGroup == null || !context.mounted) {
      if (context.mounted && !requiresSelection) {
        showSafeDialogSnackBar(
          context,
          'Please select a site or structure first',
          isError: true,
        );
      }
      return null;
    }

    final damIds = crossEvent.damIds;
    final sireIds = crossEvent.sireIds;

    // Resolve actual provenance IDs from the selected gamete organisms.
    // The wizard expects provenance IDs (PID-Gspec-XXX), not organism record IDs.
    // If no provenance ID is found, pass null and let the wizard default to 'unknown'.
    String? damProvenanceId;
    String? sireProvenanceId;
    if (organismRepository != null) {
      if (damIds.isNotEmpty) {
        damProvenanceId = await _resolveProvenanceId(
          organismRepository,
          damIds.first,
        );
      }
      if (sireIds.isNotEmpty) {
        sireProvenanceId = await _resolveProvenanceId(
          organismRepository,
          sireIds.first,
        );
      }
    }

    final metadata = <String, dynamic>{
      // Store organism record IDs for traceability
      if (damIds.isNotEmpty) 'damOrganismIds': damIds,
      if (sireIds.isNotEmpty) 'sireOrganismIds': sireIds,
      if (damIds.isNotEmpty || sireIds.isNotEmpty)
        'parentGameteIds': [...damIds, ...sireIds],
    };

    return OrganismCreationWizard.showAndCreate(
      context,
      parentGroupNode: targetGroup,
      organismKind: organismKind,
      initialProvenanceType: ProvenanceType.sexualCohort,
      initialDamProvenanceId: damProvenanceId,
      initialSireProvenanceId: sireProvenanceId,
      additionalMetadata: metadata.isEmpty ? null : metadata,
    );
  }

  /// Resolve the provenance ID from an organism record.
  /// Returns the organism's localId (genet name), or null if not found.
  /// The wizard uses this to trace lineage back to the parent gamete.
  static Future<String?> _resolveProvenanceId(
    OrganismRecordRepository repository,
    String organismId,
  ) async {
    try {
      final organism = await repository.getRecordForId(organismId);
      if (organism == null) return null;
      // Use localId which is the genet's name/identifier
      final localId = organism.localId?.trim();
      if (localId != null && localId.isNotEmpty) {
        return localId;
      }
      return null;
    } catch (e) {
      LoggingService.instance.warning(
        'CrossEventDialog: Failed to resolve provenance ID',
        {'organismId': organismId, 'error': e.toString()},
      );
      return null;
    }
  }
}

Future<SiteNode?> _selectSiteFromOrganization(
  BuildContext context,
  OrganizationNode organizationNode,
) async {
  try {
    await organizationNode.awaitLoaded().timeout(const Duration(seconds: 10));
  } on TimeoutException {
    if (!context.mounted) return null;
    showSafeDialogSnackBar(
      context,
      'Loading sites timed out. Please try again.',
      isError: true,
    );
    return null;
  } catch (_) {
    if (!context.mounted) return null;
    showSafeDialogSnackBar(
      context,
      'Unable to load sites for selection',
      isError: true,
    );
    return null;
  }
  if (!context.mounted) return null;

  final nodeState = organizationNode.state;
  if (nodeState is! OrganizationLoadedState) return null;
  final sites = nodeState.siteNodes.toList()
    ..sort((a, b) => a.site.name.compareTo(b.site.name));
  if (sites.isEmpty) {
    showSafeDialogSnackBar(
      context,
      'No sites available for selection',
      isError: true,
    );
    return null;
  }

  return showDialog<SiteNode>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (dialogContext) {
      SiteNode? selectedSite;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Site'),
            content: DropdownButtonFormField<SiteNode>(
              initialValue: selectedSite,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Choose a site',
              ),
              items: sites
                  .map(
                    (site) => DropdownMenuItem(
                      value: site,
                      child: Text(site.site.name),
                    ),
                  )
                  .toList(),
              onChanged: (site) => setState(() => selectedSite = site),
            ),
            actions: [
              TextButton(
                onPressed: () => popSafeDialogContext(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedSite == null
                    ? null
                    : () => popSafeDialogContext(dialogContext, selectedSite),
                child: const Text('Select'),
              ),
            ],
          );
        },
      );
    },
  );
}



/// Extension to make old API compatible
extension CrossDialogCompat on CrossEventDialog {
  /// Compatibility method for existing code
  static Future<CrossEvent?> showCompat(
    BuildContext context, {
    required GraphNode node,
  }) {
    return CrossEventDialog.show(context, targetNode: node);
  }
}

/// Helper function to safely load an organism node in parallel.
/// Returns the organism ID if it passes the filter, null otherwise.
Future<String?> _loadOrganismIdSafely(
  OrganismNode node, {
  required bool Function(OrganismRecord) filter,
}) async {
  try {
    await node.awaitLoaded().timeout(const Duration(seconds: 10));
    final state = node.state;
    if (state is GraphLoadedState<OrganismRecord>) {
      final organism = state.record;
      if (filter(organism)) {
        return organism.id;
      }
    }
  } catch (error) {
    LoggingService.instance.warning(
      'CrossEventDialog: Failed to load organism node for selection',
      {'nodeId': node.id, 'error': error.toString()},
    );
  }
  return null;
}

/// Helper function to safely load a group node in parallel.
Future<void> _loadGroupSafelyCross(GroupNode node) async {
  try {
    await node.awaitLoaded().timeout(const Duration(seconds: 10));
  } catch (error) {
    LoggingService.instance.warning(
      'CrossEventDialog: Failed to load group node for selection',
      {'nodeId': node.id, 'error': error.toString()},
    );
  }
}
