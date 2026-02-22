// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/reporting/filter_config.dart';
import 'package:seafoundry_app/models/reporting/time_range_config.dart';
import 'package:seafoundry_app/models/reporting/visualization_config.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';

/// Time-series data point with grouping label.
class TimeSeriesDataPoint extends Equatable {
  const TimeSeriesDataPoint({
    required this.date,
    required this.value,
    this.label,
  });

  final DateTime date;
  final double value;
  final String? label;

  @override
  List<Object?> get props => [date, value, label];
}

/// Grouped data point with category label.
class GroupedDataPoint extends Equatable {
  const GroupedDataPoint({
    required this.label,
    required this.value,
    this.subGroups,
  });

  final String label;
  final double value;
  final Map<String, double>? subGroups;

  @override
  List<Object?> get props => [label, value, subGroups];
}

/// Cross-site comparison data.
class SiteComparisonData extends Equatable {
  const SiteComparisonData({
    required this.siteId,
    required this.siteName,
    required this.metrics,
  });

  final String siteId;
  final String siteName;
  final Map<String, double> metrics;

  @override
  List<Object?> get props => [siteId, siteName, metrics];
}

/// Aggregated data result from service.
class AggregatedReportData extends Equatable {
  const AggregatedReportData({
    this.timeSeries = const [],
    this.groupedData = const [],
    this.siteComparisons = const [],
    this.summary = const {},
  });

  final List<TimeSeriesDataPoint> timeSeries;
  final List<GroupedDataPoint> groupedData;
  final List<SiteComparisonData> siteComparisons;
  final Map<String, double> summary;

  @override
  List<Object?> get props => [timeSeries, groupedData, siteComparisons, summary];
}

/// Service for aggregating report data across time periods and dimensions.
///
/// Provides:
/// - Time-series aggregation (by day, week, month)
/// - Cross-site aggregation (Pro feature)
/// - Period-over-period comparison
/// - Metric computation based on visualization configuration
class ReportDataAggregationService {
  const ReportDataAggregationService();

  /// Aggregate data based on visualization configuration.
  AggregatedReportData aggregate({
    required List<OrganismRecord> records,
    required List<Site> sites,
    required DataSourceConfig dataSource,
    required TimeRangeConfig timeRange,
    required FilterConfig filters,
  }) {
    // Filter records within time range
    final filteredRecords = _filterByTimeRange(records, timeRange);

    // Apply additional filters
    final finalRecords = _applyFilters(filteredRecords, filters);

    // Compute based on groupBy
    switch (dataSource.groupBy) {
      case DataGroupBy.none:
        return _aggregateUngrouped(finalRecords, dataSource.metric);
      case DataGroupBy.day:
      case DataGroupBy.week:
      case DataGroupBy.month:
        return _aggregateByTime(
          finalRecords,
          dataSource.metric,
          dataSource.groupBy,
          timeRange,
        );
      case DataGroupBy.site:
        return _aggregateBySite(finalRecords, sites, dataSource.metric, filters);
      case DataGroupBy.species:
        return _aggregateBySpecies(finalRecords, dataSource.metric);
      case DataGroupBy.genet:
        return _aggregateByGenet(finalRecords, dataSource.metric);
      case DataGroupBy.lifeStage:
        return _aggregateByLifeStage(finalRecords, dataSource.metric);
      case DataGroupBy.healthStatus:
        return _aggregateByHealthStatus(finalRecords, dataSource.metric);
    }
  }

  /// Compute period-over-period comparison.
  Map<String, ({double current, double previous, double? changePercent})>
      computePeriodComparison({
    required List<OrganismRecord> currentRecords,
    required List<OrganismRecord> previousRecords,
    required FilterConfig filters,
  }) {
    final currentFiltered = _applyFilters(currentRecords, filters);
    final previousFiltered = _applyFilters(previousRecords, filters);

    final result = <String, ({double current, double previous, double? changePercent})>{};

    // Total count
    final currentTotal = _computeTotalCount(currentFiltered).toDouble();
    final previousTotal = _computeTotalCount(previousFiltered).toDouble();
    result['totalCount'] = _createComparison(currentTotal, previousTotal);

    // Healthy count
    final currentHealthy = _computeHealthyCount(currentFiltered).toDouble();
    final previousHealthy = _computeHealthyCount(previousFiltered).toDouble();
    result['healthyCount'] = _createComparison(currentHealthy, previousHealthy);

    // Healthy percentage
    final currentPercent = currentTotal > 0 ? (currentHealthy / currentTotal) * 100 : 0.0;
    final previousPercent = previousTotal > 0 ? (previousHealthy / previousTotal) * 100 : 0.0;
    result['healthyPercentage'] = _createComparison(currentPercent, previousPercent);

    // Unique genets
    final currentGenets = _computeUniqueGenets(currentFiltered).toDouble();
    final previousGenets = _computeUniqueGenets(previousFiltered).toDouble();
    result['uniqueGenets'] = _createComparison(currentGenets, previousGenets);

    return result;
  }

