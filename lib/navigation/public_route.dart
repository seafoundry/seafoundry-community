// @tier: community

/// Public surfaces exposed via the Community Visual Engagement stack.
enum PublicSurface { orgLanding, orgMap, node }

/// Sections inside the org landing page.
enum PublicOrgView { highlights, impactMap }

/// Route configuration derived from the host + query parameters.
class PublicRouteConfig {
  const PublicRouteConfig({
    required this.orgId,
    required this.surface,
    this.nodeId,
    this.orgView = PublicOrgView.highlights,
    this.kiosk = false,
    this.preview = false,
    this.fromQr = false,
  });

  final String orgId;
  final PublicSurface surface;
  final String? nodeId;
  final PublicOrgView orgView;
  final bool kiosk;
  final bool preview;
  final bool fromQr;
}
