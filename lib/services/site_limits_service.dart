import 'package:seafoundry_community/models/site.dart';
import 'package:seafoundry_community/models/types/site_type.dart';

/// Manages site creation limits for community tier.
///
/// Community tier: 1 nursery + 1 outplanting site.
class SiteLimitsService {
  SiteLimitsService._();

  static const int communityNurseryLimit = 1;
  static const int communityOutplantingLimit = 1;

  /// Get list of site types available for creation.
  static List<SiteType> getAvailableSiteTypes({
    required List<Site> existingSites,
    Site? editingSite,
  }) {
    final effectiveSites = editingSite != null
        ? existingSites.where((s) => s.id != editingSite.id).toList()
        : existingSites;

    final available = <SiteType>[];
    if (_nurseryCount(effectiveSites) < communityNurseryLimit) {
      available.add(SiteType.nursery);
    }
    if (_outplantCount(effectiveSites) < communityOutplantingLimit) {
      available.add(SiteType.outplanting);
    }
    return available;
  }

  static int _nurseryCount(List<Site> sites) {
    return sites.where((s) => !SiteType.fromId(s.siteTypeId).isOutplanting).length;
  }

  static int _outplantCount(List<Site> sites) {
    return sites.where((s) => SiteType.fromId(s.siteTypeId).isOutplanting).length;
  }
}
