// @tier: community
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/cubits/organism_selection/organism_selection_state.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/wizards/organism_selection_wizard.dart';

class OrganismSelectionCubit extends SafeCubit<OrganismSelectionState> {
  OrganismSelectionCubit({
    required OrganismRecordRepository organismRecordRepository,
    required SiteRepository siteRepository,
    required GroupRepository groupRepository,
    required OrganismSelectionConfig config,
  }) : _organismRecordRepository = organismRecordRepository,
       _siteRepository = siteRepository,
       _groupRepository = groupRepository,
       _config = config,
       super(const OrganismSelectionState()) {
    _loadInitialData();
  }

  final OrganismRecordRepository _organismRecordRepository;
  final SiteRepository _siteRepository;
  final GroupRepository _groupRepository;
  final OrganismSelectionConfig _config;

  /// Request ID counter to prevent stale async responses from overwriting newer data.
  int _loadRequestId = 0;

  void _loadInitialData() {
    final initialSelection = _config.initialSelection ?? [];
    final preselectedSite = _config.preselectedSiteId;
    final preselectedGroup = _config.preselectedGroupId;

    emit(
      state.copyWith(
        selectedOrganisms: List.from(initialSelection),
        selectedSite: preselectedSite,
        selectedGroup: preselectedGroup,
      ),
    );

    loadOrganisms();
  }

  Future<void> loadOrganisms() async {
    // Increment request ID to track this load request
    final requestId = ++_loadRequestId;

    emit(state.copyWith(isLoading: true, error: null, clearError: true));

    try {
      // Fetch organisms and filter for configured kind
      final organisms = await _organismRecordRepository.getAll();

      // Guard against stale responses
      if (isClosed || requestId != _loadRequestId) return;
      final targetOrganisms = organisms
          .where((o) => o.organismKind == _config.organismKind)
          .toList();

      // Apply ID filters
      final allowedIds = _config.allowedOrganismRecordIds;
      final excludedIds = _config.excludedOrganismRecordIds;

      var filteredOrganisms = targetOrganisms;
      if (allowedIds != null && allowedIds.isNotEmpty) {
        filteredOrganisms = filteredOrganisms
            .where((organism) => allowedIds.contains(organism.id))
            .toList();
      }

      if (excludedIds != null && excludedIds.isNotEmpty) {
        filteredOrganisms = filteredOrganisms
            .where((organism) => !excludedIds.contains(organism.id))
            .toList();
      }

      // Load filter data if needed
      List<Site> sites = [];
      List<Group> groups = [];
      if (_config.showFilters) {
        sites = List<Site>.from(await _siteRepository.getAll())
          ..sort((a, b) => a.name.compareTo(b.name));

        // Guard against stale responses
        if (isClosed || requestId != _loadRequestId) return;

        groups = List<Group>.from(await _groupRepository.getAll())
          ..sort((a, b) => a.name.compareTo(b.name));

        // Guard against stale responses
        if (isClosed || requestId != _loadRequestId) return;
      }

      emit(
        state.copyWith(
          allOrganisms: filteredOrganisms,
          sites: sites,
          groups: groups,
          isLoading: false,
        ),
      );

      applyFilters();
    } catch (e, st) {
      // Guard against stale responses on error path as well
      if (isClosed || requestId != _loadRequestId) return;

      LoggingService.instance.error('Failed to load organisms', e, st);
      emit(
        state.copyWith(
          error: 'Failed to load organisms: ${e.toString()}',
          isLoading: false,
        ),
      );
    }
  }

  void searchQueryChanged(String query) {
    emit(state.copyWith(searchQuery: query));
    applyFilters();
  }

  void siteTypeFilterChanged(String? siteTypeId) {
    String? newSite;
    String? newGroup;

    if (siteTypeId != null) {
      final currentSite = _siteById(state.selectedSite);
      final currentSiteType = SiteType.maybeFromId(currentSite?.siteTypeId)?.id;
      if (currentSiteType != siteTypeId) {
        newSite = null;
        newGroup = null;
      } else {
        final currentGroup = _groupById(state.selectedGroup);
        if (currentGroup != null && currentGroup.siteId != currentSite?.id) {
          newGroup = null;
        }
      }
    }

    emit(
      state.copyWith(
        selectedSiteType: siteTypeId,
        selectedSite: newSite ?? state.selectedSite,
        selectedGroup: newGroup ?? state.selectedGroup,
      ),
    );
    applyFilters();
  }

