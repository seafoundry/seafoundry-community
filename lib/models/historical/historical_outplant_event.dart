// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/historical/historical_genotype.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Full detail for a historical outplant event from CRC or similar datasets.
/// Stored in Firestore collection: historical_outplant_events/{id}
class HistoricalOutplantEvent extends Equatable {
  const HistoricalOutplantEvent({
    required this.id,
    required this.datasetId,
    required this.source,
    required this.sourceEventId,
    required this.organismKind,
    this.speciesId,
    this.speciesName,
    required this.lifeStage,
    this.provenanceType,
    this.provenanceConfidence,
    required this.sizeSpec,
    required this.magnitude,
    required this.latitude,
    required this.longitude,
    this.geohash,
    this.siteId,
    this.siteName,
    this.reefId,
    this.reefName,
    this.region,
    this.country,
    this.eventDate,
    required this.organizationAlias,
    this.organizationName,
    this.genotypes = const [],
    this.inferenceMetadata,
    this.sourceMetadata,
  });

  // === Core identification ===

  /// Unique identifier for this event
  final String id;

  /// Dataset identifier (e.g., 'crc_2024')
  final String datasetId;

  /// Source of the data (e.g., 'crc_historical')
  final String source;

  /// Original event ID in source system
  final String sourceEventId;

  // === Five-Axis Data ===

  /// Organism kind (e.g., 'coral', 'kelp')
  final String organismKind;

  /// Species ID from taxonomy system
  final String? speciesId;

  /// Species display name
  final String? speciesName;

  /// Life stage specification
  final LifeStageSpec lifeStage;

  /// Provenance type ('wild', 'sexualCohort', 'transfer', 'unknown', etc.)
  final String? provenanceType;

  /// Provenance confidence level ('high', 'medium', 'low')
  final String? provenanceConfidence;

  /// Size specification
  final SizeSpec sizeSpec;

  /// Total colonies/organisms in this event
  final int magnitude;

  // === Location ===

  /// Latitude of outplant location
  final double latitude;

  /// Longitude of outplant location
  final double longitude;

  /// Geohash for spatial queries
  final String? geohash;

  /// Site ID if linked to SeaFoundry site
  final String? siteId;

  /// Site display name
  final String? siteName;

  /// Reef ID (CRC or custom)
  final String? reefId;

  /// Reef display name
  final String? reefName;

  /// Geographic region
  final String? region;

  /// Country
  final String? country;

  // === Event metadata ===

  /// Date of outplanting event
  final DateTime? eventDate;

  /// Organization alias (e.g., 'org_a', 'org_b')
  final String organizationAlias;

  /// Organization name (only if public/opted-in)
  final String? organizationName;

  // === Genotype detail ===

  /// List of genotypes used in this event
  final List<HistoricalGenotype> genotypes;

  // === Inference tracking ===

  /// Metadata about inferences made during import
  /// (species mapping confidence, location approximation, etc.)
  final Map<String, dynamic>? inferenceMetadata;

  // === Raw source data ===

  /// Original source data for reference/debugging
  final Map<String, dynamic>? sourceMetadata;

