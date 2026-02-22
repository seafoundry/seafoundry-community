// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/monitoring/monitoring_entry.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Immutable data class containing all computed analytics from monitoring events
class MonitoringAnalyticsData extends Equatable {
  const MonitoringAnalyticsData({
    required this.bestSiteLabel,
    required this.siteComparisonDetail,
    required this.focusSiteLabel,
    required this.focusSiteDetail,
    required this.bestGenetLabel,
    required this.worstGenetLabel,
    required this.averageCover,
    required this.medianDisease,
    required this.coverTrend,
    required this.sitePerformance,
    required this.healthDistribution,
    this.ecologicalSurveyCount = 0,
  });

  final String bestSiteLabel;
  final String siteComparisonDetail;
  final String focusSiteLabel;
  final String focusSiteDetail;
  final String bestGenetLabel;
  final String worstGenetLabel;
  final double averageCover;
  final double medianDisease;

  /// Number of ecological surveys recorded for this organization.
  final int ecologicalSurveyCount;

  // Chart data
  final List<({DateTime date, double value})> coverTrend;
  final List<({String label, double value})> sitePerformance;
  final List<({String label, double value, Color color})> healthDistribution;

  @override
  List<Object?> get props => [
        bestSiteLabel,
        siteComparisonDetail,
        focusSiteLabel,
        focusSiteDetail,
        bestGenetLabel,
        worstGenetLabel,
        averageCover,
        medianDisease,
        ecologicalSurveyCount,
        coverTrend,
        sitePerformance,
        healthDistribution,
      ];
}

/// Service for computing monitoring analytics from events
class MonitoringAnalyticsService {
  const MonitoringAnalyticsService();

