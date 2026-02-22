// @tier: community
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:seafoundry_app/models/historical/nomenclature_system.dart';
import 'package:seafoundry_app/models/historical/provenance_id.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Organization nomenclature mapping from org_nomenclature_map.json.
class OrganizationNomenclature {
  const OrganizationNomenclature({
    required this.orgKey,
    required this.displayName,
    required this.internalOrg,
    required this.fullName,
    required this.aliasCount,
    required this.rank,
  });

  final String orgKey;
  final String displayName;
  final String internalOrg;
  final String fullName;
  final int aliasCount;
  final int rank;

  factory OrganizationNomenclature.fromJson(Map<String, dynamic> json) {
    return OrganizationNomenclature(
      orgKey: json['orgKey'] as String,
      displayName: json['displayName'] as String,
      internalOrg: json['internalOrg'] as String,
      fullName: json['fullName'] as String,
      aliasCount: safeInt(json['aliasCount']) ?? 0,
      rank: safeInt(json['rank']) ?? 0,
    );
  }
}

/// Species statistics from the PID crosswalk.
class SpeciesStats {
  const SpeciesStats({
    required this.code,
    required this.name,
    required this.commonName,
    required this.totalGenotypes,
    required this.withOutplantDate,
    required this.withGeneticData,
    this.earliestOutplant,
    this.latestOutplant,
  });

  final String code;
  final String name;
  final String commonName;
  final int totalGenotypes;
  final int withOutplantDate;
  final int withGeneticData;
  final String? earliestOutplant;
  final String? latestOutplant;

  factory SpeciesStats.fromJson(Map<String, dynamic> json) {
    return SpeciesStats(
      code: json['code'] as String,
      name: json['name'] as String,
      commonName: json['commonName'] as String,
      totalGenotypes: safeInt(json['totalGenotypes']) ?? 0,
      withOutplantDate: safeInt(json['withOutplantDate']) ?? 0,
      withGeneticData: safeInt(json['withGeneticData']) ?? 0,
      earliestOutplant: json['earliestOutplant'] as String?,
      latestOutplant: json['latestOutplant'] as String?,
    );
  }
}

/// Initialization state for the nomenclature service.
enum NomenclatureServiceInitState {
  /// Service has not been initialized.
  uninitialized,

  /// Service is currently initializing.
  initializing,

  /// Service initialized successfully.
  success,

  /// Service initialization failed.
  failed,
}

/// Service for loading and querying the historical PID nomenclature crosswalk.
///
/// Provides nomenclature translation for the community map, allowing users
/// to view genotype IDs in different naming conventions.
///
/// Usage:
/// ```dart
/// final service = HistoricalNomenclatureService.instance;
/// await service.initialize();
///
/// // Get display ID for a genotype
/// final displayId = service.getDisplayId('PID-APAL-001', NomenclatureSystem.orgB);
///
/// // Get full provenance details
/// final details = service.getProvenanceDetails('PID-APAL-001');
/// ```
class HistoricalNomenclatureService {
  HistoricalNomenclatureService._();

  static final HistoricalNomenclatureService instance =
      HistoricalNomenclatureService._();

  static const String _pidCrosswalkAsset = 'crc_db/pid_crosswalk.json';
  static const String _orgMapAsset = 'crc_db/org_nomenclature_map.json';
  static const String _crcNumericGenotypeMapAsset =
      'crc_db/crc_numeric_genotype_map.json';

  NomenclatureServiceInitState _initState =
      NomenclatureServiceInitState.uninitialized;
  String? _initializationError;
  Map<String, ProvenanceId> _provenanceById = {};
  Map<String, String> _provenanceIdToPid = {};
  Map<String, String> _aliasToProvenanceId = {}; // Reverse lookup: alias -> PID
  Map<String, String> _crcNumericPidMap = {}; // CRC numeric genotype -> PID
  Map<String, SpeciesStats> _speciesStats = {};
  List<OrganizationNomenclature> _organizations = [];

  /// Whether the service has been initialized (successfully or with error).
  bool get isInitialized =>
      _initState == NomenclatureServiceInitState.success ||
      _initState == NomenclatureServiceInitState.failed;

  /// Current initialization state.
  NomenclatureServiceInitState get initState => _initState;

  /// Whether initialization failed.
  bool get hasError => _initState == NomenclatureServiceInitState.failed;

