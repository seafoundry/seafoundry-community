// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/historical/historical_impact_point.dart';
import 'package:seafoundry_app/models/historical/historical_models.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

/// Species ID to scientific name mapping for CRC data
const Map<String, String> crcSpeciesNames = {
  '1': 'Acropora cervicornis',
  '2': 'Acropora palmata',
  '3': 'Orbicella franksi',
  '4': 'Orbicella faveolata',
  '5': 'Orbicella annularis',
  '6': 'Mycetophyllia ferox',
  '7': 'Dendrogyra cylindrus',
  '8': 'Acropora prolifera',
  '9': 'Pseudodiploria clivosa',
  '10': 'Pseudodiploria strigosa',
  '11': 'Siderastrea siderea',
  '12': 'Porites porites',
  '13': 'Montastraea cavernosa',
  '14': 'Acropora species',
  '15': 'Xestospongia muta',
  '16': 'Acropora formosa',
  '17': 'Acropora abrolhosensis',
  '18': 'Montipora foliosa',
  '19': 'Acropora longicyathus',
  '20': 'Acropora hyacinthus',
  '21': 'Acropora cytherea',
  '25': 'Porites species',
  '26': 'Unknown',
  '28': 'Diploria labyrinthiformis',
  '31': 'Dichocoenia stokesii',
  '32': 'Colpophyllia natans',
  '33': 'Porites asteroides',
  '34': 'Siderastrea radians',
  '35': 'Meandrina meandrites',
  '39': 'Solenastrea bournoni',
  '42': 'Eusmilia fastigiata',
  '43': 'Agaricia agaricites',
  '44': 'Stephanocoenia intersepta',
  '45': 'Manicina areolata',
  '46': 'Favia fragum',
  '48': 'Scolymia cubensis',
  '49': 'Stephanocoenia michelini',
  '50': 'Madracis decactis',
  '51': 'Mycetophyllia aliciae',
  '52': 'Orbicella species',
  '53': 'Madracis senaria',
  '54': 'Mycetophyllia lamarckiana',
  '55': 'Agaricia humilis',
};

