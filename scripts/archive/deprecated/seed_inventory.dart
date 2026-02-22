// Seeds sites/groups/corals with a realistic structure (no clearing)
// Usage: dart run scripts/seed_inventory.dart --org=ORG_ID --user=USER_ID [--user2=USER_ID] [--history=true]

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';

Future<void> main(List<String> args) async {
  final params = _parseArgs(args);
  final orgId = params['org'] ?? (throw Exception('--org required'));
  final userId = params['user'] ?? (throw Exception('--user required'));
  final user2Id = params['user2'];
  final generateHistory =
      (params['history'] ?? 'false').toLowerCase() == 'true';

  final exStructures = _parseRangeParam(
    params['ex_structures'],
    const _Range(15, 20),
  );
  final exRacks = _parseRangeParam(params['ex_racks'], const _Range(8, 14));
  final exFragments = _parseRangeParam(
    params['ex_fragments'],
    const _Range(7, 60),
  );
  final exGenets = _parseRangeParam(params['ex_genets'], const _Range(2, 4));

  final inStructures = _parseRangeParam(
    params['in_structures'],
    const _Range(15, 20),
  );
  final inRacks = _parseRangeParam(params['in_racks'], const _Range(3, 6));
  final inFragments = _parseRangeParam(
    params['in_fragments'],
    const _Range(90, 110),
  );

  final geneStructures = _parseRangeParam(
    params['gene_structures'],
    const _Range(6, 10),
  );
  final geneIndividuals = _parseIntParam(params['gene_individuals'], 20);
  final outplantTags = _parseIntParam(params['outplant_tags'], 6);

  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;
  final taxonomyService = TaxonomyService(firestore: db);
  final speciesRegistry = SpeciesRegistry(taxonomyService: taxonomyService);
  SpeciesRegistry.installGlobal(speciesRegistry);
  await SpeciesRegistry.ensureGlobalHydrated();

  final orgSnap = await db
      .collection(ModelType.organization.collectionPath)
      .doc(orgId)
      .get();
  final userSnap = await db
      .collection(ModelType.user.collectionPath)
      .doc(userId)
      .get();
  final organization = RecordFactory.recordFromJson<Organization>(
    orgSnap.data()!,
  );
  final user = RecordFactory.recordFromJson<User>(userSnap.data()!);
  final User? user2 = user2Id == null
      ? null
      : RecordFactory.recordFromJson<User>(
          (await db
                  .collection(ModelType.user.collectionPath)
                  .doc(user2Id)
                  .get())
              .data()!,
        );

  final snapshotService = SnapshotService(firestore: db);
  final recordRepository = RecordRepository(db: db);
  final eventRepo = EventRepository(
    organization: organization,
    user: user,
    firestore: db,
  )..initialize();
  final EventRepository? eventRepo2 = user2 == null
      ? null
      : (EventRepository(organization: organization, user: user2, firestore: db)
          ..initialize());
  final siteRepo = SiteRepository(
    organization: organization,
    user: user,
    eventRepository: eventRepo,
    snapshotService: snapshotService,
    firestore: db,
  )..initialize();
  final groupRepo = GroupRepository(
    organization: organization,
    user: user,
    eventRepository: eventRepo,
    snapshotService: snapshotService,
    firestore: db,
  )..initialize();
  final organismRepo = OrganismRecordRepository(
    organization: organization,
    user: user,
    eventRepository: eventRepo,
    firestore: db,
    organismContext: OrganismContext.forKind(OrganismKind.coral),
  )..initialize();
  final organizationRepo = OrganizationRepository(firestore: db);
  final genetRepo = GenetRepository(
    organization: organization,
    user: user,
    eventRepository: eventRepo,
    snapshotService: snapshotService,
    organizationRepository: organizationRepo,
    firestore: db,
    recordRepository: recordRepository,
  )..initialize();

  // Create genets pool (mix of types incl. sexual recruits)
  final rand = Random(7);
  final speciesList = speciesRegistry.all.take(5).toList();
  if (speciesList.isEmpty) {
    throw StateError(
      'No taxonomy species found. Run the taxonomy seeding script before seeding inventory.',
    );
  }
  final genetPool = <Genet>[];
  for (final sp in speciesList) {
    final n = 10 + rand.nextInt(8); // 10-17 genets per species
    for (var i = 0; i < n; i++) {
      final typeRoll = rand.nextInt(100);
      final typeId = typeRoll < 50
          ? 'genet_type_founder'
          : (typeRoll < 75 ? 'genet_type_cohort' : 'genet_type_sexual_recruit');
      final typeName = typeRoll < 50
          ? 'founder'
          : (typeRoll < 75 ? 'cohort' : 'sexualRecruit');
      final slug = '${sp.code.toLowerCase()}-$typeId-${i + 1}';
      final crossDate = DateTime.now().subtract(
        Duration(days: rand.nextInt(365 * 5)),
      );
      final provenance = <String, String>{
        'reef_of_origin': '${sp.name} Reef ${i + 1}',
        'collection_date': _formatDate(
          crossDate.subtract(const Duration(days: 45)),
        ),
        'depth': (5 + rand.nextInt(18)).toString(),
        'habitat_type': rand.nextBool() ? 'reef_crest' : 'patch_reef',
        'collecting_institution': 'SeaFoundry Research',
        'latitude': (24.0 + rand.nextDouble()).toStringAsFixed(5),
        'longitude': (-80.0 - rand.nextDouble()).toStringAsFixed(5),
        'description': 'Synthetic seed data for demo inventory',
      };
      final damGametes = List.generate(
        2,
        (idx) => 'DAM-${sp.code}-${i + 1}-${idx + 1}',
      );
      final sireGametes = List.generate(
        2,
        (idx) => 'SIRE-${sp.code}-${i + 1}-${idx + 1}',
      );
      final parentGametes = <String>{...damGametes, ...sireGametes}.toList();
      final provenanceTypeId = typeRoll < 50
          ? ProvenanceType.wild.id
          : (typeRoll < 75
              ? ProvenanceType.sexualCohort.id
              : ProvenanceType.graduatedIndividual.id);
      final g = await genetRepo.createGenet(
        Genet.partial(
          name: '${sp.code}-$typeName-${i + 1}'.toUpperCase(),
          speciesId: sp.id,
          provenanceTypeId: provenanceTypeId,
          slug: slug,
          provenanceId: 'seed-${sp.code}-${i + 1}',
          clonalId: 'CLN-${sp.code}-${i + 1}',
          accessionNumber: 'ACC-${sp.code}-${1000 + i}',
          notes: 'Seeded genet ${i + 1} for ${sp.name}.',
          provenance: provenance,
          parentGameteIds: parentGametes,
          parentCohortId: typeId == 'genet_type_cohort'
              ? 'COHORT-${sp.code}-${i % 5 + 1}'
              : null,
          donorGenotypeId: typeId == 'genet_type_sexual_recruit'
              ? 'DONOR-${sp.code}-${i % 4 + 1}'
              : null,
          damGameteIds: damGametes,
          sireGameteIds: sireGametes,
          crossDate: crossDate,
        ),
      );
      genetPool.add(g);
    }
  }

  // Create sites
  final nurseryLand = await siteRepo.createRecord(
    Site.partial(name: 'Nursery Land', siteTypeId: SiteType.nurseryExSitu.id),
    organization,
  );
  final nurseryField = await siteRepo.createRecord(
    Site.partial(name: 'Nursery Field', siteTypeId: SiteType.nurseryInSitu.id),
    organization,
  );
  final geneBank = await siteRepo.createRecord(
    Site.partial(name: 'Gene Bank', siteTypeId: SiteType.geneBank.id),
    organization,
  );
  final outplantSite = await siteRepo.createRecord(
    Site.partial(
      name: 'Outplant Site Alpha',
      siteTypeId: SiteType.outplanting.id,
    ),
    organization,
  );

  // Populate structures with specified distributions
  await _populateExSituSite(
    groupRepo,
    organismRepo,
    genetPool,
    nurseryLand,
    rand,
    structuresRange: exStructures,
    racksPerStructure: exRacks,
    fragmentsPerRack: exFragments,
    genetsPerRack: exGenets,
  );
  await _populateInSituSite(
    groupRepo,
    organismRepo,
    genetPool,
    nurseryField,
    rand,
    structuresRange: inStructures,
    racksPerStructure: inRacks,
    fragmentsPerStructure: inFragments,
  );
  await _populateGeneBank(
    groupRepo,
    organismRepo,
    genetPool,
    geneBank,
    rand,
    structuresRange: geneStructures,
    individualsPerStructure: geneIndividuals,
  );
  await _populateOutplantSite(groupRepo, outplantSite, tagCount: outplantTags);

  // Optional historical activity across both users
  if (generateHistory) {
    await _generateHistoricalActivity(
      eventRepo: eventRepo,
      eventRepo2: eventRepo2,
      organismRepo: organismRepo,
      siteRepo: siteRepo,
      groupRepo: groupRepo,
      rand: rand,
      firestore: db,
      monthsBack: 12,
    );
  }

  siteRepo.dispose();
  groupRepo.dispose();
  organismRepo.dispose();
  eventRepo.dispose();
  eventRepo2?.dispose();
}

