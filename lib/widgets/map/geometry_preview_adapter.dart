// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/map/geometry_map.dart';

/// Helper that converts domain models into [GeometrySeries] collections for
/// `GeometryMap` preview surfaces.
class GeometryPreviewAdapter {
  const GeometryPreviewAdapter._();

  static const List<Color> _palette = <Color>[
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.redAccent,
    Colors.indigo,
  ];

  /// Builds [GeometrySeries] entries for outplant events, skipping any without
  /// geometry or coordinate data.
  static List<GeometrySeries> outplantSeries(
    List<OutplantEvent> events, {
    List<Color>? palette,
  }) {
    if (events.isEmpty) return const <GeometrySeries>[];

    final colors = palette == null || palette.isEmpty ? _palette : palette;
    final series = <GeometrySeries>[];

    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      final geometry = event.geometry;
      if (geometry == null || geometry.coordinates.isEmpty) {
        continue;
      }

      final subtitle = event.allocations.isEmpty
          ? null
          : event.allocations
                .map(
                  (allocation) =>
                      SpeciesRegistry.globalById(allocation.speciesId)?.code ??
                      allocation.speciesId.toUpperCase(),
                )
                .toSet()
                .join(', ');

      series.add(
        GeometrySeries(
          label: event.name,
          geometry: geometry,
          color: colors[index % colors.length],
          subtitle: subtitle,
        ),
      );
    }

    return series;
  }

  /// Builds a [GeometrySeries] for a site's geometry, if present.
  static GeometrySeries? siteSeries(
    Site site, {
    Color color = Colors.blueGrey,
  }) {
    final geometry = site.geometry;
    if (geometry == null || geometry.coordinates.isEmpty) {
      return null;
    }

    final subtitle = site.siteType.name;

    return GeometrySeries(
      label: site.name,
      geometry: geometry,
      color: color,
      subtitle: subtitle,
    );
  }
}