  /// Compute all analytics from monitoring events and sites
  MonitoringAnalyticsData computeAnalytics(
    List<MonitoringEventRecord> events,
    List<Site> sites, {
    int ecologicalSurveyCount = 0,
  }) {
    final siteNames = {for (final site in sites) site.id: site.name};
    final siteStats = <String, _SiteStats>{};
    final genetStats = <String, _GenetStats>{};
    final diseaseValues = <double>[];
    final healthCounts = <HealthStatus, int>{};

    // For Trend: sort events by date
    final sortedEvents = List<MonitoringEventRecord>.from(events)
      ..sort((a, b) {
        final dateA = _parseDate(a);
        final dateB = _parseDate(b);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

    final coverTrend = <({DateTime date, double value})>[];

    for (final event in sortedEvents) {
      final date = _parseDate(event);
      if (date != null && event.percentCover != null) {
        coverTrend.add((date: date, value: event.percentCover!));
      }

      final siteId = event.siteId ?? 'unknown';
      final stat = siteStats.putIfAbsent(siteId, _SiteStats.new);
      if (event.percentCover != null) {
        stat.coverSum += event.percentCover!;
        stat.coverCount += 1;
      }
      if (event.percentDisease != null) {
        stat.diseaseSum += event.percentDisease!;
        stat.diseaseCount += 1;
        diseaseValues.add(event.percentDisease!);
      }
      if (event.entries.isNotEmpty) {
        for (final entry in event.entries) {
          _updateGenetStats(genetStats, entry);

          if (entry.healthStatus?.isNotEmpty == true) {
            final status = HealthStatus.fromId(entry.healthStatus);
            healthCounts.update(status, (v) => v + 1, ifAbsent: () => 1);
          }
        }
      }
    }

    final bestSite = siteStats.entries
        .where((entry) => entry.value.coverCount > 0)
        .toList()
      ..sort(
        (a, b) => b.value.averageCover.compareTo(a.value.averageCover),
      );

    final focusSite = siteStats.entries
        .where((entry) => entry.value.diseaseCount > 0)
        .toList()
      ..sort(
        (a, b) => b.value.averageDisease.compareTo(a.value.averageDisease),
      );

    final sortedGenets = genetStats.entries
        .where((entry) => entry.value.total > 0)
        .toList()
      ..sort(
        (a, b) => b.value.healthRatio.compareTo(a.value.healthRatio),
      );

    final bestGenet = sortedGenets.isNotEmpty ? sortedGenets.first : null;
    final worstGenet = sortedGenets.isNotEmpty ? sortedGenets.last : null;

    final totalCoverSamples = siteStats.values
        .fold<int>(0, (sum, stat) => sum + stat.coverCount);
    final coverSum = siteStats.values
        .fold<double>(0, (sum, stat) => sum + stat.coverSum);

    diseaseValues.sort();
    final medianDisease = _median(diseaseValues);

    return MonitoringAnalyticsData(
      bestSiteLabel: bestSite.isEmpty
          ? 'No recent monitoring data'
          : '${siteNames[bestSite.first.key] ?? bestSite.first.key} (${bestSite.first.value.averageCover.toStringAsFixed(1)}% cover)',
      siteComparisonDetail: bestSite.length < 2
          ? 'Collect more monitoring events to compare sites.'
          : 'Runner-up: ${siteNames[bestSite[1].key] ?? bestSite[1].key} '
              '(${bestSite[1].value.averageCover.toStringAsFixed(1)}%).',
      focusSiteLabel: focusSite.isEmpty
          ? 'All sites stable'
          : (siteNames[focusSite.first.key] ?? focusSite.first.key),
      focusSiteDetail: focusSite.isEmpty
          ? 'No elevated disease levels detected.'
          : 'Average disease ${focusSite.first.value.averageDisease.toStringAsFixed(1)}% across recent events.',
      bestGenetLabel: bestGenet == null
          ? 'No genets monitored'
          : '${bestGenet.key} (${(bestGenet.value.healthRatio * 100).toStringAsFixed(0)}% healthy)',
      worstGenetLabel: worstGenet == null
          ? 'None'
          : '${worstGenet.key} (${(worstGenet.value.healthRatio * 100).toStringAsFixed(0)}% healthy)',
      averageCover:
          totalCoverSamples == 0 ? 0.0 : coverSum / totalCoverSamples,
      medianDisease: medianDisease,
      ecologicalSurveyCount: ecologicalSurveyCount,
      coverTrend: coverTrend,
      sitePerformance: _buildSitePerformance(bestSite, siteNames),
      healthDistribution: _buildHealthDistribution(healthCounts),
    );
  }

  /// Calculate proper median (handles both odd and even length lists)
  double _median(List<double> sorted) {
    if (sorted.isEmpty) return 0.0;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// CRITICAL: Safe date parsing with error handling to prevent crashes
  DateTime? _parseDate(MonitoringEventRecord event) {
    try {
      return event.monitoringDate ?? DateTime.parse(event.createdAt);
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to parse date for event ${event.id}: ${event.createdAt}',
      );
      return null;
    }
  }

  /// Build chart data for top 5 sites by cover
  List<({String label, double value})> _buildSitePerformance(
    List<MapEntry<String, _SiteStats>> bestSite,
    Map<String, String> siteNames,
  ) {
    return bestSite
        .take(5)
        .map(
          (entry) => (
            label: siteNames[entry.key] ?? entry.key,
            value: entry.value.averageCover,
          ),
        )
        .toList();
  }

  /// Build chart data for health distribution
  List<({String label, double value, Color color})> _buildHealthDistribution(
    Map<HealthStatus, int> healthCounts,
  ) {
    return healthCounts.entries
        .map(
          (entry) => (
            label: entry.key.displayName,
            value: entry.value.toDouble(),
            color: _healthColor(entry.key),
          ),
        )
        .toList();
  }

  /// Update genet statistics from a monitoring entry
  void _updateGenetStats(
    Map<String, _GenetStats> stats,
    MonitoringEntry entry,
  ) {
    if (entry.genetId.isEmpty) return;
    final healthStatus = HealthStatus.maybeFromId(entry.healthStatus);
    final record = stats.putIfAbsent(entry.genetId, () => _GenetStats());
    record.total += 1;
    if (healthStatus == null ||
        healthStatus == HealthStatus.healthy ||
        healthStatus == HealthStatus.recovering) {
      record.healthy += 1;
    }
  }

  /// Map health status to chart color
  Color _healthColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
      case HealthStatus.recovering:
        return Colors.green;
      case HealthStatus.stressed:
        return Colors.amber;
      case HealthStatus.diseased:
      case HealthStatus.bleached:
        return Colors.orange;
      case HealthStatus.deceased:
      case HealthStatus.lost:
        return Colors.grey;
      case HealthStatus.damaged:
      case HealthStatus.fragmented:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

/// Tracks site-level statistics
class _SiteStats {
  double coverSum = 0;
  int coverCount = 0;
  double diseaseSum = 0;
  int diseaseCount = 0;

  double get averageCover => coverCount == 0 ? 0 : coverSum / coverCount;
  double get averageDisease => diseaseCount == 0 ? 0 : diseaseSum / diseaseCount;
}

/// Tracks genet-level statistics
class _GenetStats {
  int healthy = 0;
  int total = 0;

  double get healthRatio => total == 0 ? 0 : healthy / total;
}
