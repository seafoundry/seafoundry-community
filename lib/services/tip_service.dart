// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_info_service.dart';
import 'package:yaml/yaml.dart';

/// TipService provides lightweight access to contextual educational tips
/// stored under the Firestore `tips` collection. Tips can be filtered by
/// species, node type (e.g. nursery vs outplant), and user role.
///
/// Additionally integrates with [SpeciesInfoService] to fetch dynamic
/// species facts from external APIs (Wikipedia, GBIF).
class TipService {
  TipService({
    required FirebaseFirestore firestore,
    FirestoreCollectionResolver? resolver,
    SpeciesInfoService? speciesInfoService,
  })  : _firestore = firestore,
        _resolver = resolver ?? FirestoreCollectionResolver.instance,
        _speciesInfoService = speciesInfoService;

  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver;
  final SpeciesInfoService? _speciesInfoService;

  /// Stream a list of Tip objects filtered by optional fields. Only approved
  /// tips are returned. If no filters are supplied, returns a general set
  /// of approved tips.
  ///
  /// If [speciesName] is provided and [SpeciesInfoService] is available,
  /// external API facts will be included alongside internal tips.
  Stream<List<Tip>> streamTips({
    String? speciesId,
    String? speciesName,
    String? nodeType,
    String? role,
    int limit = 10,
  }) {
    // 1. Create stream from Firestore
    Query<Map<String, dynamic>> q = _resolver.collection(_firestore, 'tips');
    q = q.where('approved', isEqualTo: true);
    if (speciesId != null && speciesId.isNotEmpty) {
      q = q.where('speciesId', isEqualTo: speciesId);
    }
    if (nodeType != null && nodeType.isNotEmpty) {
      q = q.where('nodeType', isEqualTo: nodeType);
    }
    if (role != null && role.isNotEmpty) {
      q = q.where('role', isEqualTo: role);
    }
    q = q.limit(limit);

    final firestoreStream = q.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return Tip(
              text: (data['text'] ?? '').toString().trim(),
              imageUrl: data['imageUrl']?.toString(),
            );
          })
          .where((tip) => tip.text.isNotEmpty)
          .toList(growable: false);
    }).startWith(const []);

    // 2. Load and filter local tips
    // We use a Stream.fromFuture to load the YAML once and then emit it.
    // In a real app, we might want to cache this in memory.
    final localStream = Stream.fromFuture(_loadLocalTips()).map((allTips) {
      return allTips.where((tip) {
        if (speciesId != null && tip.speciesId != null && tip.speciesId != speciesId) {
          return false;
        }
        if (nodeType != null && tip.nodeType != null && tip.nodeType != nodeType) {
          return false;
        }
        if (role != null && tip.role != null && tip.role != role) {
          return false;
        }
        return true;
      }).toList();
    });

    // 3. Load external species facts if service is available and species is specified
    final externalStream = _loadExternalFacts(speciesName);

    // 4. Merge all streams
    return Rx.combineLatest3<List<Tip>, List<Tip>, List<Tip>, List<Tip>>(
      localStream,
      firestoreStream,
      externalStream,
      (local, remote, external) => [...external, ...local, ...remote],
    );
  }

  /// Loads facts from external APIs for the given species name.
  Stream<List<Tip>> _loadExternalFacts(String? speciesName) {
    if (_speciesInfoService == null || speciesName == null || speciesName.isEmpty) {
      return Stream.value(const []);
    }

    return Stream.fromFuture(
      _speciesInfoService.getFactForSpecies(speciesName),
    ).map((fact) {
      if (fact == null) return const <Tip>[];
      return [
        Tip(
          text: fact.text,
          imageUrl: fact.imageUrl,
          source: TipSource.fromFactSource(fact.source),
        ),
      ];
    }).onErrorReturnWith((e, stackTrace) {
      if (kDebugMode) {
        LoggingService.instance.warning('TipService: Error loading external facts: $e');
      }
      return const <Tip>[];
    }).startWith(const []);
  }

  Future<List<Tip>> _loadLocalTips() async {
    try {
      final yamlString = await rootBundle.loadString('config/tips.defaults.yaml');
      final yaml = loadYaml(yamlString);
      if (yaml is Map && yaml['tips'] is List) {
        return (yaml['tips'] as List).map((node) {
          if (node is Map) {
            return Tip(
              text: node['text']?.toString() ?? '',
              imageUrl: node['imageUrl']?.toString(),
              speciesId: node['speciesId']?.toString(),
              nodeType: node['nodeType']?.toString(),
              role: node['role']?.toString(),
              source: TipSource.internal,
            );
          }
          return const Tip(text: '');
        }).where((t) => t.text.isNotEmpty).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('TipService: Error loading local tips: $e');
      }
    }
    return [];
  }

  /// Convenience getter from widget tree when provided via Provider.
  static TipService of(BuildContext context, {bool listen = false}) {
    return context.dependOnInheritedWidgetOfExactType<_TipServiceScope>()!.service;
  }

  /// Wrap a subtree with a TipService provider without introducing an
  /// external dependency on Provider.
  static Widget provider({required TipService service, required Widget child}) {
    return _TipServiceScope(service: service, child: child);
  }

  /// Disposes of resources including the [SpeciesInfoService].
  void dispose() {
    _speciesInfoService?.dispose();
  }
}

/// Source of a tip for attribution.
enum TipSource {
  internal,
  firestore,
  wikipedia,
  gbif,
  unknown;

  static TipSource fromFactSource(SpeciesFactSource source) {
    switch (source) {
      case SpeciesFactSource.wikipedia:
        return TipSource.wikipedia;
      case SpeciesFactSource.gbif:
        return TipSource.gbif;
      case SpeciesFactSource.unknown:
        return TipSource.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case TipSource.internal:
        return 'SeaFoundry';
      case TipSource.firestore:
        return 'SeaFoundry';
      case TipSource.wikipedia:
        return 'Wikipedia';
      case TipSource.gbif:
        return 'GBIF';
      case TipSource.unknown:
        return '';
    }
  }
}

class Tip {
  const Tip({
    required this.text,
    this.imageUrl,
    this.speciesId,
    this.nodeType,
    this.role,
    this.source = TipSource.internal,
  });

  final String text;
  final String? imageUrl;
  final String? speciesId;
  final String? nodeType;
  final String? role;
  final TipSource source;
}

class _TipServiceScope extends InheritedWidget {
  const _TipServiceScope({required this.service, required super.child});
  final TipService service;

  @override
  bool updateShouldNotify(covariant _TipServiceScope oldWidget) => false;
}