  void siteFilterChanged(String? siteId) {
    String? newGroup;
    if (siteId != null) {
      final currentGroup = _groupById(state.selectedGroup);
      if (currentGroup == null || currentGroup.siteId != siteId) {
        newGroup = null;
      }
    }

    emit(
      state.copyWith(
        selectedSite: siteId,
        selectedGroup: newGroup ?? state.selectedGroup,
      ),
    );
    applyFilters();
  }

  void groupFilterChanged(String? groupId) {
    emit(state.copyWith(selectedGroup: groupId));
    applyFilters();
  }

  void speciesFilterChanged(String? speciesId) {
    emit(state.copyWith(selectedSpecies: speciesId));
    applyFilters();
  }

  void toggleOrganismSelection(
    OrganismRecord organism,
    OrganismSelectionMode mode,
  ) {
    List<OrganismRecord> newSelection;
    if (mode == OrganismSelectionMode.single) {
      newSelection = [organism];
    } else {
      newSelection = List.from(state.selectedOrganisms);
      if (newSelection.any((o) => o.id == organism.id)) {
        newSelection.removeWhere((o) => o.id == organism.id);
      } else {
        newSelection.add(organism);
      }
    }
    emit(state.copyWith(selectedOrganisms: newSelection));
  }

  void applyFilters() {
    var filtered = state.allOrganisms;

    // Apply search filter
    if (state.searchQuery.isNotEmpty) {
      filtered = filtered.where((organism) {
        final species = SpeciesRegistry.globalById(organism.speciesId);
        final query = state.searchQuery.toLowerCase();
        final name = organism.name;
        return name.toLowerCase().contains(query) ||
            organism.id.toLowerCase().contains(query) ||
            (species?.name.toLowerCase().contains(query) ?? false) ||
            _matchesProvenanceFields(organism, query);
      }).toList();
    }

    // Apply site filter
    if (state.selectedSite != null) {
      filtered = filtered
          .where((organism) => organism.siteId == state.selectedSite)
          .toList();
    }

    // Apply group filter
    if (state.selectedGroup != null) {
      filtered = filtered
          .where((organism) => organism.groupId == state.selectedGroup)
          .toList();
    }

    // Apply species filter
    if (state.selectedSpecies != null) {
      filtered = filtered
          .where((organism) => organism.speciesId == state.selectedSpecies)
          .toList();
    }

    // Apply site type filter
    if (state.selectedSiteType != null) {
      filtered = filtered.where((organism) {
        final site = _siteById(organism.siteId);
        if (site == null) {
          return false;
        }
        final siteTypeId = SiteType.maybeFromId(site.siteTypeId)?.id;
        return siteTypeId == state.selectedSiteType;
      }).toList();
    }

    emit(state.copyWith(filteredOrganisms: filtered));
  }

  /// Checks if the organism matches provenance-related search fields.
  /// Searches: localId (clonal ID), genetId, aliases, and foreignKeys['genetId'].
  bool _matchesProvenanceFields(OrganismRecord organism, String query) {
    // Check localId (clonal ID / genet identifier)
    final localId = organism.localId?.toLowerCase();
    if (localId != null && localId.contains(query)) {
      return true;
    }

    // Check genetId (reference to Genet record)
    final genetId = organism.genetId?.toLowerCase();
    if (genetId != null && genetId.contains(query)) {
      return true;
    }

    // Check aliases (includes accession numbers and other identifiers)
    for (final alias in organism.aliases) {
      if (alias.value.toLowerCase().contains(query)) {
        return true;
      }
      final label = alias.label?.toLowerCase();
      if (label != null && label.contains(query)) {
        return true;
      }
    }

    // Check foreignKeys['genetId'] for legacy data
    final foreignGenetId = organism.foreignKeys['genetId']?.id.toLowerCase();
    if (foreignGenetId != null && foreignGenetId.contains(query)) {
      return true;
    }

    return false;
  }

  Site? _siteById(String? siteId) {
    if (siteId == null) return null;
    try {
      return state.sites.firstWhere((site) => site.id == siteId);
    } catch (_) {
      return null;
    }
  }

  Group? _groupById(String? groupId) {
    if (groupId == null) return null;
    try {
      return state.groups.firstWhere((group) => group.id == groupId);
    } catch (_) {
      return null;
    }
  }
}
