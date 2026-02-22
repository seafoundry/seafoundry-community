// @tier: community
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';

/// Represents a single geometry series to render on the map.
class GeometrySeries {
  const GeometrySeries({
    required this.label,
    required this.geometry,
    required this.color,
    this.subtitle,
  });

  final String label;
  final OutplantGeometry geometry;
  final Color color;
  final String? subtitle;

  bool get hasKmlAttachment => geometry.hasKmlAttachment;
}

/// Lightweight renderer that sketches geometry into a canvas so dialogs can
/// preview coordinates without loading Google Maps (also works on web/tests).
class GeometryMap extends StatelessWidget {
  const GeometryMap({
    super.key,
    required this.series,
    this.siteBounds,
    this.siteCentroid,
    this.showBounds = true,
    this.emptyLabel = 'No geometry available yet.',
    this.maxHeight,
  });

  final List<GeometrySeries> series;
  final GeoBounds? siteBounds;
  final GeoCoordinate? siteCentroid;
  final bool showBounds;
  final String emptyLabel;
  final double? maxHeight;

  List<String> get _kmlLabels => series
      .where((entry) => entry.geometry.hasKmlAttachment)
      .map((entry) => entry.label)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty && siteBounds == null && siteCentroid == null) {
      return _EmptyGeometryMap(label: emptyLabel);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = _resolveSize(constraints);
        final mapWidget = _buildMap(context, resolved);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mapWidget,
            if (_kmlLabels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _KmlNotice(labels: _kmlLabels),
              ),
            if (series.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _GeometryLegend(entries: series),
              ),
          ],
        );
      },
    );
  }

  _MapSize _resolveSize(BoxConstraints constraints) {
    const targetAspectRatio = 1.2;
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : 320.0;
    final constraintHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : double.infinity;
    var heightLimit = constraintHeight;
    if (maxHeight != null) {
      heightLimit = heightLimit.isFinite
          ? math.min(heightLimit, maxHeight!)
          : maxHeight!;
    }

    double mapWidth = maxWidth;
    double mapHeight = mapWidth / targetAspectRatio;

    if (heightLimit.isFinite && mapHeight > heightLimit) {
      mapHeight = heightLimit;
      mapWidth = mapHeight * targetAspectRatio;
    }

    mapHeight = mapHeight.clamp(140.0, double.infinity);
    mapWidth = mapWidth.clamp(140.0, double.infinity);
    return _MapSize(width: mapWidth, height: mapHeight);
  }

  Widget _buildMap(BuildContext context, _MapSize size) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _GeometryPainter(
                series: series,
                siteBounds: siteBounds,
                siteCentroid: siteCentroid,
                showBounds: showBounds,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience holder for computed map width/height.
class _MapSize {
  const _MapSize({required this.width, required this.height});
  final double width;
  final double height;
}

/// Paints the geometry series onto the off-screen canvas.
class _GeometryPainter extends CustomPainter {
  _GeometryPainter({
    required this.series,
    required this.siteBounds,
    required this.siteCentroid,
    required this.showBounds,
  });

  final List<GeometrySeries> series;
  final GeoBounds? siteBounds;
  final GeoCoordinate? siteCentroid;
  final bool showBounds;

  late final _Projection _projection = _Projection(
    siteBounds: siteBounds,
    siteCentroid: siteCentroid,
    series: series,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (!_projection.hasDomain) {
      return;
    }

    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    if (showBounds && siteBounds != null) {
      final boundsRect = _projection.boundsRect(size, siteBounds!);
      final boundsPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.blueGrey.shade400
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawRect(boundsRect, boundsPaint);
    }

    if (siteCentroid != null) {
      final center = _projection.project(siteCentroid!, size);
      final centerPaint = Paint()
        ..color = Colors.blueGrey.shade600
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 6, centerPaint);
    }

    for (final entry in series) {
      final geometry = entry.geometry;
      final strokePaint = Paint()
        ..color = entry.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final fillPaint = Paint()
        ..color = entry.color.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;

      if (geometry.bounds != null) {
        final rect = _projection.boundsRect(size, geometry.bounds!);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
      }

      if (geometry.coordinates.isNotEmpty) {
        final path = Path();
        for (var i = 0; i < geometry.coordinates.length; i++) {
          final projected = _projection.project(geometry.coordinates[i], size);
          if (i == 0) {
            path.moveTo(projected.dx, projected.dy);
          } else {
            path.lineTo(projected.dx, projected.dy);
          }
        }

        switch (geometry.type) {
          case OutplantGeometryType.polygon:
            if (geometry.coordinates.length >= 3) {
              path.close();
              canvas.drawPath(path, fillPaint);
              canvas.drawPath(path, strokePaint);
            }
            break;
          case OutplantGeometryType.boundingBox:
            // already handled via bounds
            break;
          case OutplantGeometryType.multipoint:
          case OutplantGeometryType.point:
            for (final coordinate in geometry.coordinates) {
              final projected = _projection.project(coordinate, size);
              canvas.drawCircle(
                projected,
                5,
                strokePaint..style = PaintingStyle.fill,
              );
            }
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeometryPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.siteBounds != siteBounds ||
        oldDelegate.siteCentroid != siteCentroid ||
        oldDelegate.showBounds != showBounds;
  }
}

/// Projects lat/lng coordinates into canvas positions and cached bounds.
class _Projection {
  _Projection({
    required this.series,
    required this.siteBounds,
    required this.siteCentroid,
  }) {
    _computeDomain();
  }

  final List<GeometrySeries> series;
  final GeoBounds? siteBounds;
  final GeoCoordinate? siteCentroid;

  double? _minLat;
  double? _maxLat;
  double? _minLng;
  double? _maxLng;

  bool get hasDomain =>
      _minLat != null && _maxLat != null && _minLng != null && _maxLng != null;

  void _computeDomain() {
    final latitudes = <double>[];
    final longitudes = <double>[];

    void addCoordinate(GeoCoordinate coordinate) {
      latitudes.add(coordinate.latitude);
      longitudes.add(coordinate.longitude);
    }

    if (siteBounds != null) {
      addCoordinate(siteBounds!.southWest);
      addCoordinate(siteBounds!.northEast);
    }

    if (siteCentroid != null) {
      addCoordinate(siteCentroid!);
    }

    for (final entry in series) {
      final geometry = entry.geometry;
      for (final coordinate in geometry.coordinates) {
        addCoordinate(coordinate);
      }
      final bounds = geometry.bounds;
      if (bounds != null) {
        addCoordinate(bounds.northEast);
        addCoordinate(bounds.southWest);
      }
    }

    if (latitudes.isEmpty || longitudes.isEmpty) {
      return;
    }

    _minLat = latitudes.reduce(math.min);
    _maxLat = latitudes.reduce(math.max);
    _minLng = longitudes.reduce(math.min);
    _maxLng = longitudes.reduce(math.max);

    // Ensure we have some range to avoid divide-by-zero.
    if ((_maxLat! - _minLat!).abs() < 1e-6) {
      _maxLat = _maxLat! + 0.001;
      _minLat = _minLat! - 0.001;
    }

    if ((_maxLng! - _minLng!).abs() < 1e-6) {
      _maxLng = _maxLng! + 0.001;
      _minLng = _minLng! - 0.001;
    }
  }

  Offset project(GeoCoordinate coordinate, Size size) {
    final width = size.width;
    final height = size.height;

    final x =
        ((coordinate.longitude - _minLng!) / (_maxLng! - _minLng!)) * width;
    final y =
        height -
        ((coordinate.latitude - _minLat!) / (_maxLat! - _minLat!)) * height;

    return Offset(x, y);
  }

  Rect boundsRect(Size size, GeoBounds bounds) {
    final sw = project(bounds.southWest, size);
    final ne = project(bounds.northEast, size);
    final left = math.min(sw.dx, ne.dx);
    final top = math.min(sw.dy, ne.dy);
    final right = math.max(sw.dx, ne.dx);
    final bottom = math.max(sw.dy, ne.dy);
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Renders a color/label legend for each geometry series.
class _GeometryLegend extends StatelessWidget {
  const _GeometryLegend({required this.entries});

  final List<GeometrySeries> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: entries
          .map(
            (entry) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: entry.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(entry.label, style: Theme.of(context).textTheme.bodySmall),
                if (entry.subtitle != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    entry.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Displays a chip highlighting when the preview includes KML overlays.
class _KmlNotice extends StatelessWidget {
  const _KmlNotice({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = labels.length == 1
        ? 'KML overlay available for ${labels.first}'
        : 'KML overlays available for ${labels.length} events';
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          Icons.layers,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        backgroundColor: theme.colorScheme.secondaryContainer,
        label: Text(labelText),
      ),
    );
  }
}

/// Placeholder shown when there is no geometry to render yet.
class _EmptyGeometryMap extends StatelessWidget {
  const _EmptyGeometryMap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}
