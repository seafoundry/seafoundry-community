// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/utils/location_path.dart';

/// Centralized formatter for location labels across sheets and interfaces.
class LocationDisplayService {
  static String formatFromEvent(
    Event event, {
    String? organizationDomain,
    String? fallback,
  }) {
    final resolvedDomain = _resolveDomain(organizationDomain, event.urlPath);
    final path = formatLocationPathFromEvent(
      urlPath: event.urlPath,
      recordModelType: event.recordModelType,
      organizationDomain: resolvedDomain,
    );
    return _withFallback(path, fallback);
  }

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

  static String formatFromPath(
    String? urlPath, {
    String? organizationDomain,
    String? fallback,
  }) {
    if (urlPath == null || urlPath.isEmpty) {
      return fallback ?? '';
    }
    final resolvedDomain = _resolveDomain(organizationDomain, urlPath);
    final path = formatLocationPathFromPath(
      urlPath: urlPath,
      organizationDomain: resolvedDomain,
    );
    return _withFallback(path, fallback);
  }

  static String formatFromPaths(
    Iterable<String> urlPaths, {
    String? organizationDomain,
    String? fallback,
  }) {
    final resolvedDomain = organizationDomain?.isNotEmpty == true
        ? organizationDomain
        : _domainFromPaths(urlPaths);
    final formatted =
        urlPaths
            .map(
              (path) =>
                  formatLocationPathFromPath(
                    urlPath: path,
                    organizationDomain: resolvedDomain,
                  ),
            )
            .where((path) => path.isNotEmpty)
            .toList();
    if (formatted.isEmpty) {
      return fallback ?? '';
    }
    formatted.sort();
    return formatted.join(', ');
  }

  static String formatFromGroupOrSitePath({
    String? groupPath,
    String? sitePath,
    String? organizationDomain,
    String? fallback,
  }) {
    if (groupPath != null && groupPath.isNotEmpty) {
      return formatFromPath(
        groupPath,
        organizationDomain: organizationDomain,
        fallback: fallback,
      );
    }
    if (sitePath != null && sitePath.isNotEmpty) {
      return formatFromPath(
        sitePath,
        organizationDomain: organizationDomain,
        fallback: fallback,
      );
    }
    return fallback ?? '';
  }

  static String? organizationDomainFromPath(String? urlPath) {
    if (urlPath == null || urlPath.isEmpty) return null;
    for (final segment in urlPath.split('/')) {
      final trimmed = segment.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String? _resolveDomain(String? provided, String? urlPath) {
    if (provided != null && provided.isNotEmpty) return provided;
    return organizationDomainFromPath(urlPath);
  }

  static String? _domainFromPaths(Iterable<String> urlPaths) {
    for (final path in urlPaths) {
      final resolved = organizationDomainFromPath(path);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
    return null;
  }

  static String _withFallback(String path, String? fallback) {
    if (path.isNotEmpty) return path;
    return fallback ?? '';
  }
}
