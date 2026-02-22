// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';

class ArchivedGenetRepository {
  ArchivedGenetRepository({
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
        'archived_genets',
      );

  CollectionReference<Map<String, dynamic>> get _activeCollection =>
      _resolver.subcollection(
        firestore,
        ModelType.organization.collectionPath,
        organization.id,
        ModelType.genet.collectionPath,
      );

  Stream<List<Genet>> streamAll() {
    final archivedStream = _archivedCollection.snapshots().map(_parseSnapshot);
    final legacyArchivedStream = _activeCollection
        .where('archived', isEqualTo: true)
        .snapshots()
        .map(_parseSnapshot);

    return Rx.combineLatest2(
      archivedStream,
      legacyArchivedStream,
      (a, b) => _mergeAndSort([a, b]),
    );
  }

  Future<List<Genet>> getAll() async {
    final archived = await _archivedCollection.get();
    final legacyArchived = await _activeCollection
        .where('archived', isEqualTo: true)
        .get();
    return _mergeAndSort([
      _parseSnapshot(archived),
      _parseSnapshot(legacyArchived),
    ]);
  }

  Future<void> restoreGenet(Genet genet) async {
    final now = DateTime.now().toIso8601String();
    final cleanedMetadata = <String, dynamic>{
      ...genet.metadata,
    }
      ..remove(kArchivedFlagKey)
      ..remove(kArchivedAtKey)
      ..remove(kArchivedByIdKey)
      ..remove(kArchivedReasonTypeKey)
      ..remove(kArchivedReasonIdKey);

    final restored = genet.copyWith(
      archived: false,
      archivedAt: null,
      metadata: cleanedMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    final batch = firestore.batch();
    batch.set(_activeCollection.doc(genet.id), restored.toJson());
    batch.delete(_archivedCollection.doc(genet.id));
    await batch.commit();
  }

  List<Genet> _parseSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final records = <Genet>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      records.add(RecordFactory.recordFromJson<Genet>(data));
    }
    return records;
  }

  List<Genet> _mergeAndSort(List<List<Genet>> lists) {
    final merged = <String, Genet>{};
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

  DateTime _archiveSortDate(Genet record) {
    if (record.archivedAt != null) {
      return record.archivedAt!;
    }
    final raw = record.metadata[kArchivedAtKey];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return record.updatedAtDateTime;
  }
}
