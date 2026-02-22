// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Describes which organisms are actionable for a graph node along with site
/// support metadata so the action dock can surface appropriate selectors,
/// warnings, and placeholders.
class OrganismAvailability {
  const OrganismAvailability({
    required this.activeOrganisms,
    required this.siteSupported,
    required this.missingFromSite,
    required this.dataBacked,
  });

  /// Organisms shown in the selector. Prefers data-backed kinds but falls back
  /// to the site's supported organisms when no live data exists so empty-state
  /// placeholders can guide the user.
  final List<OrganismKind> activeOrganisms;

  /// All organisms enabled for the current site (or organization when no site).
  final List<OrganismKind> siteSupported;

  /// Organisms supported by the organization but not yet enabled for the site.
  final List<OrganismKind> missingFromSite;

  /// Organisms that have live data (holdings, corals, descendants) in scope.
  final Set<OrganismKind> dataBacked;

  factory OrganismAvailability.resolve({
    required Iterable<OrganismKind> organizationKinds,
    required Iterable<OrganismKind> siteSupportedKinds,
    required Iterable<OrganismKind> detectedOrganisms,
  }) {
    final organizationSet = organizationKinds.toSet();
    final siteSupportedSet =
        organizationSet.isNotEmpty
            ? siteSupportedKinds.where(organizationSet.contains).toSet()
            : siteSupportedKinds.toSet();
    final resolvedSiteSupported =
        siteSupportedSet.isNotEmpty ? siteSupportedSet : organizationSet;
    final detectedSet =
        detectedOrganisms.where(resolvedSiteSupported.contains).toSet();

    final active = detectedSet.isNotEmpty ? detectedSet : resolvedSiteSupported;
    final missing = organizationKinds
        .where((kind) => !resolvedSiteSupported.contains(kind))
        .toSet();

    return OrganismAvailability(
      activeOrganisms: _sort(active),
      siteSupported: _sort(resolvedSiteSupported),
      missingFromSite: _sort(missing),
      dataBacked: detectedSet,
    );
  }

  static List<OrganismKind> _sort(Iterable<OrganismKind> kinds) {
    final list = kinds.toSet().toList();
    list.sort(
      (a, b) => a.metadata.displayName.compareTo(b.metadata.displayName),
    );
    return list;
  }
}
