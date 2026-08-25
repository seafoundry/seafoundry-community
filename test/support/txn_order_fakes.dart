import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/mockito.dart' show Fake;
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/records/graph_node_record.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/population_measurement.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';

/// Shared, ordered call log used by the slug-ordering regression tests.
///
/// Every slug mint appends `slug:<modelType>` and entry into the outer
/// transaction appends `runTransaction`. The tests assert that all slug mints
/// precede `runTransaction` — this fails on pre-fix code (which minted slugs
/// inside the transaction closure) and passes after the plan-then-commit fix.
class CallLog {
  final List<String> entries = <String>[];

  void slug(ModelType type) => entries.add('slug:${type.name}');
  void runTransaction() => entries.add('runTransaction');

  List<String> get slugEntries =>
      entries.where((e) => e.startsWith('slug:')).toList();
  int get transactionIndex => entries.indexOf('runTransaction');
}

/// A [FirebaseFirestore] stand-in that records when the outer transaction is
/// entered and returns a canned result WITHOUT invoking the transaction handler.
///
/// It subclasses [FakeFirebaseFirestore] so `collection()`/`doc()` (used by
/// `generateId` outside the transaction) work against real fake references,
/// while [runTransaction] is overridden purely to log entry.
///
/// Not invoking the handler is deliberate: the fix pre-mints all slugs OUTSIDE
/// the transaction. If a future change moves a mint back inside the closure,
/// the outside mints disappear and the slug-count/ordering assertions fail.
class RecordingFirestore extends FakeFirebaseFirestore {
  RecordingFirestore(this.log, this._canned);

  final CallLog log;
  final OrganismRecord _canned;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    log.runTransaction();
    return _canned as T;
  }
}

class FakeOrganismRecordRepository extends Fake
    implements OrganismRecordRepository {
  FakeOrganismRecordRepository({
    required this.db,
    required this.log,
  });

  @override
  final FirebaseFirestore db;
  final CallLog log;

  @override
  ModelType get modelType => ModelType.organismRecord;

  @override
  Future<String> nextSlugForModelType(ModelType modelType) async {
    log.slug(modelType);
    return '${modelType.name}1';
  }
}

class FakeGraphRepository extends Fake implements GraphRepository {
  @override
  Future<GraphNode<GraphNodeRecord>?> getNodeForUrlPath(String urlPath) async =>
      null;
}

/// Builds a minimal but valid [OrganismRecord] for driving the blocs.
OrganismRecord makeOrganism({
  required String id,
  required String tagId,
  double quantity = 10,
  String urlPath = 'organizations/org1/groups/g1/records/rec',
}) {
  return OrganismRecord.partial(
    id: id,
    createdAt: '2026-01-01T00:00:00.000Z',
    createdById: 'user1',
    updatedAt: '2026-01-02T00:00:00.000Z',
    updatedById: 'user1',
    organizationId: 'org1',
    urlPath: urlPath,
    internalPath: 'organizations/org1/groups/g1/records/$id',
    slug: 'organismRecord-$id',
    tagId: tagId,
    measurement: PopulationMeasurement(
      value: quantity,
      unit: MeasurementUnit.count,
    ),
  );
}
