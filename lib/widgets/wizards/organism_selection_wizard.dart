// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_selection/organism_selection_cubit.dart';
import 'package:seafoundry_app/cubits/organism_selection/organism_selection_state.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Configuration for organism selection behavior
enum OrganismSelectionMode {
  single, // Select one organism
  multiple, // Select multiple organisms
  dropdown, // Use dropdown for single selection
}

/// Configuration for organism filtering
class OrganismSelectionConfig {
  final OrganismSelectionMode mode;
  final String? label;
  final String? hintText;

  /// Allowed organism record IDs (filters to only these IDs)
  final List<String>? allowedOrganismRecordIds;

  /// Excluded organism record IDs (filters out these IDs)
  final List<String>? excludedOrganismRecordIds;

  final List<OrganismRecord>? initialSelection;
  final bool showSearch;
  final bool showSelectionSummary;
  final double? height;
  final String? emptyStateMessage;
  final bool showFilters;
  final bool showTreeNavigation;
  final String? preselectedSiteId;
  final String? preselectedGroupId;
  final OrganismKind organismKind;

  const OrganismSelectionConfig({
    required this.mode,
    this.label,
    this.hintText,
    this.allowedOrganismRecordIds,
    this.excludedOrganismRecordIds,
    this.initialSelection,
    this.showSearch = true,
    this.showSelectionSummary = true,
    this.height,
    this.emptyStateMessage,
    this.showFilters = false,
    this.showTreeNavigation = false,
    this.preselectedSiteId,
    this.preselectedGroupId,
    this.organismKind = OrganismKind.coral,
  });

  OrganismContext get organismContext => OrganismContext.forKind(organismKind);
  bool get supportsCurrentOrganism => true;
}

/// Reusable wizard for organism selection across all organism operations
///
/// Migration Note: Refactored to use repository pattern instead of GraphBloc traversal.
/// Now fetches organisms directly from OrganismRecordRepository for better performance and
/// alignment with the unified organism data model.
class OrganismSelectionWizard extends StatelessWidget {
  const OrganismSelectionWizard({
    super.key,
    required this.config,
    required this.onSelectionChanged,
  });

  final OrganismSelectionConfig config;
  final void Function(List<OrganismRecord>) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (!config.supportsCurrentOrganism) {
      return _UnsupportedOrganismMessage(organismKind: config.organismKind);
    }

    // Use OrganismRecordRepository exclusively
    final organismRepo = context.read<OrganismRecordRepository>();

    return BlocProvider(
      create: (_) => OrganismSelectionCubit(
        organismRecordRepository: organismRepo,
        siteRepository: context.read<SiteRepository>(),
        groupRepository: context.read<GroupRepository>(),
        config: config,
      ),
      child: BlocListener<OrganismSelectionCubit, OrganismSelectionState>(
        listener: (context, state) {
          onSelectionChanged(
            List<OrganismRecord>.from(state.selectedOrganisms),
          );
        },
        child: _OrganismSelectionWizardView(config: config),
      ),
    );
  }
}

class _UnsupportedOrganismMessage extends StatelessWidget {
  const _UnsupportedOrganismMessage({required this.organismKind});

  final OrganismKind organismKind;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '${organismKind.metadata.displayName} selection will be available soon.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _OrganismSelectionWizardView extends StatefulWidget {
  const _OrganismSelectionWizardView({required this.config});

  final OrganismSelectionConfig config;

  @override
  State<_OrganismSelectionWizardView> createState() =>
      _OrganismSelectionWizardViewState();
}

