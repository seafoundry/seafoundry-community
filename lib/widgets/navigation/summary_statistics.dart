// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_card_filter.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_filter_matcher.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_statistics_cubit.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_statistics_state.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/dialogs/filtered_organism_list_sheet.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/toolbar_dropdown.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';

/// Community-tier summary statistics widget showing organism inventory counts.
///
/// **Features:**
/// - Shows inventory counts: total organisms and unique genotypes
/// - Filter dropdowns: species, local ID (genet), site, and structure
/// - Filters apply instantly without data reload (cached organism list)
///
/// **Architecture:**
/// - Uses `SummaryStatisticsCubit` for filter state management
/// - Organization level: loads organism data once, filters synchronously on state changes
/// - Sub-node level: uses StreamBuilder for real-time data, extracts filter options per emission
class SummaryStatistics extends StatelessWidget {
  const SummaryStatistics({
    super.key,
    required this.node,
    this.organismStats,
  });

  final GraphNode node;
  final OrganismStatistics? organismStats;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SummaryStatisticsCubit(),
      child: _SummaryStatisticsView(
        node: node,
        organismStats: organismStats,
      ),
    );
  }
}

/// Internal stateful view that caches organism data and applies filters synchronously.
///
/// **Data Flow:**
/// 1. On init: resolves site/group label maps, loads organism data (org path only)
/// 2. On filter change: BlocBuilder rebuilds, filters applied synchronously from cache
/// 3. No FutureBuilder inside BlocBuilder — eliminates loading flash on filter changes
class _SummaryStatisticsView extends StatefulWidget {
  const _SummaryStatisticsView({
    required this.node,
    this.organismStats,
  });

  final GraphNode node;
  final OrganismStatistics? organismStats;

  @override
  State<_SummaryStatisticsView> createState() => _SummaryStatisticsViewState();
}

class _SummaryStatisticsViewState extends State<_SummaryStatisticsView> {
  static const Duration _summaryOrganismGetAllTimeout = Duration(seconds: 4);
  static const int _summaryOrganismFallbackThreshold = 50;

  // Cached organism data for organization-level view (loaded once)
  List<OrganismRecord>? _cachedOrganisms;
  SummaryFilterOptions? _cachedFilterOptions;
  bool _isOrgDataLoading = false;
  String? _orgDataError;

  // Cached label maps resolved once from repositories
  Map<String, String> _siteLabels = const {};
  Map<String, String> _groupLabels = const {};

  bool _didInit = false;

