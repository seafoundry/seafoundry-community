// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/mission.dart';
import 'package:seafoundry_app/models/records/archive_metadata.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

class ArchivedMissionRepository {
  ArchivedMissionRepository({
    required this.organization,
    required this.user,
    required this.firestore,
  });

  final Organization organization;
  final User user;
  final FirebaseFirestore firestore;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  CollectionReference<Map<String, dynamic>> get _archivedCollection =>
      _resolver.subcollection(
        firestore,
        ModelType.organization.collectionPath,
        organization.id,
        'archived_missions',
      );

  CollectionReference<Map<String, dynamic>> get _activeCollection =>
      _resolver.collection(firestore, ModelType.mission.collectionPath);

  Stream<List<Mission>> streamAll() {
    final archivedStream = _archivedCollection
        .where('organizationId', isEqualTo: organization.id)
        .snapshots()
        .map(_parseSnapshot);
    final legacyArchivedStream = _activeCollection
        .where('organizationId', isEqualTo: organization.id)
        .where('metadata.archived', isEqualTo: true)
        .snapshots()
        .map(_parseSnapshot);
    final legacyTopLevelStream = _activeCollection
        .where('organizationId', isEqualTo: organization.id)
        .where('archived', isEqualTo: true)
        .snapshots()
        .map(_parseSnapshot);

    return Rx.combineLatest3(
      archivedStream,
      legacyArchivedStream,
      legacyTopLevelStream,
      (a, b, c) => _mergeAndSort([a, b, c]),
    );
  }

  Future<List<Mission>> getAll() async {
    final archived = await _archivedCollection
        .where('organizationId', isEqualTo: organization.id)
        .get();
    final legacyArchived = await _activeCollection
        .where('organizationId', isEqualTo: organization.id)
        .where('metadata.archived', isEqualTo: true)
        .get();
    final legacyTopLevel = await _activeCollection
        .where('organizationId', isEqualTo: organization.id)
        .where('archived', isEqualTo: true)
        .get();
    return _mergeAndSort([
      _parseSnapshot(archived),
      _parseSnapshot(legacyArchived),
      _parseSnapshot(legacyTopLevel),
    ]);
  }

  Future<void> restoreMission(Mission mission) async {
    final now = DateTime.now().toIso8601String();
    final cleanedMetadata = <String, dynamic>{
      ...mission.metadata ?? const {},
    }
      ..remove(kArchivedFlagKey)
      ..remove(kArchivedAtKey)
      ..remove(kArchivedByIdKey)
      ..remove(kArchivedReasonTypeKey)
      ..remove(kArchivedReasonIdKey);

    final restored = mission.copyWith(
      metadata: cleanedMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    final batch = firestore.batch();
    batch.set(_activeCollection.doc(mission.id), restored.toJson());
    batch.delete(_archivedCollection.doc(mission.id));
    await batch.commit();
  }

  List<Mission> _parseSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final records = <Mission>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      records.add(Mission.fromJson(data));
    }
    return records;
  }

  List<Mission> _mergeAndSort(List<List<Mission>> lists) {
    final merged = <String, Mission>{};
    for (final list in lists) {
      for (final record in list) {
        merged[record.id] = record;
      }
    }
    final records = merged.values.toList();
    records.sort(
      (a, b) => _archiveSortDate(b).compareTo(_archiveSortDate(a)),
    );
    return records;
  }

  DateTime _archiveSortDate(Mission record) {
    final raw = record.metadata?[kArchivedAtKey];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return record.updatedAtDateTime;
  }
}
