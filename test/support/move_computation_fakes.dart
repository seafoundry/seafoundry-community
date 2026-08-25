import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:seafoundry_community/models/group.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/models/population_measurement.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';
import 'package:seafoundry_community/models/user.dart';
import 'package:seafoundry_community/repositories/inventory/event_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';

const _iso = '2026-01-01T00:00:00.000Z';

Organization buildOrganization() => Organization(
      id: 'org1',
      createdById: 'user1',
      createdAt: _iso,
      updatedAt: _iso,
      updatedById: 'user1',
      organizationId: 'org1',
      urlPath: 'org1',
      internalPath: 'organizations/org1',
      slug: 'org1',
      name: 'Test Org',
      domain: 'org1',
    );

User buildUser() => User.partial(
      id: 'user1',
      name: 'Tester',
      email: 'tester@example.com',
      organizationId: 'org1',
      createdById: 'user1',
      createdAt: _iso,
      updatedAt: _iso,
      updatedById: 'user1',
    );

/// Real [EventRepository] + [OrganismRecordRepository] over a shared in-memory
/// Firestore. `enforceAuth: false` skips auth checks; the fake supports the
/// slug-counter transaction used by `nextSlugForBase`.
({
  FakeFirebaseFirestore db,
  EventRepository events,
  OrganismRecordRepository organisms,
}) buildMoveRepos() {
  final db = FakeFirebaseFirestore();
  final org = buildOrganization();
  final user = buildUser();
  final events = EventRepository(
    organization: org,
    user: user,
    firestore: db,
    // enforceAuth defaults true on EventRepository; the move-event/compute
    // methods under test perform no auth network I/O.
  );
  final organisms = OrganismRecordRepository(
    organization: org,
    user: user,
    firestore: db,
    eventRepository: events,
    enforceAuth: false,
  );
  return (db: db, events: events, organisms: organisms);
}

OrganismRecord buildOrganism({
  String id = 'src-1',
  String tagId = 'Original',
  double quantity = 10,
  String urlPath = 'organizations/org1/groups/g1/records/src-1',
  String internalPath = 'organizations/org1/groups/g1/records/src-1',
  String slug = 'organismRecord-src-1',
}) {
  return OrganismRecord.partial(
    id: id,
    createdAt: _iso,
    createdById: 'user1',
    updatedAt: '2026-01-02T00:00:00.000Z',
    updatedById: 'user1',
    organizationId: 'org1',
    urlPath: urlPath,
    internalPath: internalPath,
    slug: slug,
    tagId: tagId,
    groupId: 'g1',
    siteId: 'site1',
    measurement: PopulationMeasurement(
      value: quantity,
      unit: MeasurementUnit.count,
    ),
  );
}

Group buildDestinationGroup({
  String id = 'dest-group',
  String slug = 'dest',
  String siteId = 'site2',
  String urlPath = 'organizations/org1/groups/dest',
  String internalPath = 'organizations/org1/groups/dest',
}) {
  return Group.partial(
    id: id,
    slug: slug,
    urlPath: urlPath,
    internalPath: internalPath,
    createdById: 'user1',
    createdAt: _iso,
    updatedAt: _iso,
    updatedById: 'user1',
    organizationId: 'org1',
    name: 'Destination',
    groupTypeId: 'group',
    siteId: siteId,
    parentId: siteId,
  );
}
