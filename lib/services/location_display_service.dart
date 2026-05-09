// @tier: community
import 'package:seafoundry_app/utils/location_path.dart';

/// Centralized formatter for location labels across sheets and interfaces.
class LocationDisplayService {
  static String formatFromRecordPath(
    String? urlPath, {
    String? organizationDomain,
    String? fallback,
  }) {
    if (urlPath == null || urlPath.isEmpty) {
      return fallback ?? '';
    }
    final resolvedDomain = _resolveDomain(organizationDomain, urlPath);
    final path = formatLocationPathFromRecord(
      urlPath: urlPath,
      organizationDomain: resolvedDomain,
    );
    return _withFallback(path, fallback);
  }

  static String? _resolveDomain(String? provided, String? urlPath) {
    if (provided != null && provided.isNotEmpty) return provided;
    return _organizationDomainFromPath(urlPath);
  }

  static String? _organizationDomainFromPath(String? urlPath) {
    if (urlPath == null || urlPath.isEmpty) return null;
    for (final segment in urlPath.split('/')) {
      final trimmed = segment.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String _withFallback(String path, String? fallback) {
    if (path.isNotEmpty) return path;
    return fallback ?? '';
  }
}
