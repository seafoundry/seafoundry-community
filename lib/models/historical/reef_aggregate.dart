// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Aggregated statistics for a reef from historical outplant data.
/// Stored in Firestore collection: reef_aggregates/{id}
/// Used for efficient map rendering and reef-level summaries.
class ReefAggregate extends Equatable {
  const ReefAggregate({
    required this.id,
    required this.datasetId,
    required this.reefId,
    required this.reefName,
    this.region,
    this.country,
    required this.latitude,
    required this.longitude,
    this.geohash,
    required this.totalOutplantEvents,
    required this.totalColonies,
    required this.totalSites,
    required this.totalGenotypes,
    required this.organizationCount,
    this.coloniesBySpecies = const {},
    this.earliestEvent,
    this.latestEvent,
  });

  /// Unique identifier (typically same as reefId within dataset)
  final String id;

  /// Dataset identifier (e.g., 'crc_2024')
  final String datasetId;

  /// Reef identifier (CRC or custom)
  final String reefId;

  /// Reef display name
  final String reefName;

  /// Geographic region
  final String? region;

  /// Country
  final String? country;

  /// Representative latitude for reef
  final double latitude;

  /// Representative longitude for reef
  final double longitude;

  /// Geohash for spatial queries
  final String? geohash;

  /// Total number of outplant events at this reef
  final int totalOutplantEvents;

  /// Total colonies across all events
  final int totalColonies;

  /// Total unique sites at this reef
  final int totalSites;

  /// Total unique genotypes across all events
  final int totalGenotypes;

  /// Number of organizations that have worked at this reef
  final int organizationCount;

  /// Breakdown of colonies by species ID
  /// Map of speciesId -> count
  final Map<String, int> coloniesBySpecies;

  /// Date of earliest outplant event
  final DateTime? earliestEvent;

  /// Date of most recent outplant event
  final DateTime? latestEvent;

  factory ReefAggregate.fromJson(Map<String, dynamic> json) {
    return ReefAggregate(
      id: json['id'] as String,
      datasetId: json['datasetId'] as String,
      reefId: json['reefId'] as String,
      reefName: json['reefName'] as String,
      region: json['region'] as String?,
      country: json['country'] as String?,
      latitude: safeDouble(json['latitude']) ?? 0.0,
      longitude: safeDouble(json['longitude']) ?? 0.0,
      geohash: json['geohash'] as String?,
      totalOutplantEvents: safeInt(json['totalOutplantEvents']) ?? 0,
      totalColonies: safeInt(json['totalColonies']) ?? 0,
      totalSites: safeInt(json['totalSites']) ?? 0,
      totalGenotypes: safeInt(json['totalGenotypes']) ?? 0,
      organizationCount: safeInt(json['organizationCount']) ?? 0,
      coloniesBySpecies: safeIntMap(json['coloniesBySpecies']),
      earliestEvent: json['earliestEvent'] is String
          ? DateTime.tryParse(json['earliestEvent'] as String)
          : null,
      latestEvent: json['latestEvent'] is String
          ? DateTime.tryParse(json['latestEvent'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'datasetId': datasetId,
      'reefId': reefId,
      'reefName': reefName,
      'latitude': latitude,
      'longitude': longitude,
      'totalOutplantEvents': totalOutplantEvents,
      'totalColonies': totalColonies,
      'totalSites': totalSites,
      'totalGenotypes': totalGenotypes,
      'organizationCount': organizationCount,
    };

    if (region != null) json['region'] = region;
    if (country != null) json['country'] = country;
    if (geohash != null) json['geohash'] = geohash;
    if (coloniesBySpecies.isNotEmpty) {
      json['coloniesBySpecies'] = coloniesBySpecies;
    }
    if (earliestEvent != null) {
      json['earliestEvent'] = earliestEvent!.toIso8601String();
    }
    if (latestEvent != null) {
      json['latestEvent'] = latestEvent!.toIso8601String();
    }

    return json;
  }

  ReefAggregate copyWith({
    String? id,
    String? datasetId,
    String? reefId,
    String? reefName,
    String? region,
    String? country,
    double? latitude,
    double? longitude,
    String? geohash,
    int? totalOutplantEvents,
    int? totalColonies,
    int? totalSites,
    int? totalGenotypes,
    int? organizationCount,
    Map<String, int>? coloniesBySpecies,
    DateTime? earliestEvent,
    DateTime? latestEvent,
  }) {
    return ReefAggregate(
      id: id ?? this.id,
      datasetId: datasetId ?? this.datasetId,
      reefId: reefId ?? this.reefId,
      reefName: reefName ?? this.reefName,
      region: region ?? this.region,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      totalOutplantEvents: totalOutplantEvents ?? this.totalOutplantEvents,
      totalColonies: totalColonies ?? this.totalColonies,
      totalSites: totalSites ?? this.totalSites,
      totalGenotypes: totalGenotypes ?? this.totalGenotypes,
      organizationCount: organizationCount ?? this.organizationCount,
      coloniesBySpecies: coloniesBySpecies ?? this.coloniesBySpecies,
      earliestEvent: earliestEvent ?? this.earliestEvent,
      latestEvent: latestEvent ?? this.latestEvent,
    );
  }

  @override
  List<Object?> get props => [
        id,
        datasetId,
        reefId,
        reefName,
        region,
        country,
        latitude,
        longitude,
        geohash,
        totalOutplantEvents,
        totalColonies,
        totalSites,
        totalGenotypes,
        organizationCount,
        coloniesBySpecies,
        earliestEvent,
        latestEvent,
      ];
}
