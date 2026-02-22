// @tier: community
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/utils/geo_utils.dart';

class OutplantGeometryBuilder {
  const OutplantGeometryBuilder({
    this.maxCoordinatePoints = 250,
    this.siteMaxDistanceMiles = 0.25,
    this.geohashPrecision = 7,
  });

  final int maxCoordinatePoints;
  final double siteMaxDistanceMiles;
  final int geohashPrecision;

  OutplantGeometry build({
    required OutplantGeometryInput input,
    GeoCoordinate? siteCentroid,
    String? updatedAtIso,
  }) {
    final coordinates = input.coordinates;
    if (coordinates.isEmpty) {
      throw ArgumentError('At least one coordinate is required.');
    }
    if (coordinates.length > maxCoordinatePoints) {
      throw ArgumentError(
        'Too many coordinates (${coordinates.length}); '
        'limit is $maxCoordinatePoints.',
      );
    }

    for (final coord in coordinates) {
      if (!GeoUtils.isValidLatitude(coord.latitude) ||
          !GeoUtils.isValidLongitude(coord.longitude)) {
        throw ArgumentError('Invalid coordinate encountered: $coord');
      }
      if (siteCentroid != null &&
          !GeoUtils.isWithinDistanceMiles(
            coordinate: coord,
            center: siteCentroid,
            maxDistanceMiles: siteMaxDistanceMiles,
          )) {
        final distance = GeoUtils.distanceMiles(coord, siteCentroid);
        throw ArgumentError(
          'Coordinate $coord is ${distance.toStringAsFixed(2)} mi from site centroid '
          '(${siteCentroid.latitude}, ${siteCentroid.longitude}); '
          'max allowed is ${siteMaxDistanceMiles.toStringAsFixed(2)} mi.',
        );
      }
    }

    final bounds = GeoUtils.computeBounds(coordinates);
    final centroid = GeoUtils.computeCentroid(coordinates);
    final geohash = GeoUtils.encodeGeohash(
      centroid,
      precision: geohashPrecision,
    );

    return OutplantGeometry(
      type: input.type,
      coordinates: coordinates,
      bounds: bounds,
      centroid: centroid,
      centroidGeohash: geohash,
      source: input.source,
      kmlAttachment: input.kmlAttachment,
      updatedAtIso: updatedAtIso ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}
