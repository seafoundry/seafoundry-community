import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_community/models/genet.dart';
import 'package:seafoundry_community/models/group.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_community/repositories/inventory/group_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';

/// Service for looking up entities during inventory CSV import.
///
/// Provides cached lookups for organisms, groups, and genets to avoid
/// redundant database queries during batch imports.
class InventoryLookupService {
  InventoryLookupService({
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
    required GenetRepository genetRepository,
  }) : _organismRecordRepository = organismRecordRepository,
       _groupRepository = groupRepository,
       _genetRepository = genetRepository;

  final OrganismRecordRepository _organismRecordRepository;
  final GroupRepository _groupRepository;
  final GenetRepository _genetRepository;

  final Map<String, OrganismRecord?> _organismCache = {};
  final Map<String, Group?> _groupCache = {};
  final Map<String, Genet?> _genetCache = {};

  /// Clears all cached lookups.
  void clearCaches() {
    _organismCache.clear();
    _groupCache.clear();
    _genetCache.clear();
  }

  /// Looks up an organism record by ID with caching.
  Future<OrganismRecord?> lookupOrganism(String organismId) async {
    if (_organismCache.containsKey(organismId)) {
      return _organismCache[organismId];
    }
    final organism = await _organismRecordRepository.getRecordForId(organismId);
    _organismCache[organismId] = organism;
    return organism;
  }

  /// Looks up a group by URL path with caching.
  ///
  /// First attempts to find the group in the main collection, then falls
  /// back to the organization-scoped collection.
  Future<Group?> lookupGroup(String urlPath) async {
    if (_groupCache.containsKey(urlPath)) {
      return _groupCache[urlPath];
    }

    Group? group = await _queryGroupCollection(
      _groupRepository.collectionRef,
      urlPath,
    );

    if (group == null) {
      // Use resolver for organization-scoped group lookup
      final orgPath =
          '${ModelType.organization.collectionPath}/${_groupRepository.organization.id}/${ModelType.group.collectionPath}';
      final orgCollection = _groupRepository.firestore.collection(orgPath);
      group = await _queryGroupCollection(orgCollection, urlPath);
    }

    _groupCache[urlPath] = group;
    return group;
  }

  Future<Group?> _queryGroupCollection(
    CollectionReference<Map<String, dynamic>> collection,
    String urlPath,
  ) async {
    final snapshot = await collection
        .where('urlPath', isEqualTo: urlPath)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final doc = snapshot.docs.first;
    final data = Map<String, dynamic>.from(doc.data());
    data['id'] = doc.id;
    return Group.fromJson(data);
  }

  /// Looks up a genet by provenance ID with caching.
  Future<Genet?> lookupGenetByProvenanceId(String provenanceId) async {
    if (_genetCache.containsKey(provenanceId)) {
      return _genetCache[provenanceId];
    }
    // Query by provenanceId field (Firestore field name)
    final snapshot = await _genetRepository.collectionRef
        .where('provenanceId', isEqualTo: provenanceId)
        .limit(1)
        .get();
    Genet? genet;
    if (snapshot.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(snapshot.docs.first.data());
      data['id'] = snapshot.docs.first.id;
      genet = Genet.fromJson(data);
    }
    _genetCache[provenanceId] = genet;
    return genet;
  }
}
