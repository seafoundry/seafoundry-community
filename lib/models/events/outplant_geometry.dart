// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/utils/geo_utils.dart';

/// Describes how outplant coordinates were captured so downstream tooling
/// can differentiate between manual entry, CSV ingest, or KML uploads.
enum OutplantGeometrySource {
  manual('manual'),
  csv('csv'),
  siteCentroid('site_centroid'),
  kmlUpload('kml_upload');

  const OutplantGeometrySource(this.id);
  final String id;

  static OutplantGeometrySource fromId(String? raw) {
    return OutplantGeometrySource.values.firstWhere(
      (value) => value.id == raw,
      orElse: () => OutplantGeometrySource.manual,
    );
  }
}

/// Supported geometry types; mirrored in Firestore to simplify filtering.
enum OutplantGeometryType {
  point('point'),
  multipoint('multipoint'),
  polygon('polygon'),
  boundingBox('bounding_box');

  const OutplantGeometryType(this.id);
  final String id;

  static OutplantGeometryType fromId(String? raw) {
    return OutplantGeometryType.values.firstWhere(
      (value) => value.id == raw,
      orElse: () => OutplantGeometryType.point,
    );
  }
}

class GeoCoordinate extends Equatable {
  const GeoCoordinate({required this.latitude, required this.longitude});

  factory GeoCoordinate.fromJson(Map<String, dynamic> json) {
    final lat = safeDouble(json['lat'] ?? json['latitude']);
    final lng = safeDouble(json['lng'] ?? json['longitude']);
    if (lat == null || lng == null) {
      throw ArgumentError('Invalid coordinate payload: $json');
    }
    return GeoCoordinate(latitude: lat, longitude: lng);
  }

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {'lat': latitude, 'lng': longitude};

  @override
  List<Object?> get props => [latitude, longitude];
}

class GeoBounds extends Equatable {
  const GeoBounds({required this.southWest, required this.northEast});

  factory GeoBounds.fromJson(Map<String, dynamic> json) {
    return GeoBounds(
      southWest: GeoCoordinate.fromJson(
        Map<String, dynamic>.from(json['southWest'] ?? json['sw'] ?? const {}),
      ),
      northEast: GeoCoordinate.fromJson(
        Map<String, dynamic>.from(json['northEast'] ?? json['ne'] ?? const {}),
      ),
    );
  }

  final GeoCoordinate southWest;
  final GeoCoordinate northEast;

  Map<String, dynamic> toJson() => {
    'southWest': southWest.toJson(),
    'northEast': northEast.toJson(),
  };

  @override
  List<Object?> get props => [southWest, northEast];
}

class OutplantKmlAttachment extends Equatable {
  const OutplantKmlAttachment({
    required this.storagePath,
    this.downloadUrl,
    this.fileName,
    this.fileSizeBytes,
    this.uploadedAtIso,
  });

  factory OutplantKmlAttachment.fromJson(Map<String, dynamic> json) {
    return OutplantKmlAttachment(
      storagePath: json['storagePath'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String?,
      fileName: json['fileName'] as String?,
      fileSizeBytes: safeInt(json['fileSizeBytes']),
      uploadedAtIso: json['uploadedAt'] as String?,
    );
  }

  final String storagePath;
  final String? downloadUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final String? uploadedAtIso;

  Map<String, dynamic> toJson() => {
    'storagePath': storagePath,
    if (downloadUrl != null) 'downloadUrl': downloadUrl,
    if (fileName != null) 'fileName': fileName,
    if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
    if (uploadedAtIso != null) 'uploadedAt': uploadedAtIso,
  };

  @override
  List<Object?> get props => [
    storagePath,
    downloadUrl,
    fileName,
    fileSizeBytes,
    uploadedAtIso,
  ];
}

class OutplantGeometry extends Equatable {
  const OutplantGeometry({
    required this.type,
    required this.coordinates,
    this.bounds,
    this.centroid,
    this.centroidGeohash,
    this.source = OutplantGeometrySource.manual,
    this.kmlAttachment,
    this.updatedAtIso,
  });

