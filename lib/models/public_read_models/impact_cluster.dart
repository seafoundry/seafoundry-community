// @tier: community
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';

/// A cluster of impact points grouped by geographic proximity.
/// Used to aggregate multiple impact points into a single marker on the map.
class ImpactCluster {
  const ImpactCluster({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.pointType,
    required this.magnitude,
    this.label,
    this.count = 1,
    this.siteCount = 1,
    this.genetBreakdown = const {},
    this.provenanceIdBreakdown = const {},
    this.speciesBreakdown = const {},
    this.siteKeys = const <String>{},
    this.sourcePoints = const <PublicImpactPoint>[],
  });

  final String id;
  final double latitude;
  final double longitude;
  final PublicImpactPointType pointType;
  final int magnitude;
  final String? label;
  final int count;
  final int siteCount;
  final Map<String, int> genetBreakdown;
  final Map<String, int> provenanceIdBreakdown;
  final Map<String, int> speciesBreakdown;
  final Set<String> siteKeys;
  final List<PublicImpactPoint> sourcePoints;

  /// Creates a cluster from a single impact point.
  factory ImpactCluster.fromPoint(PublicImpactPoint point) {
    final siteKeys = _siteKeysFor(point);
    return ImpactCluster(
      id: point.id,
      latitude: point.latitude,
      longitude: point.longitude,
      pointType: point.pointType,
      magnitude: point.magnitude,
      label: point.label,
      count: 1,
      siteCount: siteKeys.isNotEmpty ? siteKeys.length : 1,
      genetBreakdown: point.genetBreakdown,
      provenanceIdBreakdown: point.provenanceIdBreakdown,
      speciesBreakdown: point.speciesBreakdown,
      siteKeys: siteKeys,
      sourcePoints: List.unmodifiable([point]),
    );
  }

  /// Merges another impact point into this cluster, returning a new cluster
  /// with averaged position and combined magnitude.
  ImpactCluster merge(PublicImpactPoint next) {
    final total = magnitude + next.magnitude;
    final mergedSiteKeys = {
      ...siteKeys,
      ..._siteKeysFor(next),
    };
    final mergedSources = sourcePoints.isEmpty
        ? List<PublicImpactPoint>.unmodifiable([next])
        : List<PublicImpactPoint>.unmodifiable([...sourcePoints, next]);
    return ImpactCluster(
      id: id,
      latitude: (latitude * count + next.latitude) / (count + 1),
      longitude: (longitude * count + next.longitude) / (count + 1),
      pointType: pointType,
      magnitude: total,
      label: label ?? next.label,
      count: count + 1,
      siteCount: mergedSiteKeys.isNotEmpty ? mergedSiteKeys.length : count + 1,
      genetBreakdown: _mergeBreakdowns(
        genetBreakdown,
        next.genetBreakdown,
      ),
      provenanceIdBreakdown: _mergeBreakdowns(
        provenanceIdBreakdown,
        next.provenanceIdBreakdown,
      ),
      speciesBreakdown: _mergeBreakdowns(
        speciesBreakdown,
        next.speciesBreakdown,
      ),
      siteKeys: mergedSiteKeys.isNotEmpty
          ? Set.unmodifiable(mergedSiteKeys)
          : const <String>{},
      sourcePoints: mergedSources,
    );
  }

  static Map<String, int> _mergeBreakdowns(
    Map<String, int> base,
    Map<String, int> incoming,
  ) {
    if (base.isEmpty && incoming.isEmpty) {
      return const {};
    }
    final merged = <String, int>{};
    merged.addAll(base);
    incoming.forEach((key, value) {
      merged[key] = (merged[key] ?? 0) + value;
    });
    return Map.unmodifiable(merged);
  }

  static Set<String> _siteKeysFor(PublicImpactPoint point) {
    final resolved =
        point.siteId?.trim().isNotEmpty == true
            ? point.siteId!.trim()
            : (point.label?.trim().isNotEmpty == true
                ? point.label!.trim()
                : point.id);
    if (resolved.isEmpty) return const <String>{};
    return {resolved};
  }
}