  /// Aggregate data across multiple sites (Pro feature).
  AggregatedReportData aggregateCrossSite({
    required List<OrganismRecord> records,
    required List<Site> sites,
    required DataSourceMetric metric,
    required FilterConfig filters,
  }) {
    if (!filters.crossSiteAggregation) {
      return const AggregatedReportData();
    }

    final siteNames = {for (final site in sites) site.id: site.name};
    final siteComparisons = <SiteComparisonData>[];

    // Group records by site
    final recordsBySite = <String, List<OrganismRecord>>{};
    for (final record in records) {
      final siteId = record.siteId;
      if (siteId == null) continue;
      recordsBySite.putIfAbsent(siteId, () => []).add(record);
    }

    // Compute metrics for each site
    for (final entry in recordsBySite.entries) {
      final metrics = <String, double>{
        'totalCount': _computeTotalCount(entry.value).toDouble(),
        'healthyCount': _computeHealthyCount(entry.value).toDouble(),
        'uniqueGenets': _computeUniqueGenets(entry.value).toDouble(),
      };

      final total = metrics['totalCount']!;
      if (total > 0) {
        metrics['healthyPercentage'] = (metrics['healthyCount']! / total) * 100;
      }

      siteComparisons.add(SiteComparisonData(
        siteId: entry.key,
        siteName: siteNames[entry.key] ?? entry.key,
        metrics: metrics,
      ));
    }

    // Sort by total count descending
    siteComparisons.sort((a, b) =>
        (b.metrics['totalCount'] ?? 0).compareTo(a.metrics['totalCount'] ?? 0));

    return AggregatedReportData(siteComparisons: siteComparisons);
  }

  List<OrganismRecord> _filterByTimeRange(
    List<OrganismRecord> records,
    TimeRangeConfig timeRange,
  ) {
    final start = DateRangePresets.startOfDay(timeRange.startDate);
    final end = DateRangePresets.endOfDay(timeRange.endDate);

    return records.where((record) {
      final createdAtStr = record.createdAt;
      DateTime? createdAt;
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {
        return false; // Exclude records with invalid dates from time-range queries
      }
      return !createdAt.isBefore(start) && !createdAt.isAfter(end);
    }).toList();
  }