  /// Error message if initialization failed.
  String? get errorMessage => _initializationError;

  /// Total number of genotypes in the crosswalk.
  int get totalGenotypes => _provenanceById.length;

  /// Available species statistics.
  Map<String, SpeciesStats> get speciesStats =>
      Map.unmodifiable(_speciesStats);

  /// Organization nomenclature mappings (top 10).
  List<OrganizationNomenclature> get organizations =>
      List.unmodifiable(_organizations);

  /// Initialize the service by loading crosswalk data.
  ///
  /// Loads from bundled assets. Call once at app startup.
  /// Returns true if initialization succeeded, false if it failed.
  /// Check [hasError] and [errorMessage] for failure details.
  Future<bool> initialize() async {
    if (_initState == NomenclatureServiceInitState.success) return true;
    if (_initState == NomenclatureServiceInitState.failed) return false;
    if (_initState == NomenclatureServiceInitState.initializing) {
      // Already initializing, wait for completion
      while (_initState == NomenclatureServiceInitState.initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return _initState == NomenclatureServiceInitState.success;
    }

    _initState = NomenclatureServiceInitState.initializing;
    _initializationError = null;

    try {
      await Future.wait([
        _loadPidCrosswalk(),
        _loadOrgNomenclatureMap(),
        _loadCrcNumericGenotypeMap(),
      ]);
      _initState = NomenclatureServiceInitState.success;
      LoggingService.instance.info(
        'HistoricalNomenclatureService initialized: '
        '${_provenanceById.length} PIDs, ${_organizations.length} orgs',
      );
      return true;
    } catch (e, stackTrace) {
      _initState = NomenclatureServiceInitState.failed;
      _initializationError = e.toString();
      LoggingService.instance.error(
        'Failed to initialize HistoricalNomenclatureService',
        e,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _loadPidCrosswalk() async {
    try {
      final jsonString = await rootBundle.loadString(_pidCrosswalkAsset);
      final data = json.decode(jsonString) as Map<String, dynamic>;

      // Load genotypes
      final genotypes = data['genotypes'] as Map<String, dynamic>? ?? {};
      for (final entry in genotypes.entries) {
        final provenance =
            ProvenanceId.fromJson(entry.value as Map<String, dynamic>);
        _provenanceById[provenance.pid] = provenance;
        _provenanceIdToPid[provenance.provenanceId] = provenance.pid;

        // Build reverse lookup from all aliases to PID (case-insensitive)
        // Skip ambiguous aliases (N/A, pure numbers, etc.)
        for (final alias in provenance.aliases.values) {
          if (_isValidAliasForLookup(alias)) {
            _aliasToProvenanceId[alias!.toUpperCase()] = provenance.pid;
          }
        }
        // Also include rawAliases (aliases from unknown orgs)
        for (final alias in provenance.rawAliases) {
          if (_isValidAliasForLookup(alias)) {
            _aliasToProvenanceId[alias.toUpperCase()] = provenance.pid;
          }
        }
        // Also map accession number and clonal ID for lookup
        if (_isValidAliasForLookup(provenance.accessionNumber)) {
          _aliasToProvenanceId[provenance.accessionNumber!.toUpperCase()] =
              provenance.pid;
        }
        if (_isValidAliasForLookup(provenance.clonalId)) {
          _aliasToProvenanceId[provenance.clonalId!.toUpperCase()] =
              provenance.pid;
        }
      }

      // Load species stats
      final bySpecies = data['bySpecies'] as Map<String, dynamic>? ?? {};
      for (final entry in bySpecies.entries) {
        _speciesStats[entry.key] =
            SpeciesStats.fromJson(entry.value as Map<String, dynamic>);
      }
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to load PID crosswalk from asset, data may be unavailable: $e',
      );
    }
  }

  Future<void> _loadOrgNomenclatureMap() async {
    try {
      final jsonString = await rootBundle.loadString(_orgMapAsset);
      final data = json.decode(jsonString) as Map<String, dynamic>;

      final orgs = data['organizations'] as List<dynamic>? ?? [];
      _organizations = orgs
          .map((o) => OrganizationNomenclature.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to load org nomenclature map from asset: $e',
      );
    }
  }

  Future<void> _loadCrcNumericGenotypeMap() async {
    try {
      final jsonString =
          await rootBundle.loadString(_crcNumericGenotypeMapAsset);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final mappings = data['mappings'] as Map<String, dynamic>? ?? {};
      final resolved = <String, String>{};

      for (final entry in mappings.entries) {
        final value = entry.value;
        if (value is String) {
          resolved[entry.key] = value;
        } else if (value is Map<String, dynamic>) {
          final pid = value['pid'];
          if (pid is String) {
            resolved[entry.key] = pid;
          }
        }
      }

      _crcNumericPidMap = resolved;
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to load CRC numeric genotype map: $e',
      );
    }
  }

  /// Whether the service has loaded data successfully.
  bool get _hasData => _initState == NomenclatureServiceInitState.success;

  /// Get the display ID for a given genotype identifier and nomenclature system.
  ///
  /// The [genotypeId] can be a PID (e.g., "PID-APAL-001"), provenance ID,
  /// accession number,
  /// clonal ID, or any organization-specific alias. The method will attempt to
  /// resolve the input to a provenance record and return the requested translation.
  ///
  /// Returns the original [genotypeId] if no provenance record is found or if
  /// the requested alias doesn't exist for that organization.
  String getDisplayId(String genotypeId, NomenclatureSystem system) {
    if (!_hasData) {
      if (_initState != NomenclatureServiceInitState.success) {
        LoggingService.instance.warning(
          'HistoricalNomenclatureService not ready (state: $_initState), '
          'returning original ID',
        );
      }
      return genotypeId;
    }

    // Resolve to provenance record using various lookup methods
    final provenance = _resolveProvenance(genotypeId);
    if (provenance == null) return genotypeId;

    if (system == NomenclatureSystem.provenanceId) {
      return provenance.pid;
    }

    return provenance.getDisplayId(system);
  }

  /// Resolves a genotype identifier to its ProvenanceId record.
  ///
  /// Tries multiple lookup strategies:
  /// 1. Direct PID match
  /// 2. Provenance ID to PID lookup
  /// 3. Alias to PID reverse lookup (case-insensitive)
  ProvenanceId? _resolveProvenance(String genotypeId) {
    // Try direct PID lookup
    var provenance = _provenanceById[genotypeId];
    if (provenance != null) return provenance;

    // Try provenance ID lookup
    final pidFromProvenanceId = _provenanceIdToPid[genotypeId];
    if (pidFromProvenanceId != null) {
      provenance = _provenanceById[pidFromProvenanceId];
      if (provenance != null) return provenance;
    }

    // Try CRC numeric genotype mapping (unambiguous numeric IDs only)
    if (_numericDigitsPattern.hasMatch(genotypeId.trim())) {
      final pidFromNumeric = _crcNumericPidMap[genotypeId.trim()];
      if (pidFromNumeric != null) {
        provenance = _provenanceById[pidFromNumeric];
        if (provenance != null) return provenance;
      }
    }

    // Try reverse alias lookup (case-insensitive)
    final pidFromAlias = _aliasToProvenanceId[genotypeId.toUpperCase()];
    if (pidFromAlias != null) {
      provenance = _provenanceById[pidFromAlias];
      if (provenance != null) return provenance;
    }

    return null;
  }

  /// Get the full provenance details for a genotype identifier.
  ///
  /// The [genotypeId] can be a PID, provenance ID, or any organization-specific alias.
  ProvenanceId? getProvenanceDetails(String genotypeId) {
    if (!_hasData) return null;
    return _resolveProvenance(genotypeId);
  }

  /// Look up a PID by its provenance ID.
  String? getPidByProvenanceId(String provenanceId) {
    if (!_hasData) return null;
    return _provenanceIdToPid[provenanceId];
  }

  /// Get all PIDs for a species.
  List<ProvenanceId> getProvenancesBySpecies(String speciesCode) {
    if (!_hasData) return [];
    return _provenanceById.values
        .where((p) => p.species == speciesCode.toUpperCase())
        .toList();
  }

  /// Search for PIDs by alias across all organizations.
  ///
  /// Returns PIDs where any org alias contains the search term.
  List<ProvenanceId> searchByAlias(String query, {int limit = 20}) {
    if (!_hasData || query.isEmpty) return [];

    final normalizedQuery = query.trim().toUpperCase();
    final results = <ProvenanceId>[];

    for (final provenance in _provenanceById.values) {
      if (results.length >= limit) break;

      // Check PID
      if (provenance.pid.toUpperCase().contains(normalizedQuery)) {
        results.add(provenance);
        continue;
      }

      // Check accession number
      if (provenance.accessionNumber?.toUpperCase().contains(normalizedQuery) ??
          false) {
        results.add(provenance);
        continue;
      }

      // Check clonal ID
      if (provenance.clonalId?.toUpperCase().contains(normalizedQuery) ??
          false) {
        results.add(provenance);
        continue;
      }

      // Check aliases
      for (final alias in provenance.aliases.values) {
        if (alias?.toUpperCase().contains(normalizedQuery) ?? false) {
          results.add(provenance);
          break;
        }
      }
    }

    return results;
  }

  /// Get statistics summary.
  Map<String, dynamic> getStats() {
    return {
      'initState': _initState.name,
      'hasError': hasError,
      'errorMessage': _initializationError,
      'totalGenotypes': _provenanceById.length,
      'speciesCount': _speciesStats.length,
      'organizationCount': _organizations.length,
      'bySpecies': _speciesStats.map(
        (k, v) => MapEntry(k, {
          'total': v.totalGenotypes,
          'withDates': v.withOutplantDate,
          'withGenetics': v.withGeneticData,
        }),
      ),
    };
  }

  /// Pattern for pure numeric strings (integers, floats, years).
  static final _numericPattern = RegExp(r'^-?\d+\.?\d*$');
  static final _numericDigitsPattern = RegExp(r'^\d+$');

  /// Known reef/site names that should NOT be treated as genotype IDs.
  /// Defense-in-depth filter matching JavaScript INVALID_ALIAS_NAMES.
  /// Source: Florida Keys reef names, Caribbean sites, common placeholders.
  static const _invalidSiteNames = <String>{
    // Florida Keys reef/site names
    'SNAPPER LEDGE', 'HORSESHOE', 'HORSESHOE REEF', 'PICKLES', 'PICKLES REEF',
    'CONCH', 'CONCH REEF', 'LITTLE CONCH',
    'COOPERS', "COOPER'S", "COOPER'S REEF", 'COOPERS GROWTH', 'COOPERS REEF',
    'BROWARD', 'MIAMI', 'MIAMI BEACH', 'TAVERNIER',
    'CARYSFORT', 'CARYSFORT REEF', 'FRENCH REEF', 'GRECIAN ROCKS',
    'MOLASSES', 'LOOE KEY', 'SOMBRERO', 'SOMBRERO REEF',
    'ALLIGATOR REEF', 'DAVIS REEF', 'AMERICAN SHOALS',
    'DRY ROCKS', 'EASTERN DRY ROCKS', 'KEY LARGO DRY ROCKS',
    'SAND KEY', 'TENNECO', 'RAINBOW REEF',
    'FOWEY', 'EMERALD REEF', 'FLAMINGO',
    'SWAN KEY', 'SWAN KEY-A',
    // Placeholders and ambiguous entries
    'UNKNOWN', 'UNK', 'MIXED', 'MIXED-RTT PROJECT', 'MIXED/SEAWALL COLLECTION',
    'SINGLES', 'SWG EXP LEFTOVERS',
    'FLAQ', 'Y', 'W', 'BD', 'BF', 'BA',
  };

  /// Checks if an alias is valid for reverse lookup.
  /// Filters out ambiguous entries like "N/A", pure numbers, site names, etc.
  bool _isValidAliasForLookup(String? alias) {
    if (alias == null || alias.isEmpty) return false;

    final normalized = alias.toUpperCase().trim().replaceAll(RegExp(r'\s+'), ' ');

    // Skip N/A variants
    if (normalized == 'N/A' || normalized == 'NA' || normalized == r'N\A') {
      return false;
    }

    // Skip known site names (defense in depth)
    if (_invalidSiteNames.contains(normalized)) return false;

    // Skip pure numeric entries (e.g., "7", "123", "2020")
    if (_numericPattern.hasMatch(alias.trim())) return false;

    // Skip very short aliases (likely ambiguous)
    if (alias.trim().length < 2) return false;

    return true;
  }

  /// Reset the service (for testing).
  void reset() {
    _initState = NomenclatureServiceInitState.uninitialized;
    _initializationError = null;
    _provenanceById = {};
    _provenanceIdToPid = {};
    _aliasToProvenanceId = {};
    _crcNumericPidMap = {};
    _speciesStats = {};
    _organizations = [];
  }
}
