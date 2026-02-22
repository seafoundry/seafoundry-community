// @tier: community
import 'package:meta/meta.dart';

/// Data representation for a metric rendered inside a summary card.
@immutable
class SiteSummaryMetric {
  const SiteSummaryMetric({
    required this.label,
    required this.value,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;
}

/// A collection of metrics that render together inside a card.
@immutable
class SiteSummaryMetricGroup {
  const SiteSummaryMetricGroup({required this.title, required this.metrics});

  final String title;
  final List<SiteSummaryMetric> metrics;
}

/// Blueprint describing how the summary section should render for a site type.
@immutable
class SiteSummaryBlueprint {
  const SiteSummaryBlueprint({
    required this.heading,
    required this.showOrganismStatistics,
    required this.metricGroups,
  });

  final String heading;
  final bool showOrganismStatistics;
  final List<SiteSummaryMetricGroup> metricGroups;
}
