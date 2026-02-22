// @tier: community
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/widgets/graph_node/site_summary_models.dart';

SiteSummaryMetricGroup buildGeometryMetricGroup(Site site) {
  final geometry = site.geometry;
  if (geometry == null) {
    return const SiteSummaryMetricGroup(
      title: 'Geometry',
      metrics: [
        SiteSummaryMetric(
          label: 'Status',
          value: 'Not configured',
          helper:
              'Add a centroid, bounding box, or upload a KML to enable map overlays.',
        ),
      ],
    );
  }

  final centroid = geometry.centroid ?? site.centroid;
  final bounds = geometry.bounds ?? site.bounds;
  final points = site.placements.length;
  final updated = geometry.updatedAtIso ?? site.updatedAt;

  final metrics = <SiteSummaryMetric>[
    SiteSummaryMetric(
      label: 'Status',
      value: _titleCase(geometry.type.id.replaceAll('_', ' ')),
    ),
    SiteSummaryMetric(
      label: 'Coordinate Count',
      value: '$points',
    ),
    SiteSummaryMetric(
      label: 'Updated',
      value: _formatIsoDate(updated),
    ),
  ];

  if (centroid != null) {
    metrics.add(
      SiteSummaryMetric(
        label: 'Centroid',
        value:
            '${centroid.latitude.toStringAsFixed(3)}°, ${centroid.longitude.toStringAsFixed(3)}°',
      ),
    );
  }

  if (bounds != null) {
    metrics.add(
      SiteSummaryMetric(
        label: 'Bounds',
        value:
            '${bounds.southWest.latitude.toStringAsFixed(3)}°/${bounds.southWest.longitude.toStringAsFixed(3)}°'
            ' → ${bounds.northEast.latitude.toStringAsFixed(3)}°/${bounds.northEast.longitude.toStringAsFixed(3)}°',
      ),
    );
  }

  return SiteSummaryMetricGroup(title: 'Geometry', metrics: metrics);
}

String formatLatestDate(Iterable<DateTime?> dates) {
  final parsed = dates.whereType<DateTime>().toList();
  if (parsed.isEmpty) {
    return '—';
  }
  parsed.sort();
  return _formatDate(parsed.last);
}

String _formatIsoDate(String? value) {
  if (value == null || value.isEmpty) {
    return '—';
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null ? _formatDate(parsed) : value;
}

String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _titleCase(String value) {
  final words = value.split(RegExp(r'[\s_]+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
