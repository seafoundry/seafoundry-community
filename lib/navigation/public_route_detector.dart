// @tier: community
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/navigation/public_route.dart';
import 'package:seafoundry_app/services/public/public_qr_service.dart';

/// PublicRouteDetector identifies org-specific public hosts + routes.
class PublicRouteDetector {
  static PublicRouteConfig? resolve({Uri? uriOverride}) {
    final uri = uriOverride ?? Uri.base;
    final resolution = _resolveOrg(uri);
    final orgId = resolution.orgId;
    if (orgId == null) return null;

    final kiosk = _kioskRequested(uriOverride: uriOverride ?? uri);
    final preview = _previewRequested(uriOverride: uriOverride ?? uri);
    final qrPayload = PublicQrService.parse(uri.queryParameters['qr']);

    if (qrPayload != null &&
        qrPayload.surface == PublicSurface.node &&
        qrPayload.nodeId != null) {
      return PublicRouteConfig(
        orgId: orgId,
        surface: PublicSurface.node,
        nodeId: qrPayload.nodeId,
        kiosk: kiosk,
        preview: preview,
        fromQr: true,
      );
    }

    return _resolveSurfaceFromSegments(
      orgId: orgId,
      segments: resolution.remainingSegments,
      kiosk: kiosk,
      preview: preview,
      qrPayload: qrPayload,
    );
  }

  static bool isPublicOrgHost() => resolve() != null;

  static bool isKioskRoute() => resolve()?.kiosk == true;

  static bool isPreviewMode() => resolve()?.preview == true;

  /// Check if the current host is the main app domain (e.g., provenance.seafoundry.com)
  /// These are domains that should show the public landing page for unauthenticated users
  static bool isMainAppDomain() {
    if (!kIsWeb) return false;
    final host = Uri.base.host.toLowerCase();
    // Main app domains that should show public landing instead of auth
    const mainAppDomains = {
      'provenance.seafoundry.com',
      'seafoundryapp.web.app',
      'seafoundryapp.firebaseapp.com',
    };
    return mainAppDomains.contains(host);
  }

  static _OrgResolution _resolveOrg(Uri uri) {
    final baseSegments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final pathResolution = _orgIdFromPath(baseSegments);
    if (pathResolution != null) {
      return pathResolution;
    }

    final hostOrg = _orgSubdomain(uriOverride: uri);
    if (hostOrg != null) {
      return _OrgResolution(orgId: hostOrg, remainingSegments: baseSegments);
    }

    return _OrgResolution(orgId: null, remainingSegments: baseSegments);
  }

  static _OrgResolution? _orgIdFromPath(List<String> segments) {
    if (segments.length >= 3 &&
        segments[0].toLowerCase() == 'public' &&
        segments[1].toLowerCase() == 'org') {
      return _OrgResolution(
        orgId: segments[2],
        remainingSegments: segments.sublist(3),
      );
    }

    if (segments.length >= 2 && segments[0].toLowerCase() == 'org') {
      return _OrgResolution(
        orgId: segments[1],
        remainingSegments: segments.sublist(2),
      );
    }

    if (segments.length >= 4 &&
        segments[0].toLowerCase() == 'public' &&
        segments[1].toLowerCase() == 'node') {
      return _OrgResolution(
        orgId: segments[2],
        remainingSegments: ['node', segments[3], ...segments.sublist(4)],
      );
    }
    return null;
  }

  static PublicRouteConfig _resolveSurfaceFromSegments({
    required String orgId,
    required List<String> segments,
    required bool kiosk,
    required bool preview,
    PublicQrPayload? qrPayload,
  }) {
    final trimmed = _trimmedSegments(segments);
    final normalized = trimmed.map((s) => s.toLowerCase()).toList();

    if (normalized.isNotEmpty &&
        normalized.first == 'node' &&
        trimmed.length >= 2) {
      return PublicRouteConfig(
        orgId: orgId,
        surface: PublicSurface.node,
        nodeId: trimmed[1],
        kiosk: kiosk,
        preview: preview,
        fromQr: qrPayload != null,
      );
    }

    PublicOrgView view = qrPayload?.orgView ?? PublicOrgView.highlights;
    if (normalized.isNotEmpty &&
        (normalized.first == 'impact' || normalized.first == 'map')) {
      if (normalized.length >= 2 && normalized[1] == 'full') {
        return PublicRouteConfig(
          orgId: orgId,
          surface: PublicSurface.orgMap,
          kiosk: kiosk,
          preview: preview,
          orgView: PublicOrgView.impactMap,
          fromQr: qrPayload?.surface == PublicSurface.orgLanding,
        );
      }
      view = PublicOrgView.impactMap;
    }

    return PublicRouteConfig(
      orgId: orgId,
      surface: PublicSurface.orgLanding,
      orgView: view,
      kiosk: kiosk,
      preview: preview,
      fromQr:
          qrPayload != null && qrPayload.surface == PublicSurface.orgLanding,
    );
  }

  static List<String> _trimmedSegments(List<String> segments) {
    final result = <String>[];
    var skipPublicPrefix = true;
    for (final segment in segments) {
      final normalized = segment.toLowerCase();
      if (skipPublicPrefix && normalized == 'public') {
        continue;
      }
      skipPublicPrefix = false;
      result.add(segment);
    }
    return result;
  }

  static String? _orgSubdomain({Uri? uriOverride}) {
    if (!kIsWeb && uriOverride == null) return null;
    final host = (uriOverride ?? Uri.base).host;
    if (host.isEmpty) return null;
    final parts = host.split('.');
    if (parts.length < 2) return null;
    final subdomain = parts.first;
    const blocked = {'www', 'app', 'beta', 'seafoundryapp', 'provenance'};
    if (blocked.contains(subdomain.toLowerCase())) return null;
    return subdomain;
  }

  static bool _kioskRequested({Uri? uriOverride}) {
    if (!kIsWeb && uriOverride == null) return false;
    final uri = uriOverride ?? Uri.base;
    final kioskParam = uri.queryParameters['kiosk'];
    if (kioskParam != null) {
      final normalized = kioskParam.toLowerCase();
      if (normalized == '1' || normalized == 'true') {
        return true;
      }
    }
    return uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .any((segment) => segment.toLowerCase() == 'kiosk');
  }

  static bool _previewRequested({Uri? uriOverride}) {
    if (!kIsWeb && uriOverride == null) return false;
    final uri = uriOverride ?? Uri.base;
    final preview = uri.queryParameters['preview'];
    if (preview == null) return false;
    final normalized = preview.toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
}

class _OrgResolution {
  const _OrgResolution({required this.orgId, required this.remainingSegments});

  final String? orgId;
  final List<String> remainingSegments;
}
