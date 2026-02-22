// @tier: community
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/site_limits_service.dart';

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
/// - Tier-based limits (community tier has limits per site category)
/// - Organization-configured site types (Pro/Scale)
/// - Community tier uses tier defaults to avoid blocking creation when
///   activities were limited during onboarding.
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

    final tier = organization.tier;

    // Get tier-filtered site types based on existing sites and limits
    final tierFilteredSiteTypes = SiteLimitsService.getAvailableSiteTypes(
      tier: tier,
      existingSites: existingSites,
      editingSite: editingSite,
    );

    final configuredSiteTypes = organization.siteTypes;
    late final List<SiteType> availableSiteTypes;
    if (tier == Tier.community) {
      availableSiteTypes = tierFilteredSiteTypes;
    } else if (configuredSiteTypes.isNotEmpty) {
      availableSiteTypes = configuredSiteTypes
          .where((siteType) => tierFilteredSiteTypes.contains(siteType))
          .toList();
    } else {
      availableSiteTypes = tierFilteredSiteTypes;
    }

    _logDebugInfo(
      tierFilteredSiteTypes: tierFilteredSiteTypes,
      configuredSiteTypes: configuredSiteTypes,
      availableSiteTypes: availableSiteTypes,
    );

    // If no site types available after filtering, we return empty list
    // The UI should handle the "no available sites" state (e.g. by showing an upgrade message)
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
    // Prefer outplanting as default
    for (final type in siteTypes) {
      if (type.id == SiteType.outplanting.id) {
        return type;
      }
    }
    return siteTypes.isNotEmpty ? siteTypes.first : SiteType.outplanting;
  }

  static void _logDebugInfo({
    required List<SiteType> tierFilteredSiteTypes,
    required List<SiteType> configuredSiteTypes,
    required List<SiteType> availableSiteTypes,
  }) {
    if (kDebugMode) {
      LoggingService.instance.debug(
        'SiteTypeResolver: tierFilteredSiteTypes = '
        '${tierFilteredSiteTypes.map((t) => t.id).toList()}',
      );
      LoggingService.instance.debug(
        'SiteTypeResolver: configuredSiteTypes = '
        '${configuredSiteTypes.map((t) => t.id).toList()}',
      );
      LoggingService.instance.debug(
        'SiteTypeResolver: availableSiteTypes = '
        '${availableSiteTypes.map((t) => t.id).toList()}',
      );
    }
  }
}