Future<void> _populateExSituSite(
  GroupRepository groupRepo,
  OrganismRecordRepository organismRepo,
  List<Genet> genetPool,
  Site site,
  Random rand, {
  _Range structuresRange = const _Range(15, 20),
  required _Range racksPerStructure,
  _Range fragmentsPerRack = const _Range(7, 60),
  _Range genetsPerRack = const _Range(2, 4),
  bool geneBankMode = false,
  int individualsPerStructure = 20,
}) async {
  final structures = structuresRange.pick(rand);
  for (int s = 1; s <= structures; s++) {
    final structure = await groupRepo.createRecord(
      Group.partial(
        name: 'Tank ${s.toString().padLeft(2, '0')}',
        groupTypeId: GroupType.tank.id,
      ),
      site,
    );
    if (geneBankMode) {
      final used = <String>{};
      for (int i = 0; i < individualsPerStructure; i++) {
        Genet g;
        do {
          g = genetPool[rand.nextInt(genetPool.length)];
        } while (used.contains(g.id));
        used.add(g.id);
        await organismRepo.createRecord(
          OrganismRecord.partial(
            slug: '${g.slug}-ind-${i + 1}',
            organismKind: OrganismKind.coral,
            lifeStage: const LifeStageSpec(stage: LifeStage.juvenile),
            measurement: PopulationMeasurement(
              value: 1,
              unit: MeasurementUnit.count,
            ),
            speciesId: g.speciesId,
            provenanceType: ProvenanceType.wild,
            physicalForm: const PhysicalFormInstance(
              formId: 'fragment',
              sizeBandId: 'medium',
            ),
            foreignKeys: {
              'genetId': ForeignKeyReference(id: g.id),
            },
          ),
          structure,
        );
      }
      continue;
    }
    final racks = racksPerStructure.pick(rand);
    for (int r = 1; r <= racks; r++) {
      final rack = await groupRepo.createRecord(
        Group.partial(name: 'Tray $r', groupTypeId: GroupType.tray.id),
        structure,
      );
      await _seedRack(
        organismRepo,
        genetPool,
        rack,
        rand,
        fragmentsPerRack,
        genetsPerRack,
      );
    }
  }
}