  factory HistoricalOutplantEvent.fromJson(Map<String, dynamic> json) {
    return HistoricalOutplantEvent(
      id: json['id'] as String,
      datasetId: json['datasetId'] as String,
      source: json['source'] as String,
      sourceEventId: json['sourceEventId'] as String,
      organismKind: json['organismKind'] as String,
      speciesId: json['speciesId'] as String?,
      speciesName: json['speciesName'] as String?,
      lifeStage: json['lifeStage'] is Map<String, dynamic>
          ? LifeStageSpec.fromJson(json['lifeStage'] as Map<String, dynamic>)
          : const LifeStageSpec(stage: LifeStage.juvenile),
      provenanceType: json['provenanceType'] as String?,
      provenanceConfidence: json['provenanceConfidence'] as String?,
      sizeSpec: json['sizeSpec'] is Map<String, dynamic>
          ? SizeSpec.fromJson(json['sizeSpec'] as Map<String, dynamic>)
          : const SizeSpec(),
      magnitude: safeInt(json['magnitude']) ?? 0,
      latitude: safeDouble(json['latitude']) ?? 0.0,
      longitude: safeDouble(json['longitude']) ?? 0.0,
      geohash: json['geohash'] as String?,
      siteId: json['siteId'] as String?,
      siteName: json['siteName'] as String?,
      reefId: json['reefId'] as String?,
      reefName: json['reefName'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String?,
      eventDate: json['eventDate'] is String
          ? DateTime.tryParse(json['eventDate'] as String)
          : null,
      organizationAlias: json['organizationAlias'] as String,
      organizationName: json['organizationName'] as String?,
      genotypes: json['genotypes'] is List
          ? (json['genotypes'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => HistoricalGenotype.fromJson(item))
              .toList()
          : const [],
      inferenceMetadata: json['inferenceMetadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              json['inferenceMetadata'] as Map<String, dynamic>)
          : null,
      sourceMetadata: json['sourceMetadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              json['sourceMetadata'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'datasetId': datasetId,
      'source': source,
      'sourceEventId': sourceEventId,
      'organismKind': organismKind,
      'magnitude': magnitude,
      'latitude': latitude,
      'longitude': longitude,
      'organizationAlias': organizationAlias,
    };

    // Five-axis data
    if (speciesId != null) json['speciesId'] = speciesId;
    if (speciesName != null) json['speciesName'] = speciesName;
    json['lifeStage'] = lifeStage.toJson();
    if (provenanceType != null) json['provenanceType'] = provenanceType;
    if (provenanceConfidence != null) {
      json['provenanceConfidence'] = provenanceConfidence;
    }
    if (!sizeSpec.isEmpty) json['sizeSpec'] = sizeSpec.toJson();

    // Location
    if (geohash != null) json['geohash'] = geohash;
    if (siteId != null) json['siteId'] = siteId;
    if (siteName != null) json['siteName'] = siteName;
    if (reefId != null) json['reefId'] = reefId;
    if (reefName != null) json['reefName'] = reefName;
    if (region != null) json['region'] = region;
    if (country != null) json['country'] = country;

    // Event metadata
    if (eventDate != null) json['eventDate'] = eventDate!.toIso8601String();
    if (organizationName != null) json['organizationName'] = organizationName;

    // Genotypes
    if (genotypes.isNotEmpty) {
      json['genotypes'] = genotypes.map((g) => g.toJson()).toList();
    }

    // Inference and source metadata
    if (inferenceMetadata != null && inferenceMetadata!.isNotEmpty) {
      json['inferenceMetadata'] = inferenceMetadata;
    }
    if (sourceMetadata != null && sourceMetadata!.isNotEmpty) {
      json['sourceMetadata'] = sourceMetadata;
    }

    return json;
  }

  HistoricalOutplantEvent copyWith({
    String? id,
    String? datasetId,
    String? source,
    String? sourceEventId,
    String? organismKind,
    String? speciesId,
    String? speciesName,
    LifeStageSpec? lifeStage,
    String? provenanceType,
    String? provenanceConfidence,
    SizeSpec? sizeSpec,
    int? magnitude,
    double? latitude,
    double? longitude,
    String? geohash,
    String? siteId,
    String? siteName,
    String? reefId,
    String? reefName,
    String? region,
    String? country,
    DateTime? eventDate,
    String? organizationAlias,
    String? organizationName,
    List<HistoricalGenotype>? genotypes,
    Map<String, dynamic>? inferenceMetadata,
    Map<String, dynamic>? sourceMetadata,
  }) {
    return HistoricalOutplantEvent(
      id: id ?? this.id,
      datasetId: datasetId ?? this.datasetId,
      source: source ?? this.source,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      organismKind: organismKind ?? this.organismKind,
      speciesId: speciesId ?? this.speciesId,
      speciesName: speciesName ?? this.speciesName,
      lifeStage: lifeStage ?? this.lifeStage,
      provenanceType: provenanceType ?? this.provenanceType,
      provenanceConfidence: provenanceConfidence ?? this.provenanceConfidence,
      sizeSpec: sizeSpec ?? this.sizeSpec,
      magnitude: magnitude ?? this.magnitude,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      reefId: reefId ?? this.reefId,
      reefName: reefName ?? this.reefName,
      region: region ?? this.region,
      country: country ?? this.country,
      eventDate: eventDate ?? this.eventDate,
      organizationAlias: organizationAlias ?? this.organizationAlias,
      organizationName: organizationName ?? this.organizationName,
      genotypes: genotypes ?? this.genotypes,
      inferenceMetadata: inferenceMetadata ?? this.inferenceMetadata,
      sourceMetadata: sourceMetadata ?? this.sourceMetadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        datasetId,
        source,
        sourceEventId,
        organismKind,
        speciesId,
        speciesName,
        lifeStage,
        provenanceType,
        provenanceConfidence,
        sizeSpec,
        magnitude,
        latitude,
        longitude,
        geohash,
        siteId,
        siteName,
        reefId,
        reefName,
        region,
        country,
        eventDate,
        organizationAlias,
        organizationName,
        genotypes,
        inferenceMetadata,
        sourceMetadata,
      ];
}
