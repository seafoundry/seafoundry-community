import 'package:flutter/foundation.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/models/site.dart';
import 'package:seafoundry_community/models/types/site_type.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/services/site_limits_service.dart';

/// Result of resolving available site types for site creation dialog.
class SiteTypeResolution {
  const SiteTypeResolution({
    required this.availableSiteTypes,
    required this.defaultSiteType,
  });

  /// Site types available for creation (filtered by tier and configuration).
  final List<SiteType> availableSiteTypes;

  /// The default site type to pre-select.
  final SiteType defaultSiteType;
}

/// Resolves available site types for the site creation dialog.
///
/// Handles the intersection of:
/// - Community tier limits per site category
/// - Organization-configured site types
/// - Fallback to outplanting if no types available
class SiteTypeResolver {
  SiteTypeResolver._();

  /// Resolve available site types for site creation.
  ///
  /// Returns [SiteTypeResolution] containing the available types and default.
  static Future<SiteTypeResolution> resolve({
    required Organization organization,
    required List<Site> existingSites,
    bool forceAllSiteTypes = false,
    Site? editingSite,
  }) async {
    if (forceAllSiteTypes) {
      final allSiteTypes = SiteType.builtins.values.toSet().toList();
      allSiteTypes.sort((a, b) => a.name.compareTo(b.name));
      return SiteTypeResolution(
        availableSiteTypes: allSiteTypes,
        defaultSiteType: _findDefaultSiteType(allSiteTypes),
      );
    }

    // Get available site types based on existing sites and limits
    final availableSiteTypes = SiteLimitsService.getAvailableSiteTypes(
      existingSites: existingSites,
      editingSite: editingSite,
    );

    _logDebugInfo(availableSiteTypes: availableSiteTypes);

    final effectiveSiteTypes = availableSiteTypes;

    if (kDebugMode) {
      LoggingService.instance.debug(
        'SiteTypeResolver: effectiveSiteTypes = '
        '${effectiveSiteTypes.map((t) => t.id).toList()}',
      );
    }

    // Determine default site type
    // If no types available, default will be outplanting (as a safety fallback for the bloc)
    // but the UI will see empty available types and block creation.
    final defaultSiteType = _findDefaultSiteType(effectiveSiteTypes);

    return SiteTypeResolution(
      availableSiteTypes: effectiveSiteTypes,
      defaultSiteType: defaultSiteType,
    );
  }

  static SiteType _findDefaultSiteType(List<SiteType> siteTypes) {
    // Prefer nursery as default
    for (final type in siteTypes) {
      if (type.id == SiteType.nursery.id) {
        return type;
      }
    }
    return siteTypes.isNotEmpty ? siteTypes.first : SiteType.nursery;
  }

  static void _logDebugInfo({
    required List<SiteType> availableSiteTypes,
  }) {
    if (kDebugMode) {
      LoggingService.instance.debug(
        'SiteTypeResolver: availableSiteTypes = '
        '${availableSiteTypes.map((t) => t.id).toList()}',
      );
    }
  }
}