Future<void> _populateInSituSite(
  GroupRepository groupRepo,
  OrganismRecordRepository organismRepo,
  List<Genet> genetPool,
  Site site,
  Random rand, {
  _Range structuresRange = const _Range(15, 20),
  required _Range racksPerStructure,
  _Range fragmentsPerStructure = const _Range(90, 110),
}) async {
  final structures = structuresRange.pick(rand);
  for (int s = 1; s <= structures; s++) {
    final isTree = s % 2 == 1;
    final structure = await groupRepo.createRecord(
      Group.partial(
        name: isTree ? 'Tree $s' : 'Dome $s',
        groupTypeId: isTree ? GroupType.tree.id : GroupType.dome.id,
      ),
      site,
    );
    // Single genotype per structure; total ~100 fragments across racks
    final g = genetPool[rand.nextInt(genetPool.length)];
    final racks = racksPerStructure.pick(rand);
    int remaining = fragmentsPerStructure.pick(rand);
    for (int r = 1; r <= racks; r++) {
      final rackType = isTree ? GroupType.treeBranch.id : GroupType.grid.id;
      final rack = await groupRepo.createRecord(
        Group.partial(
          name: isTree ? 'Branch $r' : 'Grid $r',
          groupTypeId: rackType,
        ),
        structure,
      );
      final slotsLeft = racks - r + 1;
      final avg = (remaining / slotsLeft).floor();
      final minQty = max(0, avg - 10);
      final maxQty = avg + 10;
      final qty = slotsLeft == 1
          ? remaining
          : min(maxQty, remaining - (slotsLeft - 1) * minQty);
      final actual = min(max(minQty, qty), remaining);
      if (actual > 0) {
        await organismRepo.createRecord(
          OrganismRecord.partial(
            organismKind: OrganismKind.coral,
            lifeStage: const LifeStageSpec(stage: LifeStage.juvenile),
            measurement: PopulationMeasurement(
              value: actual.toDouble(),
              unit: MeasurementUnit.count,
            ),
            speciesId: g.speciesId,
            provenanceType: ProvenanceType.wild,
            physicalForm: const PhysicalFormInstance(
              formId: 'fragment',
              sizeBandId: 'medium',
            ),
            foreignKeys: {
              'genetId': ForeignKeyReference(id: g.id),
            },
          ),
          rack,
        );
        remaining -= actual;
      }
    }
  }
}

