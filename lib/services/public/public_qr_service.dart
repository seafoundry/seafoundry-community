// @tier: community
import 'package:seafoundry_app/navigation/public_route.dart';

class PublicQrPayload {
  const PublicQrPayload({
    required this.surface,
    this.nodeId,
    this.orgView = PublicOrgView.highlights,
  });

  final PublicSurface surface;
  final String? nodeId;
  final PublicOrgView orgView;
}

/// Lightweight parser for kiosk / QR entry tokens.
class PublicQrService {
  static PublicQrPayload? parse(String? token) {
    if (token == null || token.trim().isEmpty) return null;
    final decoded = Uri.decodeComponent(token.trim());
    final normalized = decoded.toLowerCase();

    if (normalized == 'map' || normalized == 'impact') {
      return const PublicQrPayload(
        surface: PublicSurface.orgLanding,
        orgView: PublicOrgView.impactMap,
      );
    }

    if (normalized.startsWith('node:')) {
      final colonIndex = decoded.indexOf(':');
      if (colonIndex == -1) return null;
      final nodeId = decoded.substring(colonIndex + 1).trim();
      if (nodeId.isNotEmpty) {
        return PublicQrPayload(surface: PublicSurface.node, nodeId: nodeId);
      }
    }

    if (normalized.startsWith('orgview:impact')) {
      return const PublicQrPayload(
        surface: PublicSurface.orgLanding,
        orgView: PublicOrgView.impactMap,
      );
    }

    return null;
  }
}
