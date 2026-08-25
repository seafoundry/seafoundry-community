import 'package:equatable/equatable.dart';
import 'package:seafoundry_community/models/historical/nomenclature_system.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

/// A Provenance ID (PID) record containing genotype information
/// and organization-specific aliases.
///
/// PIDs provide a universal identifier for genotypes across organizations,
/// ordered by first outplant date within each species.
///
/// Format: PID-{SPECIES}-{NNN} (e.g., PID-APAL-001)
class ProvenanceId extends Equatable {
  const ProvenanceId({
    required this.pid,
    required this.provenanceId,
    required this.species,
    required this.speciesName,
    required this.speciesCommonName,
    this.firstOutplantDate,
    this.firstOutplantSite,
    this.accessionNumber,
    this.clonalId,
    required this.aliases,
    this.rawAliases = const [],
    this.hasGeneticData = false,
    this.isFounder = false,
    this.isSexualRecruit = false,
    this.collectionDate,
    this.collectionSite,
    this.collectionRegion,
    this.totalOutplantEvents = 0,
  });

  /// Provenance ID (e.g., PID-APAL-001)
  final String pid;

  /// Provenance ID (legacy SeaFoundry format).
  final String provenanceId;

  /// Species code (e.g., APAL)
  final String species;

  /// Scientific species name (e.g., Acropora palmata)
  final String speciesName;

  /// Common species name (e.g., Elkhorn Coral)
  final String speciesCommonName;

  /// First outplant date for this genotype (ISO 8601)
  final String? firstOutplantDate;

  /// Site name of first outplant
  final String? firstOutplantSite;

  /// External accession number (if available)
  final String? accessionNumber;

  /// Partner clonal ID (if available)
  final String? clonalId;

  /// Organization-specific aliases (orgA: "AP5", orgB: null, etc.)
  final Map<String, String?> aliases;

  /// All raw alias IDs for reverse lookup (includes aliases from unknown orgs)
  final List<String> rawAliases;

  /// Whether this genotype has genetic analysis data
  final bool hasGeneticData;

  /// Whether this is a founder genotype
  final bool isFounder;

  /// Whether this is a sexual recruit
  final bool isSexualRecruit;

  /// Collection date (if known)
  final String? collectionDate;

  /// Collection site name
  final String? collectionSite;

  /// Collection region
  final String? collectionRegion;

  /// Total number of outplant events for this genotype
  final int totalOutplantEvents;

  /// Get the display ID for a given nomenclature system.
  /// Returns the PID if no alias exists for the organization.
  String getDisplayId(NomenclatureSystem system) {
    if (system == NomenclatureSystem.provenanceId) {
      return pid;
    }
    return aliases[system.aliasKey] ?? pid;
  }

  /// Check if this genotype has an alias for the given system.
  bool hasAlias(NomenclatureSystem system) {
    if (system == NomenclatureSystem.provenanceId) return true;
    return aliases[system.aliasKey] != null;
  }

  /// Get all non-null aliases as a list of display strings.
  List<String> get allAliases {
    final result = <String>[];
    for (final system in NomenclatureSystem.organizations) {
      final alias = aliases[system.aliasKey];
      if (alias != null) {
        result.add('${system.displayName}: $alias');
      }
    }
    return result;
  }