String? _resolveSpeciesName({
  String? speciesName,
  String? speciesId,
}) {
  final trimmed = speciesName?.trim();
  if (trimmed != null && trimmed.isNotEmpty && trimmed.toLowerCase() != 'unknown') {
    if (crcSpeciesNames.containsKey(trimmed)) {
      return crcSpeciesNames[trimmed];
    }
    return trimmed;
  }

  final id = speciesId?.trim();
  if (id == null || id.isEmpty) return null;

  final mapped = crcSpeciesNames[id];
  if (mapped != null && mapped.isNotEmpty) return mapped;

  final fallback = Species.fallback(id);
  if (fallback.name.toLowerCase().contains('unknown')) {
    return id;
  }
  return fallback.name;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

DateTime? _parseEventDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String? _normalizeEventDateString(dynamic value) {
  final parsed = _parseEventDate(value);
  if (parsed == null) return null;
  final iso = parsed.toIso8601String();
  return iso.length >= 10 ? iso.substring(0, 10) : iso;
}

/// Service for querying historical outplant data (CRC, etc.)
/// Provides filtered streams and aggregates for public map display.
class HistoricalDataService {
  HistoricalDataService({
    FirebaseFirestore? firestore,
    FirestoreCollectionResolver? resolver,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _resolver = resolver ?? FirestoreCollectionResolver.instance;

  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver;

  /// Stream historical impact points with optional filters.
  /// Used for zoomed-in map view (individual site markers).
  Stream<List<HistoricalImpactPoint>> streamHistoricalImpactPoints({
    required String datasetId,
    String? reefFilter,
    String? regionFilter,
    String? speciesFilter,
  }) {
    Query<Map<String, dynamic>> query = _resolver
        .collection(_firestore, 'historical_impact_points')
        .where('datasetId', isEqualTo: datasetId);

    if (reefFilter != null && reefFilter.isNotEmpty) {
      query = query.where('reefId', isEqualTo: reefFilter);
    }

    if (regionFilter != null && regionFilter.isNotEmpty) {
      query = query.where('region', isEqualTo: regionFilter);
    }

    if (speciesFilter != null && speciesFilter.isNotEmpty) {
      query = query.where('speciesId', isEqualTo: speciesFilter);
    }

    return query.snapshots().map(
      (snap) => snap.docs
          .map((doc) => HistoricalImpactPoint.fromJson(doc.data()))
          .toList(),
    );
  }

  /// Stream reef aggregates for zoomed-out map view.
  /// Shows large circles with total colony counts per reef.
  Stream<List<ReefAggregate>> streamReefAggregates({
    required String datasetId,
    String? regionFilter,
    String? speciesFilter,
  }) {
    Query<Map<String, dynamic>> query = _resolver
        .collection(_firestore, 'historical_reef_aggregates')
        .where('datasetId', isEqualTo: datasetId);

    if (regionFilter != null && regionFilter.isNotEmpty) {
      query = query.where('region', isEqualTo: regionFilter);
    }

    // Note: Species filter requires client-side filtering on coloniesBySpecies map
    // since it's a nested field. Apply in stream transformation.

    return query.snapshots().map((snap) {
      var aggregates = snap.docs
          .map((doc) => ReefAggregate.fromJson(doc.data()))
          .toList();

      // Client-side species filter
      if (speciesFilter != null && speciesFilter.isNotEmpty) {
        aggregates = aggregates
            .where((agg) => agg.coloniesBySpecies.containsKey(speciesFilter))
            .toList();
      }

      return aggregates;
    });
  }

  /// Get available filter options from the dataset metadata.
  /// Options are typically pre-computed and stored in a metadata document.
  Future<HistoricalFilterOptions> getHistoricalFilterOptions(
    String datasetId,
  ) async {
    try {
      final doc = await _resolver
          .collection(_firestore, 'historical_dataset_metadata')
          .doc(datasetId)
          .get();

      if (!doc.exists) {
        return const HistoricalFilterOptions();
      }

      final data = doc.data();
      if (data == null || data['filterOptions'] is! Map<String, dynamic>) {
        return const HistoricalFilterOptions();
      }

      return HistoricalFilterOptions.fromJson(
        data['filterOptions'] as Map<String, dynamic>,
      );
    } catch (e) {
      // Return empty options on error
      return const HistoricalFilterOptions();
    }
  }

  /// Fetch a single historical outplant event by ID.
  /// Used for detail views or drill-downs.
  Future<HistoricalOutplantEvent?> fetchOutplantEvent(String eventId) async {
    try {
      final doc = await _resolver
          .collection(_firestore, 'historical_outplant_events')
          .doc(eventId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) {
        return null;
      }

      return HistoricalOutplantEvent.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get reef aggregate by reef ID.
  /// Useful for showing reef-level summary information.
  Future<ReefAggregate?> fetchReefAggregate({
    required String datasetId,
    required String reefId,
  }) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_reef_aggregates')
          .where('datasetId', isEqualTo: datasetId)
          .where('reefId', isEqualTo: reefId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      return ReefAggregate.fromJson(query.docs.first.data());
    } catch (e) {
      return null;
    }
  }

  /// Fetch all historical impact points (one-time fetch, not stream)
  /// Applies data quality fixes: species name mapping, coordinate corrections
  Future<List<HistoricalImpactPoint>> fetchAllHistoricalImpactPoints({
    required String datasetId,
  }) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_impact_points')
          .where('datasetId', isEqualTo: datasetId)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        var point = HistoricalImpactPoint.fromJson(data);

        final resolvedSpeciesName = _resolveSpeciesName(
          speciesName: point.speciesName,
          speciesId: point.speciesId,
        );
        if (resolvedSpeciesName != null &&
            resolvedSpeciesName != point.speciesName) {
          point = point.copyWith(speciesName: resolvedSpeciesName);
        }

        // Fix longitude sign for Caribbean points with positive longitude
        // (data entry error - should be negative)
        if (point.longitude > 0 &&
            [
              'Florida',
              'Puerto Rico',
              'Virgin Islands',
              'Caribbean',
            ].contains(point.region)) {
          point = point.copyWith(longitude: -point.longitude);
        }

        return point;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch all reef aggregates (one-time fetch)
  Future<List<ReefAggregate>> fetchAllReefAggregates({
    required String datasetId,
  }) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_reef_aggregates')
          .where('datasetId', isEqualTo: datasetId)
          .get();

      return query.docs
          .map((doc) => ReefAggregate.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Build filter options dynamically from the actual data
  Future<HistoricalFilterOptions> buildFilterOptionsFromData({
    required String datasetId,
  }) async {
    try {
      final points = await fetchAllHistoricalImpactPoints(datasetId: datasetId);

      // Extract unique values
      final regions = <String, int>{};
      final reefs = <String, int>{};
      final species = <String, FilterOption>{};

      for (final point in points) {
        if (point.region != null && point.region!.isNotEmpty) {
          regions[point.region!] = (regions[point.region!] ?? 0) + 1;
        }
        if (point.reefName != null && point.reefName!.isNotEmpty) {
          reefs[point.reefName!] = (reefs[point.reefName!] ?? 0) + 1;
        }
        final resolvedName = _resolveSpeciesName(
          speciesName: point.speciesName,
          speciesId: point.speciesId,
        );
        final speciesKey = point.speciesId?.trim().isNotEmpty == true
            ? point.speciesId!.trim()
            : resolvedName;
        if (speciesKey != null && resolvedName != null && resolvedName.isNotEmpty) {
          final existing = species[speciesKey];
          species[speciesKey] = FilterOption(
            id: speciesKey,
            name: resolvedName,
            count: (existing?.count ?? 0) + 1,
          );
        }
      }

      return HistoricalFilterOptions(
        regions:
            regions.entries
                .map(
                  (e) => FilterOption(id: e.key, name: e.key, count: e.value),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
        reefs:
            reefs.entries
                .map(
                  (e) => FilterOption(id: e.key, name: e.key, count: e.value),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
        species:
            species.values.toList()
              ..sort(
                (a, b) => b.count.compareTo(a.count),
              ), // Sort by count desc
      );
    } catch (e) {
      return const HistoricalFilterOptions();
    }
  }

  /// Fetch available years from outplant events
  Future<List<int>> fetchAvailableYears({required String datasetId}) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_outplant_events')
          .where('datasetId', isEqualTo: datasetId)
          .get();

      final years = <int>{};
      for (final doc in query.docs) {
        final data = doc.data();
        final eventDate = _parseEventDate(data['eventDate']);
        if (eventDate != null) {
          final year = eventDate.year;
          if (year > 1990 && year < 2100) {
            years.add(year);
          }
          continue;
        }

        final fiveAxis = _asMap(data['fiveAxis']);
        final measurement = _asMap(fiveAxis?['measurement']);
        final legacyDate = measurement?['eventDate'];
        if (legacyDate is String && legacyDate.isNotEmpty) {
          final year = int.tryParse(legacyDate.split('-')[0]);
          if (year != null && year > 1990 && year < 2100) {
            years.add(year);
          }
        }
      }

      return years.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  /// Fetch available genotypes from outplant events
  /// Note: Many genotypes ARE named after collection sites (e.g., "snapper ledge",
  /// "horseshoe", "conch") - this is common practice in coral restoration.
  /// We rely on _isValidGenetName to filter out invalid entries.
  Future<List<String>> fetchAvailableGenets({required String datasetId}) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_outplant_events')
          .where('datasetId', isEqualTo: datasetId)
          .get();

      final genets = <String>{};

      // Collect valid genet names - rely on _isValidGenetName for filtering
      // Don't exclude site-named genets since many genotypes ARE named after sites
      for (final doc in query.docs) {
        final data = doc.data();
        final genotypes = data['genotypes'];
        if (genotypes is List) {
          for (final genotype in genotypes) {
            if (genotype is! Map<String, dynamic>) continue;
            final rawName =
                (genotype['displayName'] ?? genotype['id'])?.toString();
            if (rawName == null || rawName.isEmpty) continue;
            if (rawName == 'Unknown' || rawName == 'ACERUNK') continue;
            if (_isValidGenetName(rawName)) {
              genets.add(rawName);
            }
          }
          continue;
        }

        // Legacy fallback (five-axis structure)
        final fiveAxis = _asMap(data['fiveAxis']);
        final provenance = _asMap(fiveAxis?['provenance']);
        final legacyName = provenance?['genotypeName'];
        if (legacyName is String &&
            legacyName.isNotEmpty &&
            legacyName != 'Unknown' &&
            legacyName != 'ACERUNK' &&
            _isValidGenetName(legacyName)) {
          genets.add(legacyName);
        }
      }

      return genets.toList()..sort(_compareGenetNames);
    } catch (e) {
      return [];
    }
  }

  /// Check if a name looks like a valid genotype identifier
  /// Valid genotype names follow patterns like: AP40, ACER-001, MC-12, Yung's-B, etc.
  /// Exclude site names entered in wrong field (conch, horseshoe, pickles, unk)
  bool _isValidGenetName(String name) {
    final lower = name.toLowerCase().trim();

    // Skip empty or very short
    if (name.isEmpty || name.length < 2) return false;

    // Skip pure numbers - these are site IDs entered in wrong column
    if (RegExp(r'^\d+$').hasMatch(name)) return false;

    // Skip generic unknowns
    if (lower == 'unknown' || lower == 'unk' || lower == 'acerunk') {
      return false;
    }

    // Skip common site/reef names that got entered in genotype field (data quality issue)
    // These are clearly NOT valid genotype IDs
    const invalidSiteNames = {
      'conch',
      'horseshoe',
      'pickles',
      'snapper',
      'snapper ledge',
      'snapper\'s ledge',
      'carysfort',
      'molasses',
      'french reef',
      'elbow',
      'dixie shoal',
      'horseshoe reef',
      'conch reef',
      'pickles reef',
      'alligator',
      'tavernier',
      'key largo',
      'looe key',
      'sombrero',
    };
    if (invalidSiteNames.contains(lower)) return false;

    // Skip entries that are clearly site descriptions (multiple words with location terms)
    if (name.split(' ').length >= 2 &&
        (lower.contains('reef') ||
            lower.contains('site') ||
            lower.contains('area') ||
            lower.contains('frame') ||
            lower.contains('dive program') ||
            lower.contains('patch') ||
            lower.contains('key') ||
            lower.contains('ledge'))) {
      return false;
    }

    // Valid genotype patterns:
    // - Alphanumeric codes: AP40, MC12, OFAV-001, ACER-1
    // - Named genotypes: Yung's-B, Yung's mixed
    // - Simple codes with hyphens or numbers: AP-40, M-12

    // Require at least one letter AND one number/hyphen for simple names
    // OR allow possessive names (Yung's)
    if (lower.contains("'s") || lower.contains("'s")) {
      return true; // Named genotypes like "Yung's-B"
    }

    // Must have at least one digit or be an uppercase pattern like "ACER", "APAL"
    final hasDigit = RegExp(r'\d').hasMatch(name);
    final isUppercasePattern = RegExp(
      r'^[A-Z]{2,4}(-[A-Z0-9]+)?$',
    ).hasMatch(name);

    return hasDigit || isUppercasePattern;
  }

  /// Sort genet names alphanumerically
  int _compareGenetNames(String a, String b) {
    // Extract prefix and number for natural sorting
    final aMatch = RegExp(r'^([A-Za-z]+)(\d*)').firstMatch(a);
    final bMatch = RegExp(r'^([A-Za-z]+)(\d*)').firstMatch(b);

    if (aMatch != null && bMatch != null) {
      final prefixCmp = aMatch.group(1)!.compareTo(bMatch.group(1)!);
      if (prefixCmp != 0) return prefixCmp;

      final aNum = int.tryParse(aMatch.group(2) ?? '') ?? 0;
      final bNum = int.tryParse(bMatch.group(2) ?? '') ?? 0;
      return aNum.compareTo(bNum);
    }

    return a.compareTo(b);
  }

  /// Fetch site IDs that have outplants in a given year
  Future<Set<String>> fetchSiteIdsForYear({
    required String datasetId,
    required int year,
  }) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_outplant_events')
          .where('datasetId', isEqualTo: datasetId)
          .get();

      final siteIds = <String>{};
      for (final doc in query.docs) {
        final data = doc.data();
        final eventDate = _parseEventDate(data['eventDate']);
        if (eventDate != null) {
          if (eventDate.year != year) continue;
          final siteId = data['siteId']?.toString();
          if (siteId != null && siteId.isNotEmpty) {
            siteIds.add(siteId);
          }
          continue;
        }

        // Legacy fallback (five-axis structure)
        final fiveAxis = _asMap(data['fiveAxis']);
        final measurement = _asMap(fiveAxis?['measurement']);
        final legacyDate = measurement?['eventDate'];
        if (legacyDate is String && legacyDate.startsWith('$year-')) {
          final location = _asMap(fiveAxis?['location']);
          final legacySiteId = location?['siteId']?.toString();
          if (legacySiteId != null && legacySiteId.isNotEmpty) {
            siteIds.add(legacySiteId);
          }
        }
      }

      return siteIds;
    } catch (e) {
      return {};
    }
  }

  /// Fetch site IDs that have a specific genotype
  Future<Set<String>> fetchSiteIdsForGenet({
    required String datasetId,
    required String genet,
  }) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_outplant_events')
          .where('datasetId', isEqualTo: datasetId)
          .get();

      final siteIds = <String>{};
      final normalizedTarget = genet.trim();
      for (final doc in query.docs) {
        final data = doc.data();
        final genotypes = data['genotypes'];
        if (genotypes is List) {
          var matches = false;
          for (final genotype in genotypes) {
            if (genotype is! Map<String, dynamic>) continue;
            final displayName =
                (genotype['displayName'] ?? genotype['id'])?.toString();
            if (displayName == null || displayName.isEmpty) continue;
            if (displayName == normalizedTarget ||
                displayName.toUpperCase() ==
                    normalizedTarget.toUpperCase()) {
              matches = true;
              break;
            }
          }
          if (!matches) continue;
          final siteId = data['siteId']?.toString();
          if (siteId != null && siteId.isNotEmpty) {
            siteIds.add(siteId);
          }
          continue;
        }

        // Legacy fallback (five-axis structure)
        final fiveAxis = _asMap(data['fiveAxis']);
        final provenance = _asMap(fiveAxis?['provenance']);
        final legacyName = provenance?['genotypeName'];
        if (legacyName == normalizedTarget) {
          final location = _asMap(fiveAxis?['location']);
          final legacySiteId = location?['siteId']?.toString();
          if (legacySiteId != null && legacySiteId.isNotEmpty) {
            siteIds.add(legacySiteId);
          }
        }
      }

      return siteIds;
    } catch (e) {
      return {};
    }
  }

  /// Fetch detailed outplant events for a specific site
  Future<SiteOutplantDetails> fetchSiteOutplantDetails({
    required String datasetId,
    required String siteId,
  }) async {
    try {
      final query = await _resolver
          .collection(_firestore, 'historical_outplant_events')
          .where('datasetId', isEqualTo: datasetId)
          .get();

      final events = <OutplantEventSummary>[];
      final genotypeMap = <_GenotypeKey, int>{};
      final speciesMap = <String, int>{};
      int totalColonies = 0;
      int totalEvents = 0;
      String? siteName;
      String? reefName;
      String? region;

      for (final doc in query.docs) {
        final data = doc.data();
        final eventSiteId =
            data['siteId']?.toString() ??
            _asMap(_asMap(data['fiveAxis'])?['location'])?['siteId']
                ?.toString();

        if (eventSiteId != siteId) continue;

        totalEvents += 1;

        // Extract site info
        siteName ??= data['siteName'] as String?;
        reefName ??= data['reefName'] as String?;
        region ??= data['region'] as String?;

        final fiveAxis = _asMap(data['fiveAxis']);
        final taxonomy = _asMap(fiveAxis?['taxonomy']);
        final legacySpeciesName = taxonomy?['scientificName'] as String?;

        final speciesName = _resolveSpeciesName(
          speciesName: data['speciesName'] as String? ?? legacySpeciesName,
          speciesId: data['speciesId'] as String?,
        ) ?? 'Unknown';

        final eventDate =
            _normalizeEventDateString(data['eventDate']) ??
            (_asMap(fiveAxis?['measurement'])?['eventDate'] as String?);
        final eventMagnitude =
            safeInt(data['magnitude']) ??
            safeInt(_asMap(fiveAxis?['measurement'])?['colonies']) ??
            0;

        final genotypes = data['genotypes'];
        var eventColonies = 0;
        if (genotypes is List) {
          for (final genotype in genotypes) {
            if (genotype is! Map<String, dynamic>) continue;
            final genotypeName =
                (genotype['displayName'] ?? genotype['id'])?.toString() ??
                'Unknown';
            final colonies =
                safeInt(genotype['colonies']) ?? 0;
            eventColonies += colonies;

            if (genotypeName != 'Unknown' && genotypeName != 'ACERUNK') {
              final key = _GenotypeKey(
                genotypeName: genotypeName,
                speciesName: speciesName,
              );
              genotypeMap[key] = (genotypeMap[key] ?? 0) + colonies;
            }

            events.add(
              OutplantEventSummary(
                eventDate: eventDate,
                speciesName: speciesName,
                genotypeName: genotypeName,
                colonies: colonies,
              ),
            );
          }
        } else {
          final legacyProvenance = _asMap(fiveAxis?['provenance']);
          final legacyGenotypeName =
              legacyProvenance?['genotypeName'] as String? ?? 'Unknown';
          final legacyColonies =
              safeInt(_asMap(fiveAxis?['measurement'])?['colonies']) ??
              0;
          eventColonies += legacyColonies;

          if (legacyGenotypeName != 'Unknown' &&
              legacyGenotypeName != 'ACERUNK') {
            final key = _GenotypeKey(
              genotypeName: legacyGenotypeName,
              speciesName: speciesName,
            );
            genotypeMap[key] = (genotypeMap[key] ?? 0) + legacyColonies;
          }

          events.add(
            OutplantEventSummary(
              eventDate: eventDate,
              speciesName: speciesName,
              genotypeName: legacyGenotypeName,
              colonies: legacyColonies,
            ),
          );
        }

        if (eventColonies == 0) {
          eventColonies = eventMagnitude;
          events.add(
            OutplantEventSummary(
              eventDate: eventDate,
              speciesName: speciesName,
              genotypeName: 'Unknown',
              colonies: eventMagnitude,
            ),
          );
        }

        totalColonies += eventColonies;

        // Aggregate by species
        speciesMap[speciesName] = (speciesMap[speciesName] ?? 0) + eventColonies;
      }

      // Sort events by date descending
      events.sort((a, b) => (b.eventDate ?? '').compareTo(a.eventDate ?? ''));

      // Convert maps to sorted lists
      final genotypes =
          genotypeMap.entries
              .map(
                (e) => GenotypeCount(
                  name: e.key.genotypeName,
                  speciesName: e.key.speciesName,
                  colonies: e.value,
                ),
              )
              .toList()
            ..sort((a, b) => b.colonies.compareTo(a.colonies));

      final species =
          speciesMap.entries
              .map((e) => SpeciesCount(name: e.key, colonies: e.value))
              .toList()
            ..sort((a, b) => b.colonies.compareTo(a.colonies));

      return SiteOutplantDetails(
        siteId: siteId,
        siteName: siteName,
        reefName: reefName,
        region: region,
        totalColonies: totalColonies,
        totalEvents: totalEvents,
        events: events,
        genotypes: genotypes,
        species: species,
      );
    } catch (e) {
      return SiteOutplantDetails(
        siteId: siteId,
        totalColonies: 0,
        totalEvents: 0,
        events: [],
        genotypes: [],
        species: [],
      );
    }
  }
}

/// Summary of outplant details for a specific site
class SiteOutplantDetails {
  const SiteOutplantDetails({
    required this.siteId,
    this.siteName,
    this.reefName,
    this.region,
    required this.totalColonies,
    required this.totalEvents,
    required this.events,
    required this.genotypes,
    required this.species,
  });

  final String siteId;
  final String? siteName;
  final String? reefName;
  final String? region;
  final int totalColonies;
  final int totalEvents;
  final List<OutplantEventSummary> events;
  final List<GenotypeCount> genotypes;
  final List<SpeciesCount> species;
}

/// Summary of a single outplant event
class OutplantEventSummary {
  const OutplantEventSummary({
    this.eventDate,
    required this.speciesName,
    required this.genotypeName,
    required this.colonies,
  });

  final String? eventDate;
  final String speciesName;
  final String genotypeName;
  final int colonies;
}

/// Genotype with colony count
class _GenotypeKey {
  const _GenotypeKey({required this.genotypeName, required this.speciesName});

  final String genotypeName;
  final String speciesName;

  @override
  bool operator ==(Object other) {
    return other is _GenotypeKey &&
        other.genotypeName == genotypeName &&
        other.speciesName == speciesName;
  }

  @override
  int get hashCode => Object.hash(genotypeName, speciesName);
}

class GenotypeCount {
  const GenotypeCount({
    required this.name,
    required this.speciesName,
    required this.colonies,
  });
  final String name;
  final String speciesName;
  final int colonies;
}

/// Species with colony count
class SpeciesCount {
  const SpeciesCount({required this.name, required this.colonies});
  final String name;
  final int colonies;
}
