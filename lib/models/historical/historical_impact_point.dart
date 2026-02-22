// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Sanitized historical outplant data point for public map display.
/// Similar to PublicImpactPoint but for historical datasets (CRC, etc.)
/// Stored in Firestore collection: historical_impact_points/{id}
class HistoricalImpactPoint extends Equatable {
  const HistoricalImpactPoint({
    required this.id,
    required this.datasetId,
    required this.latitude,
    required this.longitude,
    required this.magnitude,
    this.label,
    this.reefId,
    this.reefName,
    this.region,
    this.speciesId,
    this.speciesName,
    this.organizationAlias,
  });

  /// Unique identifier
  final String id;

  /// Dataset identifier (e.g., 'crc_2024')
  final String datasetId;

  /// Latitude of site/event
  final double latitude;

  /// Longitude of site/event
  final double longitude;

  /// Total colonies/organisms at this point
  final int magnitude;

  /// Display label (site name, reef name, etc.)
  final String? label;

  /// Reef ID (for filtering)
  final String? reefId;

  /// Reef name (for display)
  final String? reefName;

  /// Region (for filtering)
  final String? region;

  /// Species ID (for filtering)
  final String? speciesId;

  /// Species name (for display)
  final String? speciesName;

  /// Organization alias (anonymized, e.g., 'org_a')
  final String? organizationAlias;

  factory HistoricalImpactPoint.fromJson(Map<String, dynamic> json) {
    return HistoricalImpactPoint(
      id: json['id'] as String,
      datasetId: json['datasetId'] as String,
      latitude: safeDouble(json['latitude']) ?? 0.0,
      longitude: safeDouble(json['longitude']) ?? 0.0,
      magnitude: safeInt(json['magnitude']) ?? 0,
      label: json['label'] as String?,
      reefId: json['reefId'] as String?,
      reefName: json['reefName'] as String?,
      region: json['region'] as String?,
      speciesId: json['speciesId'] as String?,
      speciesName: json['speciesName'] as String?,
      organizationAlias: json['organizationAlias'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'datasetId': datasetId,
      'latitude': latitude,
      'longitude': longitude,
      'magnitude': magnitude,
    };

    if (label != null) json['label'] = label;
    if (reefId != null) json['reefId'] = reefId;
    if (reefName != null) json['reefName'] = reefName;
    if (region != null) json['region'] = region;
    if (speciesId != null) json['speciesId'] = speciesId;
    if (speciesName != null) json['speciesName'] = speciesName;
    if (organizationAlias != null) json['organizationAlias'] = organizationAlias;

    return json;
  }

  HistoricalImpactPoint copyWith({
    String? id,
    String? datasetId,
    double? latitude,
    double? longitude,
    int? magnitude,
    String? label,
    String? reefId,
    String? reefName,
    String? region,
    String? speciesId,
    String? speciesName,
    String? organizationAlias,
  }) {
    return HistoricalImpactPoint(
      id: id ?? this.id,
      datasetId: datasetId ?? this.datasetId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      magnitude: magnitude ?? this.magnitude,
      label: label ?? this.label,
      reefId: reefId ?? this.reefId,
      reefName: reefName ?? this.reefName,
      region: region ?? this.region,
      speciesId: speciesId ?? this.speciesId,
      speciesName: speciesName ?? this.speciesName,
      organizationAlias: organizationAlias ?? this.organizationAlias,
    );
  }

  @override
  List<Object?> get props => [
        id,
        datasetId,
        latitude,
        longitude,
        magnitude,
        label,
        reefId,
        reefName,
        region,
        speciesId,
        speciesName,
        organizationAlias,
      ];
}
