// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/models.dart';

class ArchivedOrganismRecordRepository {
  ArchivedOrganismRecordRepository({
    required this.organization,
    required this.user,
    required this.firestore,
  });

  final Organization organization;
  final User user;
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> get _archivedCollection =>
      firestore
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection('archived_organism_records');

  CollectionReference<Map<String, dynamic>> get _activeCollection =>
      firestore
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection(ModelType.organismRecord.collectionPath);

  Stream<List<OrganismRecord>> streamAll() {
    final archivedStream = _archivedCollection.snapshots().map(_parseSnapshot);
    final legacyArchivedStream = _activeCollection
        .where('archived', isEqualTo: true)
        .snapshots()
        .map(_parseSnapshot);
    final legacyMetadataStream = _activeCollection
        .where('metadata.archived', isEqualTo: true)
        .snapshots()
        .map(_parseSnapshot);
    final legacyDeletedStream = _activeCollection
        .where('isDeleted', isEqualTo: true)
        .snapshots()
        .map(_parseSnapshot);

    return Rx.combineLatest4(
      archivedStream,
      legacyArchivedStream,
      legacyMetadataStream,
      legacyDeletedStream,
      (a, b, c, d) => _mergeAndSort([a, b, c, d]),
    );
  }

  Future<List<OrganismRecord>> getAll() async {
    final archived = await _archivedCollection.get();
    final legacyArchived = await _activeCollection
        .where('archived', isEqualTo: true)
        .get();
    final legacyMetadata = await _activeCollection
        .where('metadata.archived', isEqualTo: true)
        .get();
    final legacyDeleted =
        await _activeCollection.where('isDeleted', isEqualTo: true).get();

    return _mergeAndSort([
      _parseSnapshot(archived),
      _parseSnapshot(legacyArchived),
      _parseSnapshot(legacyMetadata),
      _parseSnapshot(legacyDeleted),
    ]);
  }

  Future<void> restoreRecord(OrganismRecord record) async {
    final now = DateTime.now().toIso8601String();
    final cleanedMetadata = <String, dynamic>{
      ...record.metadata ?? const {},
    }
      ..remove(kArchivedFlagKey)
      ..remove(kArchivedAtKey)
      ..remove(kArchivedByIdKey)
      ..remove(kArchivedReasonTypeKey)
      ..remove(kArchivedReasonIdKey)
      ..remove('isDeleted');

    final restored = record.copyWith(
      metadata: cleanedMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    final batch = firestore.batch();
    batch.set(_activeCollection.doc(record.id), restored.toJson());
    batch.delete(_archivedCollection.doc(record.id));
    await batch.commit();
  }

  List<OrganismRecord> _parseSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final records = <OrganismRecord>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      records.add(RecordFactory.recordFromJson<OrganismRecord>(data));
    }
    return records;
  }

  List<OrganismRecord> _mergeAndSort(List<List<OrganismRecord>> lists) {
    final merged = <String, OrganismRecord>{};
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

  DateTime _archiveSortDate(OrganismRecord record) {
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