Future<void> _populateGeneBank(
  GroupRepository groupRepo,
  OrganismRecordRepository organismRepo,
  List<Genet> genetPool,
  Site site,
  Random rand, {
  required _Range structuresRange,
  int individualsPerStructure = 20,
}) async {
  await _populateExSituSite(
    groupRepo,
    organismRepo,
    genetPool,
    site,
    rand,
    structuresRange: structuresRange,
    racksPerStructure: const _Range(1, 1),
    geneBankMode: true,
    individualsPerStructure: individualsPerStructure,
  );
}

Future<void> _seedRack(
  OrganismRecordRepository organismRepo,
  List<Genet> genetPool,
  Group rack,
  Random rand,
  _Range fragmentsPerRack,
  _Range genetsPerRack,
) async {
  final nGenets = genetsPerRack.pick(rand);
  final chosenGenets = <Genet>[];
  while (chosenGenets.length < nGenets) {
    final genet = genetPool[rand.nextInt(genetPool.length)];
    if (!chosenGenets.any((candidate) => candidate.id == genet.id)) {
      chosenGenets.add(genet);
    }
  }

  final totalFragments = fragmentsPerRack.pick(rand);
  final base = totalFragments ~/ chosenGenets.length;
  int remainder = totalFragments % chosenGenets.length;

  for (final genet in chosenGenets) {
    final quantity = base + (remainder-- > 0 ? 1 : 0);
    if (quantity <= 0) continue;
    await organismRepo.createRecord(
      OrganismRecord.partial(
        organismKind: OrganismKind.coral,
        lifeStage: const LifeStageSpec(stage: LifeStage.juvenile),
        measurement: PopulationMeasurement(
          value: quantity.toDouble(),
          unit: MeasurementUnit.count,
        ),
        speciesId: genet.speciesId,
        provenanceType: ProvenanceType.wild,
        physicalForm: const PhysicalFormInstance(
          formId: 'fragment',
          sizeBandId: 'medium',
        ),
        foreignKeys: {
          'genetId': ForeignKeyReference(id: genet.id),
        },
      ),
      rack,
    );
  }
}

