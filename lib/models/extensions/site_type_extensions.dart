// @tier: community
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

/// Extension providing site type classification helpers.
///
/// Centralizes the logic for determining if a site is an outplant or monitoring
/// site, eliminating duplication across dialog widgets.
extension SiteTypeClassification on Site {
  /// Whether this site is an outplanting site.
  bool get isOutplantSite => siteType == SiteType.outplanting;

  /// Whether this site is a monitoring-only site (baseline or reference).
  bool get isMonitoringSite => siteType.isMonitoringOnly;

  /// Whether this site can receive deliverable allocations.
  ///
  /// Only outplant and monitoring sites are valid for deliverable site
  /// allocations.
  bool get isDeliverableTargetSite => isOutplantSite || isMonitoringSite;
}

/// Extension for filtering site lists by type.
extension SiteListFilters on Iterable<Site> {
  /// Filter to only outplant sites.
  Iterable<Site> get outplantSites => where((s) => s.isOutplantSite);

  /// Filter to only monitoring sites.
  Iterable<Site> get monitoringSites => where((s) => s.isMonitoringSite);

  /// Filter to sites that can receive deliverable allocations.
  Iterable<Site> get deliverableTargetSites =>
      where((s) => s.isDeliverableTargetSite);
}
