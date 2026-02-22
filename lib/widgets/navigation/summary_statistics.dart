// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_card_filter.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_statistics_cubit.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_statistics_state.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/dialogs/filtered_organism_list_sheet.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';

/// Community-tier summary statistics widget showing organism inventory counts.
///
/// **Features:**
/// - Shows inventory counts: total organisms and unique genotypes
/// - Pro features displayed as disabled: ready for outplant, ready for propagation, health issues
///   (shown as "N/A" with "Upgrade to Pro" messaging)
/// - No health filters (community tier limitation)
/// - No volume calculations (community tier)
/// - No task tracking (community tier)
///
/// **Architecture:**
/// - Uses `SummaryStatisticsCubit` for state management
/// - Calculates statistics from organism data streamed from `OrganismRecordRepository`
/// - Pro features display greyed-out placeholders with upgrade messaging
///
/// **Performance:**
/// - Uses streams for real-time organism data updates
/// - Statistics calculated on-demand from filtered organism lists
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

/// Internal view widget that handles the actual statistics display logic.
///
/// **Data Flow:**
/// 1. Determines record type from GraphNode state
/// 2. For Organization: Aggregates stats across all nursery sites
/// 3. For other nodes: Streams organism data and calculates stats from children
/// 4. Applies health filters before rendering statistics
class _SummaryStatisticsView extends StatelessWidget {
  const _SummaryStatisticsView({
    required this.node,
    this.organismStats,
  });

  final GraphNode node;
  final OrganismStatistics? organismStats;

  static const OrganismStatistics _emptyStats = OrganismStatistics(
    totalOrganisms: 0,
    totalOrganismRecords: 0,
    readyForOutplant: 0,
    readyForOutplantRecords: 0,
    readyForPropagation: 0,
    readyForPropagationRecords: 0,
    healthIssues: 0,
    healthIssuesRecords: 0,
    statusBreakdown: {},
    uniqueGenotypes: null,
  );

  static const Duration _summaryOrganismGetAllTimeout = Duration(seconds: 4);
  static const int _summaryOrganismFallbackThreshold = 50;

  /// Helper to safely get record from GraphNode state
  GraphNodeRecord? _getRecord(GraphNode node) => node.state is GraphLoadedState
      ? (node.state as GraphLoadedState).record
      : null;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SummaryStatisticsCubit, SummaryStatisticsState>(
      builder: (context, filterState) {
        // For organization level, aggregate across nursery sites
        final record = _getRecord(node);
        if (record is Organization) {
          return FutureBuilder<OrganismStatistics>(
            future: _computeOrganizationStats(context, filterState),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingStats();
              }
              if (snapshot.hasError) {
                return _buildErrorStats(snapshot.error.toString());
              }
              final stats = snapshot.data ?? _emptyStats;
              return _buildStatsDisplay(context, stats, filterState);
            },
          );
        }

        // For other levels, calculate stats from node's children
        return BlocBuilder<GraphNode, GraphNodeState>(
          bloc: node,
          builder: (context, _) {
            final record = _getRecord(node);
            if (record == null) {
              return _buildLoadingStats();
            }

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
                // Show loading if waiting AND data is empty (BehaviorSubject emits
                // empty list immediately, so we must check data emptiness too)
                if (snapshot.connectionState == ConnectionState.waiting &&
                    (snapshot.data == null || snapshot.data!.isEmpty)) {
                  return _buildLoadingStats();
                }
                final organisms = (snapshot.data ?? const <OrganismRecord>[])
                    .where((organism) => !_isExcludedFromInventoryCounts(siteId: organism.siteId ?? ''))
                    .where((organism) => _includeByHealth(organism, filterState));
                final stats = _summarizeOrganisms(organisms, filterState);
                return _buildStatsDisplay(context, stats, filterState);
              },
            );
          },
        );
      },
    );
  }

  /// Compute organization-level stats restricted to nursery sites
  Future<OrganismStatistics> _computeOrganizationStats(
    BuildContext context,
    SummaryStatisticsState filterState,
  ) async {
    final organismRecordRepository = context.read<OrganismRecordRepository>();
    final allOrganisms = await _initialOrganismSnapshot(organismRecordRepository);

    final filtered = allOrganisms
        .where((organism) => !_isExcludedFromInventoryCounts(siteId: organism.siteId ?? ''))
        .toList(growable: false);

    final filteredByHealth = filtered.where(
      (organism) => _includeByHealth(organism, filterState),
    );

    return _summarizeOrganisms(filteredByHealth, filterState);
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
  /// **Calculations Performed:**
  /// 1. **Quantities**: Counts total organisms, ready for outplant, ready for propagation, health issues
  /// 2. **Status Breakdown**: Aggregates counts by health status
  /// 3. **Genotypes**: Counts unique genotypes
  ///
  /// **Filtering Logic:**
  /// - `onlyIssues`: Only counts organisms with non-healthy status
  /// - `selectedHealth`: Only counts organisms matching the selected health status
  /// - Both filters are applied before categorization
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

    // Convert to list for multiple iterations
    final organismList = organisms.toList();
    final filteredOrganismList = organismList
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

      // Apply health filters
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
          const SizedBox(height: 12),
          _buildInventoryStats(context, stats, filterState),
        ],
      ),
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
        const SizedBox(height: 6),
        // Ready for Outplant and Propagation - Pro features (disabled in community)
        Row(
          children: [
            Expanded(
              child: _buildProFeatureCard(
                context,
                'Ready for Outplant',
                Icons.upload,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildProFeatureCard(
                context,
                'Ready for Propagation',
                Icons.content_cut,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Health Issues - Pro feature (disabled in community)
        Row(
          children: [
            Expanded(
              child: _buildProFeatureCard(
                context,
                'Health Issues',
                Icons.warning,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  /// Builds a disabled Pro feature card for community tier.
  ///
  /// **Layout:**
  /// - Greyed out icon and label
  /// - "N/A" value text
  /// - "Upgrade to Pro" subtitle
  ///
  /// **Styling:**
  /// - Background color: Light grey
  /// - Border: Light grey
  /// - Text: Grey, subdued
  Widget _buildProFeatureCard(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
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
            'N/A',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Coming Soon',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an individual statistics card widget.
  ///
  /// **Layout:**
  /// - Icon and label in top row
  /// - Large value text below
  /// - Optional detail text for record counts
  ///
  /// **Styling:**
  /// - Background color: Semi-transparent version of primary color
  /// - Border: Semi-transparent version of primary color
  /// - Value text: Bold, large, uses primary color
  /// - onTap: Optional callback for clickable cards (shows pointer cursor)
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
    final record = _getRecord(node);
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
        LoggingService.instance.info('SummaryStatistics: Organism selected - ${organism.localId ?? organism.slug}');
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
    // Ready to propagate when flag is set AND organism is marked Healthy
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
///
/// **Quantities:**
/// - `totalOrganisms`: Total count of organisms (after filtering)
/// - `totalOrganismRecords`: Total number of organism records (after filtering)
/// - `readyForOutplant`: Count of organisms marked ready for outplanting
/// - `readyForOutplantRecords`: Record count for ready-for-outplant organisms
/// - `readyForPropagation`: Count of organisms marked ready for propagation
/// - `readyForPropagationRecords`: Record count for ready-for-propagation organisms
/// - `healthIssues`: Count of organisms with non-healthy status
/// - `healthIssuesRecords`: Record count for organisms with health issues
///
/// **Metadata:**
/// - `statusBreakdown`: Map of health status display names to counts
/// - `uniqueGenotypes`: Count of unique genotypes represented
/// - `filterSignature`: String signature of applied filters (for caching)
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
}