Future<void> _populateOutplantSite(
  GroupRepository groupRepo,
  Site site, {
  int tagCount = 6,
}) async {
  final zone = await groupRepo.createRecord(
    Group.partial(name: 'Zone A', groupTypeId: GroupType.zone.id),
    site,
  );
  for (int i = 1; i <= tagCount; i++) {
    await groupRepo.createRecord(
      Group.partial(
        name: 'Tag ${i.toString().padLeft(3, '0')}',
        groupTypeId: GroupType.tag.id,
      ),
      zone,
    );
  }
}

Future<void> _generateHistoricalActivity({
  required EventRepository eventRepo,
  EventRepository? eventRepo2,
  required OrganismRecordRepository organismRepo,
  required SiteRepository siteRepo,
  required GroupRepository groupRepo,
  required Random rand,
  required FirebaseFirestore firestore,
  int monthsBack = 12,
}) async {
  DateTime randomPast() {
    final days = rand.nextInt(monthsBack * 30);
    final minutes = rand.nextInt(24 * 60);
    return DateTime.now().subtract(Duration(days: days, minutes: minutes));
  }

  EventRepository repoForIndex(int i) =>
      (i % 2 == 0 || eventRepo2 == null) ? eventRepo : eventRepo2;

  final organisms = await organismRepo.getAll();
  if (organisms.isEmpty) return;

  // **Size changes**: Generate realistic growth progression over time
  // Each organism gets a size change event that properly links to the updated record
  final sampleA =
      organisms.where((o) => o.healthStatus != HealthStatus.deceased).toList()
        ..shuffle(rand);
  for (int i = 0; i < min(50, sampleA.length); i++) {
    final organism = sampleA[i];
    final sizeClasses = ['XS', 'S', 'M', 'L', 'XL'];
    final newSizeClass = sizeClasses[rand.nextInt(sizeClasses.length)];
    final newSize = SizeSpec(sizeClass: newSizeClass);

    // Use repository's update method which generates proper SizeChangeEvent
    // This ensures the event links to the record update and propagates correctly
    final updated = organism.copyWith(sizeSpec: newSize);
    await organismRepo.updateRecord(updated);

    // Note: Size change events are automatically created by the repository
    // Additional activity events below are for parent feed propagation
    final eventId = generateId(firestore: firestore);
    final slug = await eventRepo.nextSlugForModelType(ModelType.event);
    final evt = ActivityEvent(
      id: eventId,
      activityType: 'size_change',
      description: 'Size updated',
      parameters: {'newSize': newSizeClass},
      createdById: repoForIndex(i).user.id,
      createdAt: randomPast().toIso8601String(),
      updatedAt: randomPast().toIso8601String(),
      updatedById: repoForIndex(i).user.id,
      organizationId: organism.organizationId,
      recordId: organism.id,
      recordModelType: organism.modelType,
      urlPath: '${organism.urlPath}/$slug',
      internalPath: '${organism.internalPath}/$eventId',
      slug: slug,
    );
    await repoForIndex(i).createEvent(evt);
  }

  // **Status changes**: Track readiness flags for fragging and outplanting
  // These simulate realistic workflow progression
  final sampleB =
      organisms.where((o) => o.healthStatus != HealthStatus.deceased).toList()
        ..shuffle(rand);
  for (int i = 0; i < min(40, sampleB.length); i++) {
    final organism = sampleB[i];
    final readyType = (i % 2 == 0)
        ? 'ready_for_fragging'
        : 'ready_for_outplant';
    final eventId = generateId(firestore: firestore);
    final slug = await eventRepo.nextSlugForModelType(ModelType.event);
    final evt = ActivityEvent(
      id: eventId,
      activityType: 'status_change',
      description: 'Status updated',
      parameters: {readyType: true},
      createdById: repoForIndex(i).user.id,
      createdAt: randomPast().toIso8601String(),
      updatedAt: randomPast().toIso8601String(),
      updatedById: repoForIndex(i).user.id,
      organizationId: organism.organizationId,
      recordId: organism.id,
      recordModelType: organism.modelType,
      urlPath: '${organism.urlPath}/$slug',
      internalPath: '${organism.internalPath}/$eventId',
      slug: slug,
    );
    await repoForIndex(i).createEvent(evt);
  }

  // **Observations**: Generate routine health checks
  // These use the proper observation event creation method
  final sampleC =
      organisms.where((o) => o.healthStatus != HealthStatus.deceased).toList()
        ..shuffle(rand);
  for (int i = 0; i < min(30, sampleC.length); i++) {
    final organism = sampleC[i];
    await repoForIndex(i).createObservationEvent(
      forRecord: organism,
      comment: 'Routine check OK',
      createdAt: randomPast(),
    );
  }

  // **Moves**: Generate realistic nursery reorganization over time
  // Note: moveRecord() automatically creates MoveInEvent and MoveOutEvent
  // The additional ActivityEvent below is for parent feed visibility
  final groups = await groupRepo.getAll();
  final racks = groups
      .where(
        (g) =>
            g.groupTypeId == GroupType.tray.id ||
            g.groupTypeId == GroupType.treeBranch.id ||
            g.groupTypeId == GroupType.grid.id,
      )
      .toList();
  final movable = organisms.toList()..shuffle(rand);
  for (int i = 0; i < min(25, movable.length); i++) {
    final organism = movable[i];
    final fromParentPath = organism.urlPath.substring(
      0,
      organism.urlPath.lastIndexOf('/'),
    );
    final fromParent = groups.firstWhere(
      (g) => g.urlPath == fromParentPath,
      orElse: () => groups.first,
    );
    final toParent = racks[rand.nextInt(racks.length)];
    if (toParent.id == fromParent.id) continue;

    // Use repository moveRecord which creates proper MoveIn/MoveOut events
    await FirebaseFirestore.instance.runTransaction((tx) async {
      await organismRepo.moveRecord(
        record: organism,
        fromParent: fromParent,
        toParent: toParent,
        transaction: tx,
      );
    });

    // Optional: Create activity event for parent group visibility
    // This propagates to parent activity feeds (tanks, sites)
    final eventId = generateId(firestore: firestore);
    final slug = await eventRepo.nextSlugForModelType(ModelType.event);
    final evt = ActivityEvent(
      id: eventId,
      activityType: 'moved',
      description: 'Relocated within nursery',
      parameters: {'to': toParent.name},
      createdById: repoForIndex(i).user.id,
      createdAt: randomPast().toIso8601String(),
      updatedAt: randomPast().toIso8601String(),
      updatedById: repoForIndex(i).user.id,
      organizationId: organism.organizationId,
      recordId: organism.id,
      recordModelType: organism.modelType,
      urlPath: '${organism.urlPath}/$slug',
      internalPath: '${organism.internalPath}/$eventId',
      slug: slug,
    );
    await repoForIndex(i).createEvent(evt);
  }
}

class _Range {
  final int min;
  final int max;
  const _Range(this.min, this.max);
  int pick(Random r) => min + r.nextInt(max - min + 1);
}

_Range _parseRangeParam(String? raw, _Range fallback) {
  if (raw == null || raw.trim().isEmpty) return fallback;
  final parts = raw.split('-').map((part) => part.trim()).toList();
  if (parts.isEmpty) return fallback;
  final start = int.tryParse(parts.first);
  final end = parts.length > 1 ? int.tryParse(parts.last) : start;
  if (start == null) return fallback;
  if (end == null) return _Range(start, start);
  final min = start <= end ? start : end;
  final max = start <= end ? end : start;
  return _Range(min, max);
}

int _parseIntParam(String? raw, int fallback) {
  if (raw == null || raw.trim().isEmpty) return fallback;
  final value = int.tryParse(raw.trim());
  return value ?? fallback;
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (final a in args) {
    final parts = a.split('=');
    if (parts.length == 2) {
      final key = parts[0].replaceFirst('--', '');
      map[key] = parts[1];
    }
  }
  return map;
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
