// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Historical genotype information from CRC dataset.
/// Represents a single genotype used in historical outplanting events.
class HistoricalGenotype extends Equatable {
  const HistoricalGenotype({
    required this.id,
    required this.displayName,
    required this.organizationAlias,
    this.accessionNumber,
    this.hasGeneticAnalysis = false,
    this.collectionDate,
    this.collectionLatitude,
    this.collectionLongitude,
    this.collectionSite,
    required this.colonies,
    required this.sizeSpec,
    this.provenanceType,
    this.provenanceConfidence,
  });

  /// Unique identifier for this genotype
  final String id;

  /// Display name (e.g., 'Acer-007')
  final String displayName;

  /// Organization alias (e.g., 'org_a')
  final String organizationAlias;

  /// CRC UUID or other accession number
  final String? accessionNumber;

  /// Whether this genotype has genetic analysis data
  final bool hasGeneticAnalysis;

  /// When this genotype was collected
  final DateTime? collectionDate;

  /// Collection location latitude
  final double? collectionLatitude;

  /// Collection location longitude
  final double? collectionLongitude;

  /// Collection site name
  final String? collectionSite;

  /// Number of colonies for this genotype in the event
  final int colonies;

  /// Size specification for colonies
  final SizeSpec sizeSpec;

  /// Provenance type ('wild', 'sexualCohort', 'transfer', 'unknown', etc.)
  final String? provenanceType;

  /// Provenance confidence ('high', 'medium', 'low')
  final String? provenanceConfidence;

  factory HistoricalGenotype.fromJson(Map<String, dynamic> json) {
    return HistoricalGenotype(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      organizationAlias: json['organizationAlias'] as String,
      accessionNumber: json['accessionNumber'] as String?,
      hasGeneticAnalysis: json['hasGeneticAnalysis'] as bool? ?? false,
      collectionDate: json['collectionDate'] is String
          ? DateTime.tryParse(json['collectionDate'] as String)
          : null,
      collectionLatitude: safeDouble(json['collectionLatitude']),
      collectionLongitude: safeDouble(json['collectionLongitude']),
      collectionSite: json['collectionSite'] as String?,
      colonies: safeInt(json['colonies']) ?? 0,
      sizeSpec: json['sizeSpec'] is Map<String, dynamic>
          ? SizeSpec.fromJson(json['sizeSpec'] as Map<String, dynamic>)
          : const SizeSpec(),
      provenanceType: json['provenanceType'] as String?,
      provenanceConfidence: json['provenanceConfidence'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'organizationAlias': organizationAlias,
      'hasGeneticAnalysis': hasGeneticAnalysis,
      'colonies': colonies,
    };

    if (accessionNumber != null) json['accessionNumber'] = accessionNumber;
    if (collectionDate != null) {
      json['collectionDate'] = collectionDate!.toIso8601String();
    }
    if (collectionLatitude != null) {
      json['collectionLatitude'] = collectionLatitude;
    }
    if (collectionLongitude != null) {
      json['collectionLongitude'] = collectionLongitude;
    }
    if (collectionSite != null) json['collectionSite'] = collectionSite;
    if (!sizeSpec.isEmpty) json['sizeSpec'] = sizeSpec.toJson();
    if (provenanceType != null) json['provenanceType'] = provenanceType;
    if (provenanceConfidence != null) {
      json['provenanceConfidence'] = provenanceConfidence;
    }

    return json;
  }

  HistoricalGenotype copyWith({
    String? id,
    String? displayName,
    String? organizationAlias,
    String? accessionNumber,
    bool? hasGeneticAnalysis,
    DateTime? collectionDate,
    double? collectionLatitude,
    double? collectionLongitude,
    String? collectionSite,
    int? colonies,
    SizeSpec? sizeSpec,
    String? provenanceType,
    String? provenanceConfidence,
  }) {
    return HistoricalGenotype(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      organizationAlias: organizationAlias ?? this.organizationAlias,
      accessionNumber: accessionNumber ?? this.accessionNumber,
      hasGeneticAnalysis: hasGeneticAnalysis ?? this.hasGeneticAnalysis,
      collectionDate: collectionDate ?? this.collectionDate,
      collectionLatitude: collectionLatitude ?? this.collectionLatitude,
      collectionLongitude: collectionLongitude ?? this.collectionLongitude,
      collectionSite: collectionSite ?? this.collectionSite,
      colonies: colonies ?? this.colonies,
      sizeSpec: sizeSpec ?? this.sizeSpec,
      provenanceType: provenanceType ?? this.provenanceType,
      provenanceConfidence: provenanceConfidence ?? this.provenanceConfidence,
    );
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        organizationAlias,
        accessionNumber,
        hasGeneticAnalysis,
        collectionDate,
        collectionLatitude,
        collectionLongitude,
        collectionSite,
        colonies,
        sizeSpec,
        provenanceType,
        provenanceConfidence,
      ];
}