  GraphNodeRecord? _getRecord(GraphNode node) => node.state is GraphLoadedState
      ? (node.state as GraphLoadedState).record
      : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _initializeData();
    }
  }

  /// One-time initialization: resolve label maps, then load organism data for org path.
  Future<void> _initializeData() async {
    await _resolveLabelMaps();

    final record = _getRecord(widget.node);
    if (record is Organization) {
      await _loadOrganismData();
    }
  }

  /// Resolves site/group display name maps from repositories.
  /// BehaviorSubject streams typically resolve immediately from cache.
  Future<void> _resolveLabelMaps() async {
    SiteRepository? siteRepo;
    GroupRepository? groupRepo;
    try {
      siteRepo = context.read<SiteRepository>();
    } catch (_) {
      // SiteRepository not in widget tree
    }
    try {
      groupRepo = context.read<GroupRepository>();
    } catch (_) {
      // GroupRepository not in widget tree
    }

    final siteLabelMap = <String, String>{};
    final groupLabelMap = <String, String>{};

    if (siteRepo != null) {
      try {
        final sites = await siteRepo.streamAll.first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => <Site>[],
        );
        for (final site in sites) {
          siteLabelMap[site.id] = site.name;
        }
      } catch (_) {
        // Timeout; IDs used as fallback labels
      }
    }

    if (groupRepo != null) {
      try {
        final groups = await groupRepo.streamAll.first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => <Group>[],
        );
        for (final group in groups) {
          groupLabelMap[group.id] = group.name;
        }
      } catch (_) {
        // Timeout; IDs used as fallback labels
      }
    }

    if (mounted) {
      setState(() {
        _siteLabels = siteLabelMap;
        _groupLabels = groupLabelMap;
      });
    }
  }

  /// Loads organism data once for the organization-level view.
  Future<void> _loadOrganismData() async {
    setState(() {
      _isOrgDataLoading = true;
      _orgDataError = null;
    });

    try {
      final orgRepo = context.read<OrganismRecordRepository>();
      final allOrganisms = await _initialOrganismSnapshot(orgRepo);
      final inventory = allOrganisms
          .where((o) => !_isExcludedFromInventoryCounts(siteId: o.siteId ?? ''))
          .toList(growable: false);

      final options = _buildFilterOptions(inventory);

      if (mounted) {
        setState(() {
          _cachedOrganisms = inventory;
          _cachedFilterOptions = options;
          _isOrgDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _orgDataError = e.toString();
          _isOrgDataLoading = false;
        });
      }
    }
  }

  /// Builds filter options synchronously using cached label maps.
  SummaryFilterOptions _buildFilterOptions(List<OrganismRecord> organisms) {
    final siteIds = <String>{};
    final speciesIds = <String>{};
    final genetIds = <String>{};
    final structureIds = <String>{};

    for (final organism in organisms) {
      final siteId = organism.siteId?.trim();
      if (siteId != null && siteId.isNotEmpty) siteIds.add(siteId);
      final speciesId = organism.speciesId?.trim();
      if (speciesId != null && speciesId.isNotEmpty) speciesIds.add(speciesId);
      final genetId = GenetIdResolver.resolve(organism)?.trim();
      if (genetId != null && genetId.isNotEmpty) genetIds.add(genetId);
      final groupId = organism.groupId?.trim();
      if (groupId != null && groupId.isNotEmpty) structureIds.add(groupId);
    }

    final speciesLabels = <String, String>{};
    for (final id in speciesIds) {
      final species = SpeciesRegistry.globalById(id);
      speciesLabels[id] = species?.name ?? id;
    }

    // Genet labels: use the localGenetId from the first organism with that genet
    final genetLabels = <String, String>{};
    for (final organism in organisms) {
      final genetId = GenetIdResolver.resolve(organism)?.trim();
      if (genetId != null && genetId.isNotEmpty && !genetLabels.containsKey(genetId)) {
        genetLabels[genetId] = organism.localGenetId ?? genetId;
      }
    }

    // Use cached label maps for site/group display names
    final siteLabels = <String, String>{};
    for (final id in siteIds) {
      siteLabels[id] = _siteLabels[id] ?? id;
    }

    final structureLabels = <String, String>{};
    for (final id in structureIds) {
      structureLabels[id] = _groupLabels[id] ?? id;
    }

    return SummaryFilterOptions(
      siteIds: siteIds.toList()..sort((a, b) =>
        (siteLabels[a] ?? a).compareTo(siteLabels[b] ?? b)),
      speciesIds: speciesIds.toList()..sort((a, b) =>
        (speciesLabels[a] ?? a).compareTo(speciesLabels[b] ?? b)),
      genetIds: genetIds.toList()..sort((a, b) =>
        (genetLabels[a] ?? a).compareTo(genetLabels[b] ?? b)),
      structureIds: structureIds.toList()..sort((a, b) =>
        (structureLabels[a] ?? a).compareTo(structureLabels[b] ?? b)),
      speciesLabels: speciesLabels,
      genetLabels: genetLabels,
      siteLabels: siteLabels,
      structureLabels: structureLabels,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SummaryStatisticsCubit, SummaryStatisticsState>(
      builder: (context, filterState) {
        final record = _getRecord(widget.node);
        if (record is Organization) {
          return _buildOrganizationView(context, filterState);
        }
        return _buildSubNodeView(context, filterState);
      },
    );
  }

  /// Organization-level: renders from cached data, filters applied synchronously.
  Widget _buildOrganizationView(
    BuildContext context,
    SummaryStatisticsState filterState,
  ) {
    if (_isOrgDataLoading) return _buildLoadingStats();
    if (_orgDataError != null) return _buildErrorStats(_orgDataError!);

    final organisms = _cachedOrganisms;
    if (organisms == null) return _buildLoadingStats();

    // Apply multiselect filters synchronously from cached data.
    // Health filtering is handled inside _summarizeOrganisms only.
    final filtered = organisms.where(
      (o) => SummaryFilterMatcher.matches(o, filterState),
    );
    final stats = _summarizeOrganisms(filtered, filterState);
    final options = _cachedFilterOptions ?? _buildFilterOptions(organisms);
    return _buildStatsDisplay(context, stats.withFilterOptions(options), filterState);
  }

  /// Sub-node level: uses StreamBuilder for real-time data with sync filter extraction.
  Widget _buildSubNodeView(
    BuildContext context,
    SummaryStatisticsState filterState,
  ) {
    return BlocBuilder<GraphNode, GraphNodeState>(
      bloc: widget.node,
      builder: (context, _) {
        final record = _getRecord(widget.node);
        if (record == null) return _buildLoadingStats();

        if (record is OrganismRecord) {
          final stats = _summarizeOrganisms([record], filterState);
          return _buildStatsDisplay(context, stats, filterState);
        }

        final organismRecordRepository = context.read<OrganismRecordRepository>();
        final stream = organismRecordRepository.streamRecordsForUrlPath(
          record.urlPath,
        );

        return StreamBuilder<List<OrganismRecord>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                (snapshot.data == null || snapshot.data!.isEmpty)) {
              return _buildLoadingStats();
            }
            final allOrganisms = (snapshot.data ?? const <OrganismRecord>[])
                .where((o) => !_isExcludedFromInventoryCounts(siteId: o.siteId ?? ''))
                .toList();
            // Apply multiselect filters; health handled in _summarizeOrganisms
            final filtered = allOrganisms.where(
              (o) => SummaryFilterMatcher.matches(o, filterState),
            );
            final stats = _summarizeOrganisms(filtered, filterState);
            final options = _buildFilterOptions(allOrganisms);
            return _buildStatsDisplay(
              context,
              stats.withFilterOptions(options),
              filterState,
            );
          },
        );
      },
    );
  }

  /// Attempts to obtain the first organism snapshot with a short timeout.
  ///
  /// Note: The BehaviorSubject is seeded with an empty list, so we need to skip
  /// the initial empty emission and wait for actual Firestore data. If no data
  /// arrives within the timeout, return an empty list to avoid heavy getAll().
  Future<List<OrganismRecord>> _initialOrganismSnapshot(
    OrganismRecordRepository organismRecordRepository,
  ) async {
    try {
      // First, get whatever is in the stream (might be seeded empty list)
      final firstEmission = await organismRecordRepository.streamAll.first.timeout(
        const Duration(seconds: 1),
      );

      // If we got actual data, return it
      if (firstEmission.isNotEmpty) {
        if (firstEmission.length < _summaryOrganismFallbackThreshold) {
          try {
            final fetched = await organismRecordRepository
                .getAll()
                .timeout(
                  _summaryOrganismGetAllTimeout,
                  onTimeout: () => firstEmission,
                );
            if (fetched.length > firstEmission.length) {
              LoggingService.instance.warning(
                'SummaryStatistics: stream snapshot returned ${firstEmission.length} '
                'organisms; getAll fetched ${fetched.length}. Using getAll fallback.',
              );
              return fetched;
            }
          } catch (error, stackTrace) {
            LoggingService.instance.warning(
              'SummaryStatistics: getAll fallback failed; using stream snapshot',
              error,
            );
            LoggingService.instance.error(
              'SummaryStatistics getAll fallback error',
              error,
              stackTrace,
            );
          }
        }
        return firstEmission;
      }

      // If empty, wait for a non-empty emission (real Firestore data)
      // This handles the BehaviorSubject seeded empty list case
      return await organismRecordRepository.streamAll
          .firstWhere((list) => list.isNotEmpty)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => firstEmission,
          );
    } on TimeoutException catch (e, stackTrace) {
      LoggingService.instance.warning(
        'SummaryStatistics: organism stream timeout waiting for initial snapshot; '
        'using empty list to avoid heavy getAll() (${e.runtimeType})',
      );
      LoggingService.instance.debug(
        'SummaryStatistics timeout stackTrace: $stackTrace',
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'SummaryStatistics: Failed to read organism stream snapshot',
        error,
        stackTrace,
      );
    }

    return const <OrganismRecord>[];
  }

  /// Checks if a site should be excluded from active inventory counts.
  ///
  /// Outplanting sites and monitoring-only sites (baseline, reference) have
  /// their own separate holdings views and should not inflate active inventory
  /// totals.
  bool _isExcludedFromInventoryCounts({required String siteId}) {
    if (siteId.isEmpty) return false;
    final normalized = siteId.toLowerCase();
    return normalized.startsWith('outplant_') ||
        normalized.startsWith('op-') ||
        normalized.startsWith('baseline') ||
        normalized.startsWith('reference') ||
        normalized.startsWith('ref-') ||
        normalized.startsWith('bl-');
  }

  /// Summarizes organism statistics from a collection of organisms.
  ///
  /// Callers should apply `SummaryFilterMatcher.matches()` before passing organisms.
  /// Health filtering (`_includeByHealth`) is applied internally — do NOT pre-filter.
  OrganismStatistics _summarizeOrganisms(
    Iterable<OrganismRecord> organisms,
    SummaryStatisticsState filterState,
  ) {
    int totalOrganisms = 0;
    int totalOrganismRecords = 0;
    int readyForOutplant = 0;
    int readyForOutplantRecords = 0;
    int readyForPropagation = 0;
    int readyForPropagationRecords = 0;
    int healthIssues = 0;
    int healthIssuesRecords = 0;

    final statusCounts = <String, int>{};

    // Apply health filtering and materialize
    final filteredOrganismList = organisms
        .where((organism) => _includeByHealth(organism, filterState))
        .toList(growable: false);

    // Calculate unique genotypes
    final uniqueGenotypes = filteredOrganismList
        .map((o) => GenetIdResolver.resolve(o))
        .where((id) => id != null)
        .map((id) => id!)
        .toSet()
        .length;

    // Iterate through organisms to calculate quantities and categorize
    for (final organism in filteredOrganismList) {
      final quantity = _organismQuantity(organism);
      totalOrganisms += quantity;
      totalOrganismRecords += 1;

      // Track status breakdown
      final status = organism.healthStatus;
      statusCounts.update(
        status.displayName,
        (prev) => prev + quantity,
        ifAbsent: () => quantity,
      );

      // Apply health categorization
      final isHealthy = status == HealthStatus.healthy;
      if (filterState.onlyIssues) {
        if (!isHealthy) {
          healthIssues += quantity;
          healthIssuesRecords += 1;
        }
        continue;
      }
      if (filterState.selectedHealth != null && status != filterState.selectedHealth) {
        continue;
      }

      // Categorize organisms
      if (isHealthy) {
        if (_isReadyForOutplant(organism)) {
          readyForOutplant += quantity;
          readyForOutplantRecords += 1;
        }
        if (_isReadyForPropagation(organism)) {
          readyForPropagation += quantity;
          readyForPropagationRecords += 1;
        }
      } else {
        healthIssues += quantity;
        healthIssuesRecords += 1;
      }
    }

    return OrganismStatistics(
      totalOrganisms: totalOrganisms,
      totalOrganismRecords: totalOrganismRecords,
      readyForOutplant: readyForOutplant,
      readyForOutplantRecords: readyForOutplantRecords,
      readyForPropagation: readyForPropagation,
      readyForPropagationRecords: readyForPropagationRecords,
      healthIssues: healthIssues,
      healthIssuesRecords: healthIssuesRecords,
      statusBreakdown: statusCounts,
      filterSignature: filterState.filterSignature,
      uniqueGenotypes: uniqueGenotypes > 0 ? uniqueGenotypes : null,
    );
  }

  Widget _buildLoadingStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Build error state for stats.
  Widget _buildErrorStats(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Center(child: Text('Error loading stats: $error')),
    );
  }

  /// Renders the full stats module for given OrganismStatistics.
  Widget _buildStatsDisplay(
    BuildContext context,
    OrganismStatistics stats,
    SummaryStatisticsState filterState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (stats.filterOptions != null) ...[
            const SizedBox(height: 8),
            _buildFilterRow(context, stats.filterOptions!, filterState),
          ],
          const SizedBox(height: 12),
          _buildInventoryStats(context, stats, filterState),
        ],
      ),
    );
  }

  /// Builds the filter row with dropdown selectors for species, local ID, site, and structure.
  /// Dropdowns are single-select; the cubit's set-based state wraps single values.
  Widget _buildFilterRow(
    BuildContext context,
    SummaryFilterOptions options,
    SummaryStatisticsState filterState,
  ) {
    final cubit = context.read<SummaryStatisticsCubit>();

    // Convert set-based filter state to single-value for dropdowns
    final selectedSpecies = filterState.selectedSpeciesIds.length == 1
        ? filterState.selectedSpeciesIds.first
        : null;
    final selectedGenet = filterState.selectedGenetIds.length == 1
        ? filterState.selectedGenetIds.first
        : null;
    final selectedSite = filterState.selectedSiteIds.length == 1
        ? filterState.selectedSiteIds.first
        : null;
    final selectedStructure = filterState.selectedStructureIds.length == 1
        ? filterState.selectedStructureIds.first
        : null;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (options.speciesIds.length > 1)
          ToolbarDropdown(
            width: 200,
            label: 'Species',
            value: selectedSpecies,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Species'),
              ),
              ...options.speciesIds.map(
                (id) => DropdownMenuItem<String?>(
                  value: id,
                  child: Text(
                    options.speciesLabels[id] ?? id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => cubit.speciesFilterChanged(
              value != null ? {value} : const {},
            ),
          ),
        if (options.genetIds.length > 1)
          ToolbarDropdown(
            width: 180,
            label: 'Local ID',
            value: selectedGenet,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Local IDs'),
              ),
              ...options.genetIds.map(
                (id) => DropdownMenuItem<String?>(
                  value: id,
                  child: Text(
                    options.genetLabels[id] ?? id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => cubit.genetFilterChanged(
              value != null ? {value} : const {},
            ),
          ),
        if (options.siteIds.length > 1)
          ToolbarDropdown(
            width: 180,
            label: 'Site',
            value: selectedSite,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Sites'),
              ),
              ...options.siteIds.map(
                (id) => DropdownMenuItem<String?>(
                  value: id,
                  child: Text(
                    options.siteLabels[id] ?? id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => cubit.siteFilterChanged(
              value != null ? {value} : const {},
            ),
          ),
        if (options.structureIds.length > 1)
          ToolbarDropdown(
            width: 180,
            label: 'Structure',
            value: selectedStructure,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Structures'),
              ),
              ...options.structureIds.map(
                (id) => DropdownMenuItem<String?>(
                  value: id,
                  child: Text(
                    options.structureLabels[id] ?? id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => cubit.structureFilterChanged(
              value != null ? {value} : const {},
            ),
          ),
        if (filterState.hasActiveFilters)
          TextButton.icon(
            onPressed: () => cubit.clearAllFilters(),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
          ),
      ],
    );
  }

  Widget _buildInventoryStats(
    BuildContext context,
    OrganismStatistics stats,
    SummaryStatisticsState filterState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total organisms
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Total Organisms',
                stats.totalOrganisms.toString(),
                AppColors.primary,
                Icons.circle,
                detailText: 'Records: ${stats.totalOrganismRecords}',
                onTap: stats.totalOrganismRecords > 0
                    ? () => _showFilteredList(
                          context,
                          filterState,
                          SummaryCardFilter.totalOrganisms,
                          'Total Organisms',
                          stats.totalOrganisms,
                          recordCount: stats.totalOrganismRecords,
                        )
                    : null,
              ),
            ),
            if (stats.uniqueGenotypes != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Unique Genotypes',
                  stats.uniqueGenotypes.toString(),
                  AppColors.primary,
                  Icons.category,
                  onTap: stats.uniqueGenotypes! > 0
                      ? () => _showFilteredList(
                            context,
                            filterState,
                            SummaryCardFilter.byGenotype,
                            'Unique Genotypes',
                            stats.uniqueGenotypes!,
                          )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon, {
    String? detailText,
    VoidCallback? onTap,
  }) {
    Widget card = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (detailText != null) ...[
            const SizedBox(height: 2),
            Text(
              detailText,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: card,
        ),
      );
    }
    return card;
  }

  /// Shows the filtered organism list sheet for a given filter.
  void _showFilteredList(
    BuildContext context,
    SummaryStatisticsState filterState,
    SummaryCardFilter filter,
    String title,
    int inventoryCount, {
    int? recordCount,
  }) {
    final record = _getRecord(widget.node);
    if (record == null) return;

    // Capture NavigationCubit before showing modal to avoid context issues after pop
    final navigationCubit = context.read<NavigationCubit>();

    FilteredOrganismListSheet.show(
      context,
      filter: filter,
      urlPath: record.urlPath,
      title: title,
      inventoryCount: inventoryCount,
      recordCount: recordCount,
      filterState: filterState,
      isOutplantingSite: (siteId) => _isExcludedFromInventoryCounts(siteId: siteId),
      onRecordSelected: (organism) {
        LoggingService.instance.info('SummaryStatistics: Organism selected - ${organism.localGenetId ?? organism.slug}');
        LoggingService.instance.info('SummaryStatistics: Navigating to urlPath: ${organism.urlPath}');
        // Note: Bottom sheet pops itself using its own context before invoking this callback
        if (!navigationCubit.isClosed) {
          LoggingService.instance.info('SummaryStatistics: NavigationCubit is open, calling navigateToPath');
          navigationCubit.navigateToPath(organism.urlPath);
        } else {
          LoggingService.instance.warning('SummaryStatistics: NavigationCubit is closed!');
        }
      },
    );
  }

  /// Get numeric quantity represented by an organism record
  int _organismQuantity(OrganismRecord organism) {
    final count = organism.inventoryMetrics.count;
    if (count != null) {
      return count;
    }
    if (organism.measurement.unit.category == MeasurementUnitCategory.count) {
      return organism.measurement.value.toInt();
    }
    return 1;
  }

  /// Determine if organism is ready for outplanting
  bool _isReadyForOutplant(OrganismRecord organism) {
    if (_isExcludedFromInventoryCounts(siteId: organism.siteId ?? '')) {
      return false;
    }
    return organism.readyForOutplant;
  }

  /// Determine if organism is ready for propagation
  bool _isReadyForPropagation(OrganismRecord organism) {
    return organism.readyForPropagation && organism.healthStatus == HealthStatus.healthy;
  }

  /// Determine if organism should be included based on health filters
  bool _includeByHealth(OrganismRecord organism, SummaryStatisticsState filterState) {
    final healthStatus = organism.healthStatus;
    if (filterState.onlyIssues) {
      return healthStatus != HealthStatus.healthy;
    }
    if (filterState.selectedHealth == null) {
      return true;
    }
    return healthStatus == filterState.selectedHealth;
  }
}

/// Data transfer object for organism inventory statistics.
class OrganismStatistics {
  const OrganismStatistics({
    required this.totalOrganisms,
    required this.totalOrganismRecords,
    required this.readyForOutplant,
    required this.readyForOutplantRecords,
    required this.readyForPropagation,
    required this.readyForPropagationRecords,
    required this.healthIssues,
    required this.healthIssuesRecords,
    required this.statusBreakdown,
    this.filterSignature,
    this.uniqueGenotypes,
    this.filterOptions,
  });

  final int totalOrganisms;
  final int totalOrganismRecords;
  final int readyForOutplant;
  final int readyForOutplantRecords;
  final int readyForPropagation;
  final int readyForPropagationRecords;
  final int healthIssues;
  final int healthIssuesRecords;
  final Map<String, int> statusBreakdown;
  final String? filterSignature;
  final int? uniqueGenotypes;
  final SummaryFilterOptions? filterOptions;

  /// Returns a copy with filter options attached.
  OrganismStatistics withFilterOptions(SummaryFilterOptions options) {
    return OrganismStatistics(
      totalOrganisms: totalOrganisms,
      totalOrganismRecords: totalOrganismRecords,
      readyForOutplant: readyForOutplant,
      readyForOutplantRecords: readyForOutplantRecords,
      readyForPropagation: readyForPropagation,
      readyForPropagationRecords: readyForPropagationRecords,
      healthIssues: healthIssues,
      healthIssuesRecords: healthIssuesRecords,
      statusBreakdown: statusBreakdown,
      filterSignature: filterSignature,
      uniqueGenotypes: uniqueGenotypes,
      filterOptions: options,
    );
  }
}

/// Available filter options extracted from organism data for dropdown population.
class SummaryFilterOptions {
  const SummaryFilterOptions({
    required this.siteIds,
    required this.speciesIds,
    required this.genetIds,
    required this.structureIds,
    required this.siteLabels,
    required this.speciesLabels,
    required this.genetLabels,
    required this.structureLabels,
  });

  final List<String> siteIds;
  final List<String> speciesIds;
  final List<String> genetIds;
  final List<String> structureIds;
  final Map<String, String> siteLabels;
  final Map<String, String> speciesLabels;
  final Map<String, String> genetLabels;
  final Map<String, String> structureLabels;
}