  factory OutplantGeometry.fromJson(Map<String, dynamic> json) {
    return OutplantGeometry(
      type: OutplantGeometryType.fromId(json['type'] as String?),
      coordinates: (json['coordinates'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GeoCoordinate.fromJson)
          .toList(),
      bounds: json['bounds'] is Map<String, dynamic>
          ? GeoBounds.fromJson(Map<String, dynamic>.from(json['bounds']))
          : null,
      centroid: json['centroid'] is Map<String, dynamic>
          ? GeoCoordinate.fromJson(Map<String, dynamic>.from(json['centroid']))
          : null,
      centroidGeohash: json['centroidGeohash'] as String?,
      source: OutplantGeometrySource.fromId(json['source'] as String?),
      kmlAttachment: json['kmlAttachment'] is Map<String, dynamic>
          ? OutplantKmlAttachment.fromJson(
              Map<String, dynamic>.from(json['kmlAttachment']),
            )
          : null,
      updatedAtIso: json['updatedAt'] as String?,
    );
  }

  static OutplantGeometry? maybeFromJson(Object? payload) {
    if (payload is Map<String, dynamic>) {
      return OutplantGeometry.fromJson(payload);
    }
    return null;
  }

  final OutplantGeometryType type;
  final List<GeoCoordinate> coordinates;
  final GeoBounds? bounds;
  final GeoCoordinate? centroid;
  final String? centroidGeohash;
  final OutplantGeometrySource source;
  final OutplantKmlAttachment? kmlAttachment;
  final String? updatedAtIso;

  bool get hasPolygon => type == OutplantGeometryType.polygon;
  bool get hasKmlAttachment => kmlAttachment != null;

  /// Computed area in hectares for polygons with at least 3 points.
  double? get areaHectares =>
      hasPolygon && coordinates.length >= 3
          ? GeoUtils.computeAreaHectares(coordinates)
          : null;

  Map<String, dynamic> toJson() => {
    'type': type.id,
    'coordinates': coordinates.map((c) => c.toJson()).toList(),
    if (bounds != null) 'bounds': bounds!.toJson(),
    if (centroid != null) 'centroid': centroid!.toJson(),
    if (centroidGeohash != null) 'centroidGeohash': centroidGeohash,
    'source': source.id,
    if (kmlAttachment != null) 'kmlAttachment': kmlAttachment!.toJson(),
    if (updatedAtIso != null) 'updatedAt': updatedAtIso,
  };

  OutplantGeometry copyWith({
    OutplantGeometryType? type,
    List<GeoCoordinate>? coordinates,
    GeoBounds? bounds,
    GeoCoordinate? centroid,
    String? centroidGeohash,
    OutplantGeometrySource? source,
    OutplantKmlAttachment? kmlAttachment,
    String? updatedAtIso,
    Map<String, dynamic>? metadata,
  }) {
    return OutplantGeometry(
      type: type ?? this.type,
      coordinates: coordinates ?? this.coordinates,
      bounds: bounds ?? this.bounds,
      centroid: centroid ?? this.centroid,
      centroidGeohash: centroidGeohash ?? this.centroidGeohash,
      source: source ?? this.source,
      kmlAttachment: kmlAttachment ?? this.kmlAttachment,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  @override
  List<Object?> get props => [
    type,
    coordinates,
    bounds,
    centroid,
    centroidGeohash,
    source,
    kmlAttachment,
    updatedAtIso,
  ];
}

class OutplantGeometryInput extends Equatable {
  OutplantGeometryInput({
    required this.type,
    required List<GeoCoordinate> coordinates,
    this.source = OutplantGeometrySource.manual,
    this.kmlAttachment,
  }) : coordinates = List.unmodifiable(coordinates);

  final OutplantGeometryType type;
  final List<GeoCoordinate> coordinates;
  final OutplantGeometrySource source;
  final OutplantKmlAttachment? kmlAttachment;

  bool get hasCoordinates => coordinates.isNotEmpty;

  @override
  List<Object?> get props => [type, coordinates, source, kmlAttachment];
}
