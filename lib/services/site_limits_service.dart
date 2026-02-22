// @tier: community
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/services/tier.dart';

/// Service to manage site creation limits based on organization tier.
///
/// Community tier allows:
/// - 1 nursery site (ex situ, in situ, or gene bank)
/// - 3 outplanting/restoration sites
/// - Monitoring-only sites require Pro
///
/// Pro and Scale tiers have unlimited sites.
class SiteLimitsService {
  SiteLimitsService._();

  // Community tier limits
  static const int communityNurseryLimit = 1;
  static const int communityOutplantingLimit = 3;

  /// Site types that count towards the nursery limit
  static const List<SiteType> nurserySiteTypes = [
    SiteType.nurseryExSitu,
    SiteType.nurseryInSitu,
    SiteType.geneBank,
  ];

  /// Site types that count towards the outplanting limit
  static const List<SiteType> outplantingSiteTypes = [
    SiteType.outplanting,
    SiteType.fieldCollection,
  ];

  /// Helper to check if a site type is monitoring-only.
  /// Uses SiteType.isMonitoringOnly for single source of truth.
  static bool _isMonitoringSiteType(SiteType siteType) => siteType.isMonitoringOnly;

  /// Check if organization can create a new site of the given type
  ///
  /// Returns true if:
  /// - Organization is Pro/Scale tier (unlimited sites)
  /// - Organization is Community tier and hasn't reached the limit for this site type
  static bool canCreateSite({
    required Tier tier,
    required SiteType siteType,
    required List<Site> existingSites,
  }) {
    // Pro and Scale tiers have unlimited sites
    if (tier != Tier.community) {
      return true;
    }

    // Community tier: check limits
    if (nurserySiteTypes.contains(siteType)) {
      final existingNurseryCount = existingSites
          .where((site) => nurserySiteTypes.contains(site.siteType))
          .length;
      return existingNurseryCount < communityNurseryLimit;
    }

    if (outplantingSiteTypes.contains(siteType)) {
      final existingOutplantingCount = existingSites
          .where((site) => outplantingSiteTypes.contains(site.siteType))
          .length;
      return existingOutplantingCount < communityOutplantingLimit;
    }

    // Monitoring and other site types not allowed in Community tier
    return false;
  }

  /// Check if organization has reached the nursery site limit
  static bool hasReachedNurseryLimit({
    required Tier tier,
    required List<Site> existingSites,
  }) {
    if (tier != Tier.community) {
      return false;
    }

    final existingNurseryCount = existingSites
        .where((site) => nurserySiteTypes.contains(site.siteType))
        .length;
    return existingNurseryCount >= communityNurseryLimit;
  }

  /// Check if organization has reached the outplanting site limit
  static bool hasReachedOutplantingLimit({
    required Tier tier,
    required List<Site> existingSites,
  }) {
    if (tier != Tier.community) {
      return false;
    }

    final existingOutplantingCount = existingSites
        .where((site) => outplantingSiteTypes.contains(site.siteType))
        .length;
    return existingOutplantingCount >= communityOutplantingLimit;
  }

  /// Get upgrade message for site creation
  ///
  /// Returns a message explaining the limit and suggesting an upgrade
  static String getUpgradeMessage(SiteType siteType) {
    if (nurserySiteTypes.contains(siteType)) {
      return 'Community tier allows $communityNurseryLimit nursery site. '
          'Upgrade for unlimited sites.';
    }

    if (outplantingSiteTypes.contains(siteType)) {
      return 'Community tier allows $communityOutplantingLimit outplanting sites. '
          'Upgrade for unlimited sites.';
    }

    if (_isMonitoringSiteType(siteType)) {
      return 'Monitoring sites are not available in Community tier. '
          'Upgrade to create baseline and reference sites.';
    }

    return 'This site type is not available in Community tier. '
        'Upgrade for access to all site types.';
  }

  /// Get a user-friendly description of remaining site capacity
  static String getRemainingCapacityMessage({
    required Tier tier,
    required List<Site> existingSites,
  }) {
    if (tier != Tier.community) {
      return 'Unlimited sites available';
    }

    final nurseryCount = existingSites
        .where((site) => nurserySiteTypes.contains(site.siteType))
        .length;
    final outplantingCount = existingSites
        .where((site) => outplantingSiteTypes.contains(site.siteType))
        .length;

    final nurseryRemaining = communityNurseryLimit - nurseryCount;
    final outplantingRemaining = communityOutplantingLimit - outplantingCount;

    final parts = <String>[];
    if (nurseryRemaining > 0) {
      parts.add('$nurseryRemaining nursery site${nurseryRemaining != 1 ? "s" : ""}');
    }
    if (outplantingRemaining > 0) {
      parts.add('$outplantingRemaining outplanting site${outplantingRemaining != 1 ? "s" : ""}');
    }

    if (parts.isEmpty) {
      return 'Site limit reached. Upgrade for unlimited sites.';
    }

    return 'Remaining: ${parts.join(", ")}';
  }

  /// Get list of site types available for creation
  ///
  /// Returns site types that haven't reached their limit
  static List<SiteType> getAvailableSiteTypes({
    required Tier tier,
    required List<Site> existingSites,
    Site? editingSite,
  }) {
    if (tier != Tier.community) {
      // Pro/Scale: all site types available
      return SiteType.builtins.values.toSet().toList();
    }

    // Filter out the site being edited from the count check
    // This allows changing the type of an existing site even if "at limit"
    final effectiveSites = editingSite != null
        ? existingSites.where((s) => s.id != editingSite.id).toList()
        : existingSites;

    // Community: only nursery and outplanting types, if not at limit
    final available = <SiteType>[];

    if (!hasReachedNurseryLimit(tier: tier, existingSites: effectiveSites)) {
      available.addAll(nurserySiteTypes);
    }

    if (!hasReachedOutplantingLimit(tier: tier, existingSites: effectiveSites)) {
      available.addAll(outplantingSiteTypes);
    }

    // Monitoring-only sites are no longer available in Community tier
    // (moved to Pro)

    return available;
  }
}