  List<OrganismRecord> _applyFilters(
    List<OrganismRecord> records,
    FilterConfig filters,
  ) {
    if (filters.isEmpty) return records;
    final normalizedSpeciesIds = filters.speciesIds.isNotEmpty
        ? SpeciesRegistry.normalizeIds(filters.speciesIds)
        : const <String>{};

    return records.where((record) {
      if (filters.siteIds.isNotEmpty) {
        final siteId = record.siteId;
        if (siteId == null || !filters.siteIds.contains(siteId)) return false;
      }
      if (filters.structureIds.isNotEmpty) {
        final groupId = record.groupId;
        if (groupId == null || !filters.structureIds.contains(groupId)) {
          return false;
        }
      }
      if (filters.speciesIds.isNotEmpty) {
        final speciesId = SpeciesRegistry.normalizeId(record.speciesId);
        if (speciesId == null || !normalizedSpeciesIds.contains(speciesId)) {
          return false;
        }
      }
      if (filters.genetIds.isNotEmpty) {
        final genetId = record.genetId;
        if (genetId == null || !filters.genetIds.contains(genetId)) {
          return false;
        }
      }
      if (filters.lifeStageIds.isNotEmpty) {
        final lifeStageId = record.lifeStageId;
        if (!filters.lifeStageIds.contains(lifeStageId)) {
          return false;
        }
      }
      if (filters.healthStatusIds.isNotEmpty) {
        final healthStatus = _getHealthStatus(record);
        if (!filters.healthStatusIds.contains(healthStatus.id)) {
          return false;
        }
      }
      if (filters.zoneIds.isNotEmpty) {
        final zoneId = record.zoneId;
        if (zoneId == null || !filters.zoneIds.contains(zoneId)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  AggregatedReportData _aggregateUngrouped(
    List<OrganismRecord> records,
    DataSourceMetric metric,
  ) {
    final value = _computeMetricValue(records, metric);
    return AggregatedReportData(
      summary: {metric.name: value},
    );
  }

  AggregatedReportData _aggregateByTime(
    List<OrganismRecord> records,
    DataSourceMetric metric,
    DataGroupBy groupBy,
    TimeRangeConfig timeRange,
  ) {
    final byPeriod = <DateTime, List<OrganismRecord>>{};

    for (final record in records) {
      final createdAtStr = record.createdAt;
      DateTime? createdAt;
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {
        continue;
      }

      final periodKey = _getPeriodKey(createdAt, groupBy);
      byPeriod.putIfAbsent(periodKey, () => []).add(record);
    }

    // Sort by date
    final sortedPeriods = byPeriod.keys.toList()..sort();

    // Compute cumulative or point values based on metric
    final timeSeries = <TimeSeriesDataPoint>[];
    var cumulative = 0.0;

    for (final period in sortedPeriods) {
      final periodRecords = byPeriod[period]!;
      final value = _computeMetricValue(periodRecords, metric);

      // For count metrics, show cumulative; for percentages, show point-in-time
      if (metric == DataSourceMetric.totalCount ||
          metric == DataSourceMetric.healthyCount ||
          metric == DataSourceMetric.readyForOutplant ||
          metric == DataSourceMetric.uniqueGenets) {
        cumulative += value;
        timeSeries.add(TimeSeriesDataPoint(
          date: period,
          value: cumulative,
          label: _formatPeriodLabel(period, groupBy),
        ));
      } else {
        timeSeries.add(TimeSeriesDataPoint(
          date: period,
          value: value,
          label: _formatPeriodLabel(period, groupBy),
        ));
      }
    }

    return AggregatedReportData(timeSeries: timeSeries);
  }

  AggregatedReportData _aggregateBySite(
    List<OrganismRecord> records,
    List<Site> sites,
    DataSourceMetric metric,
    FilterConfig filters,
  ) {
    final siteNames = {for (final site in sites) site.id: site.name};
    final bySite = <String, List<OrganismRecord>>{};

    for (final record in records) {
      final siteId = record.siteId;
      if (siteId == null) continue;
      bySite.putIfAbsent(siteId, () => []).add(record);
    }

    final groupedData = bySite.entries.map((entry) {
      final value = _computeMetricValue(entry.value, metric);
      return GroupedDataPoint(
        label: siteNames[entry.key] ?? entry.key,
        value: value,
      );
    }).toList();

    groupedData.sort((a, b) => b.value.compareTo(a.value));

    return AggregatedReportData(groupedData: groupedData);
  }

  AggregatedReportData _aggregateBySpecies(
    List<OrganismRecord> records,
    DataSourceMetric metric,
  ) {
    final bySpecies = <String, List<OrganismRecord>>{};

    for (final record in records) {
      final speciesName = record.speciesId ?? 'Unknown';
      bySpecies.putIfAbsent(speciesName, () => []).add(record);
    }

    final groupedData = bySpecies.entries.map((entry) {
      final value = _computeMetricValue(entry.value, metric);
      return GroupedDataPoint(label: entry.key, value: value);
    }).toList();

    groupedData.sort((a, b) => b.value.compareTo(a.value));

    return AggregatedReportData(groupedData: groupedData);
  }

  AggregatedReportData _aggregateByGenet(
    List<OrganismRecord> records,
    DataSourceMetric metric,
  ) {
    final byGenet = <String, List<OrganismRecord>>{};

    for (final record in records) {
      final genetId = record.genetId ?? 'Unknown';
      byGenet.putIfAbsent(genetId, () => []).add(record);
    }

    final groupedData = byGenet.entries.map((entry) {
      final value = _computeMetricValue(entry.value, metric);
      return GroupedDataPoint(label: entry.key, value: value);
    }).toList();

    groupedData.sort((a, b) => b.value.compareTo(a.value));

    return AggregatedReportData(groupedData: groupedData);
  }

  AggregatedReportData _aggregateByLifeStage(
    List<OrganismRecord> records,
    DataSourceMetric metric,
  ) {
    final byStage = <String, List<OrganismRecord>>{};

    for (final record in records) {
      final stage = record.lifeStageId;
      byStage.putIfAbsent(stage, () => []).add(record);
    }

    final groupedData = byStage.entries.map((entry) {
      final value = _computeMetricValue(entry.value, metric);
      return GroupedDataPoint(label: entry.key, value: value);
    }).toList();

    groupedData.sort((a, b) => b.value.compareTo(a.value));

    return AggregatedReportData(groupedData: groupedData);
  }

  AggregatedReportData _aggregateByHealthStatus(
    List<OrganismRecord> records,
    DataSourceMetric metric,
  ) {
    final byStatus = <HealthStatus, List<OrganismRecord>>{};

    for (final record in records) {
      final status = _getHealthStatus(record);
      byStatus.putIfAbsent(status, () => []).add(record);
    }

    final groupedData = byStatus.entries.map((entry) {
      final value = _computeMetricValue(entry.value, metric);
      return GroupedDataPoint(label: entry.key.displayName, value: value);
    }).toList();

    groupedData.sort((a, b) => b.value.compareTo(a.value));

    return AggregatedReportData(groupedData: groupedData);
  }

  double _computeMetricValue(
    List<OrganismRecord> records,
    DataSourceMetric metric,
  ) {
    switch (metric) {
      case DataSourceMetric.totalCount:
        return _computeTotalCount(records).toDouble();
      case DataSourceMetric.healthyCount:
        return _computeHealthyCount(records).toDouble();
      case DataSourceMetric.healthyPercentage:
        final total = _computeTotalCount(records);
        final healthy = _computeHealthyCount(records);
        return total > 0 ? (healthy / total) * 100 : 0;
      case DataSourceMetric.readyForOutplant:
        return records.where((r) {
          final isHealthy = _getHealthStatus(r) == HealthStatus.healthy;
          final hasQuantity = _getQuantity(r) > 0;
          return r.readyForOutplant && isHealthy && hasQuantity;
        }).fold<double>(0, (sum, record) => sum + _getQuantity(record));
      case DataSourceMetric.quantity:
        return _computeTotalCount(records).toDouble();
      case DataSourceMetric.uniqueGenets:
        return _computeUniqueGenets(records).toDouble();
      case DataSourceMetric.survivalRate:
        // Placeholder - actual survival rate needs mortality events
        return 100.0;
      case DataSourceMetric.growthRate:
        // Placeholder - actual growth rate needs measurement events
        return 0.0;
    }
  }

  HealthStatus _getHealthStatus(OrganismRecord record) {
    final metadata = record.metadata;
    if (metadata != null && metadata['healthStatus'] is String) {
      return HealthStatus.fromId(metadata['healthStatus'] as String);
    }
    return HealthStatus.healthy;
  }

  int _getQuantity(OrganismRecord record) {
    final count = record.inventoryMetrics.count;
    if (count != null) {
      return count;
    }
    if (record.measurement.unit.category == MeasurementUnitCategory.count) {
      return record.measurement.value.round();
    }
    return 1;
  }

  int _computeTotalCount(List<OrganismRecord> records) {
    return records.fold<int>(0, (sum, r) => sum + _getQuantity(r));
  }

  int _computeHealthyCount(List<OrganismRecord> records) {
    return records.where((r) {
      final status = _getHealthStatus(r);
      return status == HealthStatus.healthy ||
          status == HealthStatus.recovering;
    }).fold<int>(0, (sum, r) => sum + _getQuantity(r));
  }

  int _computeUniqueGenets(List<OrganismRecord> records) {
    return records
        .map((r) => r.genetId)
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .length;
  }

  DateTime _getPeriodKey(DateTime date, DataGroupBy groupBy) {
    switch (groupBy) {
      case DataGroupBy.day:
        return DateTime(date.year, date.month, date.day);
      case DataGroupBy.week:
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
      case DataGroupBy.month:
        return DateTime(date.year, date.month, 1);
      default:
        return DateTime(date.year, date.month, date.day);
    }
  }

  String _formatPeriodLabel(DateTime date, DataGroupBy groupBy) {
    switch (groupBy) {
      case DataGroupBy.day:
        return '${date.month}/${date.day}';
      case DataGroupBy.week:
        return 'W${_weekNumber(date)}';
      case DataGroupBy.month:
        return '${_monthName(date.month)} ${date.year}';
      default:
        return '${date.month}/${date.day}/${date.year}';
    }
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    // Ensure we never return 0 - week 1 starts on Jan 1
    final weekNum = ((daysDiff + firstDayOfYear.weekday) / 7).ceil();
    return weekNum < 1 ? 1 : weekNum;
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  ({double current, double previous, double? changePercent}) _createComparison(
    double current,
    double previous,
  ) {
    double? changePercent;
    if (previous != 0) {
      changePercent = ((current - previous) / previous) * 100;
    }
    return (current: current, previous: previous, changePercent: changePercent);
  }
}