  /// Parse from JSON (matching pid_crosswalk.json structure)
  factory ProvenanceId.fromJson(Map<String, dynamic> json) {
    return ProvenanceId(
      pid: json['pid'] as String,
      provenanceId: json['provenanceId'] as String,
      species: json['species'] as String,
      speciesName: json['speciesName'] as String,
      speciesCommonName: json['speciesCommonName'] as String,
      firstOutplantDate: json['firstOutplantDate'] as String?,
      firstOutplantSite: json['firstOutplantSite'] as String?,
      accessionNumber: json['accessionNumber'] as String?,
      clonalId: json['clonalId'] as String?,
      aliases: Map.unmodifiable(
        (json['aliases'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as String?),
            ) ??
            const <String, String?>{},
      ),
      rawAliases: List<String>.unmodifiable(
        (json['rawAliases'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [],
      ),
      hasGeneticData: json['hasGeneticData'] as bool? ?? false,
      isFounder: json['isFounder'] as bool? ?? false,
      isSexualRecruit: json['isSexualRecruit'] as bool? ?? false,
      collectionDate: json['collectionDate'] as String?,
      collectionSite: json['collectionSite'] as String?,
      collectionRegion: json['collectionRegion'] as String?,
      totalOutplantEvents: safeInt(json['totalOutplantEvents']) ?? 0,
    );
  }

  /// Creates a copy with optional field overrides.
  ProvenanceId copyWith({
    String? pid,
    String? provenanceId,
    String? species,
    String? speciesName,
    String? speciesCommonName,
    String? firstOutplantDate,
    String? firstOutplantSite,
    String? accessionNumber,
    String? clonalId,
    Map<String, String?>? aliases,
    List<String>? rawAliases,
    bool? hasGeneticData,
    bool? isFounder,
    bool? isSexualRecruit,
    String? collectionDate,
    String? collectionSite,
    String? collectionRegion,
    int? totalOutplantEvents,
  }) {
    return ProvenanceId(
      pid: pid ?? this.pid,
      provenanceId: provenanceId ?? this.provenanceId,
      species: species ?? this.species,
      speciesName: speciesName ?? this.speciesName,
      speciesCommonName: speciesCommonName ?? this.speciesCommonName,
      firstOutplantDate: firstOutplantDate ?? this.firstOutplantDate,
      firstOutplantSite: firstOutplantSite ?? this.firstOutplantSite,
      accessionNumber: accessionNumber ?? this.accessionNumber,
      clonalId: clonalId ?? this.clonalId,
      aliases: aliases ?? this.aliases,
      rawAliases: rawAliases ?? this.rawAliases,
      hasGeneticData: hasGeneticData ?? this.hasGeneticData,
      isFounder: isFounder ?? this.isFounder,
      isSexualRecruit: isSexualRecruit ?? this.isSexualRecruit,
      collectionDate: collectionDate ?? this.collectionDate,
      collectionSite: collectionSite ?? this.collectionSite,
      collectionRegion: collectionRegion ?? this.collectionRegion,
      totalOutplantEvents: totalOutplantEvents ?? this.totalOutplantEvents,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'provenanceId': provenanceId,
      'species': species,
      'speciesName': speciesName,
      'speciesCommonName': speciesCommonName,
      if (firstOutplantDate != null) 'firstOutplantDate': firstOutplantDate,
      if (firstOutplantSite != null) 'firstOutplantSite': firstOutplantSite,
      if (accessionNumber != null) 'accessionNumber': accessionNumber,
      if (clonalId != null) 'clonalId': clonalId,
      'aliases': aliases,
      if (rawAliases.isNotEmpty) 'rawAliases': rawAliases,
      'hasGeneticData': hasGeneticData,
      'isFounder': isFounder,
      'isSexualRecruit': isSexualRecruit,
      if (collectionDate != null) 'collectionDate': collectionDate,
      if (collectionSite != null) 'collectionSite': collectionSite,
      if (collectionRegion != null) 'collectionRegion': collectionRegion,
      'totalOutplantEvents': totalOutplantEvents,
    };
  }

  @override
  List<Object?> get props => [
        pid,
        provenanceId,
        species,
        speciesName,
        speciesCommonName,
        firstOutplantDate,
        firstOutplantSite,
        accessionNumber,
        clonalId,
        aliases,
        rawAliases,
        hasGeneticData,
        isFounder,
        isSexualRecruit,
        collectionDate,
        collectionSite,
        collectionRegion,
        totalOutplantEvents,
      ];
}
