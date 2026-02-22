// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/public_read_models/impact_cluster.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_details_sheet.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/impact_point_details_content.dart';

/// Bottom sheet showing public impact point details for holdings/outplants.
class ImpactPointDetailsSheet extends StatefulWidget {
  const ImpactPointDetailsSheet({
    super.key,
    required this.cluster,
  });

  final ImpactCluster cluster;

  @override
  State<ImpactPointDetailsSheet> createState() =>
      _ImpactPointDetailsSheetState();
}

class _ImpactPointDetailsSheetState extends State<ImpactPointDetailsSheet> {
  ImpactCluster? _resolvedCluster;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolvedCluster = widget.cluster;
    _loadEnrichedCluster();
  }

  @override
  void didUpdateWidget(covariant ImpactPointDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cluster != widget.cluster) {
      _resolvedCluster = widget.cluster;
      _loadEnrichedCluster();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cluster = _resolvedCluster ?? widget.cluster;
    return HoldingsMapDetailsSheet(
      title: _titleFor(cluster),
      contentBuilder: (scrollController) {
        if (_isLoading && _needsEnrichment(widget.cluster)) {
          return const Center(child: CircularProgressIndicator());
        }
        return ImpactPointDetailsContent(
          cluster: cluster,
          scrollController: scrollController,
        );
      },
    );
  }

  bool _needsEnrichment(ImpactCluster cluster) {
    if (cluster.provenanceIdBreakdown.isNotEmpty) return false;
    if (cluster.genetBreakdown.isNotEmpty || cluster.speciesBreakdown.isNotEmpty) {
      return false;
    }
    if (cluster.sourcePoints.isEmpty) return false;
    return cluster.sourcePoints.any(
      (point) => point.metadata?['source'] == 'community_site',
    );
  }

  Future<void> _loadEnrichedCluster() async {
    final cluster = widget.cluster;
    if (!_needsEnrichment(cluster)) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final service = PublicReadModelsService();
      final futures = <Future<PublicImpactPoint?>>[];
      for (final point in cluster.sourcePoints) {
        final siteId = point.siteId?.trim();
        if (siteId == null || siteId.isEmpty) continue;
        futures.add(service.fetchImpactPointForSite(
          organizationId: point.organizationId,
          siteId: siteId,
          pointType: point.pointType,
        ));
      }
      final results = await Future.wait(futures);
      final points = results.whereType<PublicImpactPoint>().toList();
      if (!mounted) return;
      if (points.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _resolvedCluster = _aggregateCluster(cluster, points);
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to enrich impact point details',
        {'error': e.toString(), 'stackTrace': stackTrace.toString()},
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  ImpactCluster _aggregateCluster(
    ImpactCluster base,
    List<PublicImpactPoint> points,
  ) {
    var magnitude = 0;
    final genetBreakdown = <String, int>{};
    final provenanceIdBreakdown = <String, int>{};
    final speciesBreakdown = <String, int>{};

    void mergeBreakdown(Map<String, int> target, Map<String, int> incoming) {
      incoming.forEach((key, value) {
        target[key] = (target[key] ?? 0) + value;
      });
    }

    for (final point in points) {
      magnitude += point.magnitude;
      mergeBreakdown(genetBreakdown, point.genetBreakdown);
      mergeBreakdown(provenanceIdBreakdown, point.provenanceIdBreakdown);
      mergeBreakdown(speciesBreakdown, point.speciesBreakdown);
    }

    return ImpactCluster(
      id: base.id,
      latitude: base.latitude,
      longitude: base.longitude,
      pointType: base.pointType,
      magnitude: magnitude,
      label: base.label,
      count: base.count,
      siteCount: base.siteCount,
      genetBreakdown: Map.unmodifiable(genetBreakdown),
      provenanceIdBreakdown: Map.unmodifiable(provenanceIdBreakdown),
      speciesBreakdown: Map.unmodifiable(speciesBreakdown),
      siteKeys: base.siteKeys,
      sourcePoints: points,
    );
  }
}

String _titleFor(ImpactCluster cluster) {
  final isHolding = cluster.pointType == PublicImpactPointType.holding;
  final multiSite = cluster.siteCount > 1;
  final base = multiSite
      ? (isHolding ? 'Holdings' : 'Outplants')
      : (cluster.label ?? (isHolding ? 'Holdings' : 'Outplants'));
  if (multiSite) {
    return '$base (${cluster.siteCount} sites)';
  }
  return base;
}