class _OrganismSelectionWizardViewState
    extends State<_OrganismSelectionWizardView> {
  late final TextEditingController _searchController;
  bool _isUpdatingSearch = false;

  @override
  void initState() {
    super.initState();
    final cubitState = context.read<OrganismSelectionCubit>().state;
    _searchController = TextEditingController(text: cubitState.searchQuery);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_isUpdatingSearch) return;
    context.read<OrganismSelectionCubit>().searchQueryChanged(
      _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrganismSelectionCubit, OrganismSelectionState>(
      builder: (context, cubitState) {
        // Sync search controller with cubit state
        if (_searchController.text != cubitState.searchQuery) {
          _isUpdatingSearch = true;
          _searchController.value = _searchController.value.copyWith(
            text: cubitState.searchQuery,
            selection: TextSelection.collapsed(
              offset: cubitState.searchQuery.length,
            ),
          );
          _isUpdatingSearch = false;
        }

        return _buildWizardContent(context, cubitState);
      },
    );
  }

  Future<T?> _showSelectionDialog<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) itemLabelBuilder,
    T? selectedValue,
    String? emptyMessage,
  }) async {
    if (!context.mounted) return null;

    if (items.isEmpty) {
      if (emptyMessage != null) {
        await showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(emptyMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return null;
    }

    return showDialog<T>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            // ignore: no_leading_underscores_for_local_identifiers
            separatorBuilder: (_context, _index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return RadioListTile<T>(
                value: item,
                // ignore: deprecated_member_use
                groupValue: selectedValue,
                title: Text(itemLabelBuilder(item)),
                // ignore: deprecated_member_use
                onChanged: (_) => Navigator.of(dialogContext).pop(item),
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
  }

  Site? _siteById(OrganismSelectionState state, String? siteId) {
    if (siteId == null) return null;
    try {
      return state.sites.firstWhere((site) => site.id == siteId);
    } catch (_) {
      return null;
    }
  }

  Group? _groupById(OrganismSelectionState state, String? groupId) {
    if (groupId == null) return null;
    try {
      return state.groups.firstWhere((group) => group.id == groupId);
    } catch (_) {
      return null;
    }
  }

  String _siteTypeLabel(OrganismSelectionState state) {
    if (state.selectedSiteType == null) return 'All Site Types';
    final siteType = SiteType.maybeFromId(state.selectedSiteType);
    return siteType?.name ?? 'All Site Types';
  }

  String _siteLabel(OrganismSelectionState state) {
    if (state.selectedSite == null) return 'All Sites';
    final site = _siteById(state, state.selectedSite);
    return site?.name ?? 'All Sites';
  }

  String _groupLabel(OrganismSelectionState state) {
    if (state.selectedGroup == null) return 'All Groups';
    final group = _groupById(state, state.selectedGroup);
    return group?.name ?? 'All Groups';
  }

  String _lifeStageLabel(OrganismRecord organism) {
    final lifeStage = organism.lifeStage;
    if (lifeStage.stage != LifeStage.gamete) {
      return lifeStage.displayName;
    }
    final role = organism.provenanceAttributes.gameteRole;
    if (role == ProvenanceGameteRole.egg) {
      return 'Egg gamete';
    }
    if (role == ProvenanceGameteRole.sperm) {
      return 'Sperm gamete';
    }
    return lifeStage.displayName;
  }

  String _speciesLabel(
    OrganismSelectionState state,
    SpeciesRegistry speciesRegistry,
  ) {
    if (state.selectedSpecies == null) return 'All Species';
    final species = speciesRegistry.byId(state.selectedSpecies);
    return species?.name ?? 'All Species';
  }

  Future<void> _handleSiteTypeFilterSelected(
    BuildContext context,
    OrganismSelectionState state,
    bool selected,
  ) async {
    final cubit = context.read<OrganismSelectionCubit>();
    if (!selected) {
      cubit.siteTypeFilterChanged(null);
      return;
    }

    final uniqueSiteTypes = SiteType.builtins.values.toSet().toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final result = await _showSelectionDialog<SiteType>(
      context: context,
      title: 'Filter by Site Type',
      items: uniqueSiteTypes,
      selectedValue: SiteType.maybeFromId(state.selectedSiteType),
      itemLabelBuilder: (siteType) => siteType.name,
      emptyMessage: 'No site types available.',
    );

    if (!context.mounted || result == null) {
      return;
    }

    cubit.siteTypeFilterChanged(result.id);
  }

  Future<void> _handleSiteFilterSelected(
    BuildContext context,
    OrganismSelectionState state,
    bool selected,
  ) async {
    final cubit = context.read<OrganismSelectionCubit>();
    if (!selected) {
      cubit.siteFilterChanged(null);
      return;
    }

    final selectedSiteType = state.selectedSiteType;
    final filteredSites = state.sites.where((site) {
      if (selectedSiteType == null) return true;
      final canonicalType = SiteType.maybeFromId(site.siteTypeId)?.id;
      return canonicalType == selectedSiteType;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    final site = await _showSelectionDialog<Site>(
      context: context,
      title: 'Filter by Site',
      items: filteredSites,
      selectedValue: _siteById(state, state.selectedSite),
      itemLabelBuilder: (site) => site.name,
      emptyMessage: selectedSiteType != null
          ? 'No sites available for the selected site type.'
          : 'No sites available.',
    );

    if (!context.mounted || site == null) {
      return;
    }

    cubit.siteFilterChanged(site.id);
  }

  Future<void> _handleGroupFilterSelected(
    BuildContext context,
    OrganismSelectionState state,
    bool selected,
  ) async {
    final cubit = context.read<OrganismSelectionCubit>();
    if (!selected) {
      cubit.groupFilterChanged(null);
      return;
    }

    final selectedSiteId = state.selectedSite;
    final selectedSiteTypeId = state.selectedSiteType;

    final filteredGroups = state.groups.where((group) {
      if (selectedSiteId != null && group.siteId != selectedSiteId) {
        return false;
      }
      if (selectedSiteTypeId != null) {
        final site = _siteById(state, group.siteId);
        final siteTypeId = SiteType.maybeFromId(site?.siteTypeId)?.id;
        if (siteTypeId != selectedSiteTypeId) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    final group = await _showSelectionDialog<Group>(
      context: context,
      title: 'Filter by Group',
      items: filteredGroups,
      selectedValue: _groupById(state, state.selectedGroup),
      itemLabelBuilder: (group) => group.name,
      emptyMessage: 'No groups available for the current filters.',
    );

    if (!context.mounted || group == null) {
      return;
    }

    cubit.groupFilterChanged(group.id);
  }

  Future<void> _handleSpeciesFilterSelected(
    BuildContext context,
    OrganismSelectionState state,
    bool selected,
    SpeciesRegistry speciesRegistry,
  ) async {
    final cubit = context.read<OrganismSelectionCubit>();
    if (!selected) {
      cubit.speciesFilterChanged(null);
      return;
    }

    final speciesList = speciesRegistry.all;

    final species = await _showSelectionDialog<Species>(
      context: context,
      title: 'Filter by Species',
      items: speciesList,
      selectedValue: speciesRegistry.byId(state.selectedSpecies),
      itemLabelBuilder: (species) => species.name,
      emptyMessage: 'No species available.',
    );

    if (!context.mounted || species == null) {
      return;
    }

    cubit.speciesFilterChanged(species.id);
  }

  Widget _buildFilterChips(
    BuildContext context,
    OrganismSelectionState state,
    SpeciesRegistry speciesRegistry,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Site Type Filter
        ChoiceChip(
          label: Text(_siteTypeLabel(state)),
          selected: state.selectedSiteType != null,
          onSelected: (selected) {
            _handleSiteTypeFilterSelected(context, state, selected);
          },
        ),
        // Site Filter
        ChoiceChip(
          label: Text(_siteLabel(state)),
          selected: state.selectedSite != null,
          onSelected: (selected) {
            _handleSiteFilterSelected(context, state, selected);
          },
        ),
        // Group Filter
        ChoiceChip(
          label: Text(_groupLabel(state)),
          selected: state.selectedGroup != null,
          onSelected: (selected) {
            _handleGroupFilterSelected(context, state, selected);
          },
        ),
        // Species Filter
        ChoiceChip(
          label: Text(_speciesLabel(state, speciesRegistry)),
          selected: state.selectedSpecies != null,
          onSelected: (selected) {
            _handleSpeciesFilterSelected(
              context,
              state,
              selected,
              speciesRegistry,
            );
          },
        ),
      ],
    );
  }

  Widget _buildWizardContent(
    BuildContext context,
    OrganismSelectionState state,
  ) {
    final speciesRegistry = context.watch<SpeciesRegistry>();
    // Dropdown mode
    if (widget.config.mode == OrganismSelectionMode.dropdown) {
      final selectedCoral = state.selectedOrganisms.isNotEmpty
          ? state.selectedOrganisms.first
          : null;
      return DropdownButtonFormField<OrganismRecord>(
        key: ValueKey('coral-dropdown-${selectedCoral?.id ?? 'none'}'),
        decoration: InputDecoration(
          labelText: widget.config.label,
          hintText: widget.config.hintText,
          border: const OutlineInputBorder(),
        ),
        initialValue: selectedCoral,
        items: state.filteredOrganisms.map((organism) {
          final species = speciesRegistry.byId(organism.speciesId);
          return DropdownMenuItem(
            value: organism,
            child: Text('${organism.name} (${species?.name ?? 'Unknown'})'),
          );
        }).toList(),
        onChanged: (organism) {
          if (organism != null) {
            context.read<OrganismSelectionCubit>().toggleOrganismSelection(
              organism,
              widget.config.mode,
            );
          }
        },
      );
    }

    // List/Grid mode
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.config.label != null) ...[
            UIText.bodyMedium(widget.config.label!),
            UI.spacingVerticalSm,
          ],

          // Search field
          if (widget.config.showSearch) ...[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText:
                    'Search ${widget.config.organismKind.metadata.displayName.toLowerCase()}s',
                hintText: 'Name, ID, clonal ID, accession, or alias',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            UI.spacingVerticalMd,
          ],

          // Filters
          if (widget.config.showFilters) ...[
            _buildFilterChips(context, state, speciesRegistry),
            UI.spacingVerticalMd,
          ],

          // Loading state
          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),

          // Error state
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<OrganismSelectionCubit>().loadOrganisms(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // Coral list
          if (!state.isLoading && state.error == null) ...[
            Container(
              height: widget.config.height ?? 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: state.filteredOrganisms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          widget.config.emptyStateMessage ??
                              (state.searchQuery.isNotEmpty
                                  ? 'No ${widget.config.organismKind.metadata.displayName.toLowerCase()}s match your search'
                                  : 'No available ${widget.config.organismKind.metadata.displayName.toLowerCase()}s'),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.filteredOrganisms.length,
                      itemBuilder: (context, index) {
                        final organism = state.filteredOrganisms[index];
                        final species = speciesRegistry.byId(
                          organism.speciesId,
                        );
                        final isSelected = state.selectedOrganisms.any(
                          (c) => c.id == organism.id,
                        );

                        return ListTile(
                          leading:
                              widget.config.mode ==
                                  OrganismSelectionMode.multiple
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => context
                                      .read<OrganismSelectionCubit>()
                                      .toggleOrganismSelection(
                                        organism,
                                        widget.config.mode,
                                      ),
                                )
                              : Icon(
                                  Icons.scatter_plot,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                          title: Text(
                            organism.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                        ),
                          subtitle: Text(
                            '${species?.name ?? 'Unknown species'} • ${_lifeStageLabel(organism)}',
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          selected: isSelected,
                          onTap: () => context
                              .read<OrganismSelectionCubit>()
                              .toggleOrganismSelection(
                                organism,
                                widget.config.mode,
                              ),
                        );
                      },
                    ),
            ),
          ],

          // Selection summary
          if (widget.config.showSelectionSummary &&
              state.selectedOrganisms.isNotEmpty) ...[
            UI.spacingVerticalMd,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${state.selectedOrganisms.length} ${widget.config.organismKind.metadata.displayName.toLowerCase()}${state.selectedOrganisms.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
}
