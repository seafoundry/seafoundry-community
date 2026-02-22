// @tier: community
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Centralises the rules for when permit metadata should be surfaced or
/// required across dialogs, spreadsheets, and CSV previews.
class PermitMetadataPolicy {
  const PermitMetadataPolicy._();

  /// Returns true when the provided site allows operators to enter permit
  /// metadata. Falls back to `true` when no site has been resolved yet so the
  /// UI can optimistically render while the GraphNode hydrates.
  static bool siteSupportsPermits(Site? site) {
    if (site == null) {
      return true;
    }
    final capabilities = SiteCapabilities.resolve(site.siteType);
    return capabilities.supportsPermitUpload;
  }

  /// Whether permits should be required for the provided organism kind. The
  /// mappings follow the regulatory table in docs/taxonomy/README.md (NOAA,
  /// NSSP, USACE, DEP, WOAH, etc.).
  static bool requiresPermit(OrganismKind? kind) {
    if (kind == null) {
      return false;
    }
    return _organismsWithMandates.contains(kind);
  }

  /// Human-readable helper for tooltips / helper text.
  static String requirementLabel(OrganismKind kind) {
    return requiresPermit(kind) ? 'Permit metadata required' : 'Permit metadata';
  }

  static const Set<OrganismKind> _organismsWithMandates = {
    OrganismKind.coral,
    OrganismKind.oyster,
    OrganismKind.kelp,
    OrganismKind.mangrove,
    OrganismKind.finfish,
  };
}
