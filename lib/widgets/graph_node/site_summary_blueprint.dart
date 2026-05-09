// @tier: community
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/widgets/graph_node/site_summary_models.dart';

/// Build a UI blueprint for site summary cards based on site capabilities.
SiteSummaryBlueprint buildSiteSummaryBlueprint({
  required SiteLoadedState state,
  required SiteCapabilities capabilities,
}) {
  final siteType = capabilities.siteType;
  final metricGroups = <SiteSummaryMetricGroup>[];

  final heading = _headlineForSiteType(siteType);
  final showStatistics = !siteType.isOutplanting;

  return SiteSummaryBlueprint(
    heading: heading,
    showOrganismStatistics: showStatistics,
    metricGroups: metricGroups,
  );
}

// Outplant activity metrics and gene bank metrics removed in
// coral-only / nursery-only simplification.

String _headlineForSiteType(SiteType siteType) {
  if (siteType.isOutplanting) {
    return 'Outplanting Site Snapshot';
  }
  return 'Nursery Health Snapshot';
}
