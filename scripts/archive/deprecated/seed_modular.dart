// Modular seeding script that supports targeted operations.
// Usage example:
//   dart run scripts/seed_modular.dart --org=ORG_ID --user=ADMIN_ID \
//       --delete=true --seed_land=true --seed_outplant=true

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
// import 'package:seafoundry_app/repositories/graph_repository.dart'; // Unused
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/monitoring_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';

Future<void> main(List<String> args) async {
  final params = _parseArgs(args);
  final orgId = params['org'] ?? (throw Exception('--org required'));
  final userId = params['user'] ?? (throw Exception('--user required'));

  final deleteData = _parseBoolParam(params, 'delete');
  final seedLandNurseries = _parseBoolParam(params, 'seed_land');
  final seedFieldNurseries = _parseBoolParam(params, 'seed_field');
  final seedGeneBanks = _parseBoolParam(params, 'seed_gene');
  final seedOutplanting = _parseBoolParam(params, 'seed_outplant');
  final seedMonitoring = _parseBoolParam(params, 'seed_monitoring');
  final seedHistory = _parseBoolParam(params, 'seed_history');

  final outplantCount = _parseIntParam(params['outplant_count'], 4);
  final outplantAllocations = _parseIntParam(params['outplant_allocations'], 3);
  final monitoringCount = _parseIntParam(params['monitoring_count'], 3);

  final hasOperations =
      deleteData ||
      seedLandNurseries ||
      seedFieldNurseries ||
      seedGeneBanks ||
      seedOutplanting ||
      seedMonitoring ||
      seedHistory;

  if (!hasOperations) {
    // If no operations requested, exit early to avoid running the full reset.
    // This keeps the script idempotent for UI usage where options are explicit.
    stdout.writeln(
      'No operations requested. Use --delete=true, --seed_land=true, etc. to trigger work.',
    );
    return;
  }

  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;
  final taxonomyService = TaxonomyService(firestore: db);
  final speciesRegistry = SpeciesRegistry(taxonomyService: taxonomyService);
  SpeciesRegistry.installGlobal(speciesRegistry);
  await SpeciesRegistry.ensureGlobalHydrated();
  await TaxonomyConfigSync.sync(
    firestore: db,
    updatedBy: userId,
  );
  final seedSpecies = speciesRegistry.all.take(5).toList();
  if (seedSpecies.isEmpty) {
    throw StateError(
      'No taxonomy species found. Seed taxonomy collections before running seed_modular.',
    );
  }

  // final recordRepo = RecordRepository.instance; // Unused
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

  final snapshotService = SnapshotService(firestore: db);
  final eventRepo = EventRepository(
    organization: organization,
    user: user,
    firestore: db,
  )..initialize();
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
  final recordRepo = RecordRepository(db: db);
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
    recordRepository: recordRepo,
    firestore: db,
  )..initialize();

  // final graphRepo = GraphRepository(
  //   eventRepository: eventRepo,
  //   siteRepository: siteRepo,
  //   groupRepository: groupRepo,
  //   coralRepository: coralRepo,
  //   genetRepository: genetRepo,
  // ); // Unused

  final rand = Random(7);
  final exStructures = _parseRangeParam(
    params['ex_structures'],
    const _Range(10, 15),
  );
  final exRacks = _parseRangeParam(params['ex_racks'], const _Range(10, 15));
  final exFragments = _parseRangeParam(
    params['ex_fragments'],
    const _Range(20, 60),
  );
  final exGenets = _parseRangeParam(params['ex_genets'], const _Range(3, 5));
  final inStructures = _parseRangeParam(
    params['in_structures'],
    const _Range(10, 15),
  );
  final inRacks = _parseRangeParam(params['in_racks'], const _Range(10, 15));
  final inFragments = _parseRangeParam(
    params['in_fragments'],
    const _Range(20, 60),
  );
  // final inGenets = _parseRangeParam(params['in_genets'], const _Range(3, 5)); // Unused
  final geneStructures = _parseRangeParam(
    params['gene_structures'],
    const _Range(8, 12),
  );
  final geneIndividuals = _parseIntParam(params['gene_individuals'], 20);
  final outplantTags = _parseIntParam(params['outplant_tags'], 6);

  try {
    if (deleteData) {
      await _clearOrganizationData(
        siteRepo: siteRepo,
        groupRepo: groupRepo,
        organismRepo: organismRepo,
        organization: organization,
      );
    }

    final existingSites = await siteRepo.streamAll.first;

    List<Genet> genetPool = const [];
    if (seedLandNurseries ||
        seedFieldNurseries ||
        seedGeneBanks ||
        seedOutplanting ||
        seedMonitoring ||
        seedHistory) {
      genetPool = await _seedGenetPool(
        genetRepo: genetRepo,
        rand: rand,
        speciesSeed: seedSpecies,
      );
    }

    Future<Site> ensureSite(String name, SiteType type) => _ensureSite(
      existingSites: existingSites,
      siteRepo: siteRepo,
      organization: organization,
      siteName: name,
      siteType: type,
    );

    if (seedLandNurseries) {
      final site = await ensureSite('Nursery Land', SiteType.nursery);
      await _populateExSituSite(
        groupRepo,
        organismRepo,
        genetPool,
        site,
        rand,
        structuresRange: exStructures,
        racksPerStructure: exRacks,
        fragmentsPerRack: exFragments,
        genetsPerRack: exGenets,
      );
    }

    if (seedFieldNurseries) {
      final site = await ensureSite('Nursery Field', SiteType.nursery);
      await _populateInSituSite(
        groupRepo,
        organismRepo,
        genetPool,
        site,
        rand,
        structuresRange: inStructures,
        racksPerStructure: inRacks,
        fragmentsPerStructure: inFragments,
      );
    }

    if (seedGeneBanks) {
      final site = await ensureSite('Gene Bank', SiteType.geneBank);
      await _populateGeneBank(
        groupRepo,
        organismRepo,
        genetPool,
        site,
        rand,
        structuresRange: geneStructures,
        individualsPerStructure: geneIndividuals,
      );
    }

    Site? outplantSite;
    List<_MonitoringSeedContext> monitoringSites = const [];
    if (seedMonitoring) {
      monitoringSites = await _seedMonitoringSites(
        ensureSite: ensureSite,
        groupRepo: groupRepo,
        organismRepo: organismRepo,
        speciesSeed: seedSpecies,
        rand: rand,
      );
    }

    if (seedOutplanting || seedMonitoring) {
      outplantSite = await ensureSite(
        'Outplant Site Alpha',
        SiteType.outplanting,
      );
      await _populateOutplantSite(
        groupRepo,
        outplantSite,
        tagCount: outplantTags,
      );
    }

    if (seedOutplanting && outplantSite != null) {
      await _seedOutplantEvents(
        eventRepo: eventRepo,
        organismRepo: organismRepo,
        outplantSite: outplantSite,
        rand: rand,
        eventCount: outplantCount,
        allocationsPerEvent: outplantAllocations,
      );
    }

    if (seedMonitoring) {
      final monitoringRepo = MonitoringRepository(
        organization: organization,
        user: user,
        firestore: db,
      );
      var contexts = monitoringSites;
      if (contexts.isEmpty && outplantSite != null) {
        final allOrganisms = await organismRepo.getAll();
        contexts = [
          _MonitoringSeedContext(
            site: outplantSite,
            organisms: allOrganisms
                .where((o) => o.siteId == outplantSite!.id)
                .toList(),
          ),
        ];
      }

      for (final context in contexts) {
        await _seedMonitoringEvents(
          monitoringRepo: monitoringRepo,
          organismRepo: organismRepo,
          site: context.site,
          organisms: context.organisms,
          rand: rand,
          eventCount: monitoringCount,
        );
      }
    }

    if (seedHistory) {
      await _generateHistoricalActivity(
        eventRepo: eventRepo,
        eventRepo2: null,
        organismRepo: organismRepo,
        siteRepo: siteRepo,
        groupRepo: groupRepo,
        rand: rand,
        monthsBack: 12,
        firestore: db,
      );
    }
  } finally {
    // graphRepo.dispose(); // GraphRepository doesn't have dispose method
    siteRepo.dispose();
    groupRepo.dispose();
    organismRepo.dispose();
    eventRepo.dispose();
    genetRepo.dispose();
  }
}

/// Loads the CRC/HOG crosswalk data from crc_db/pid_crosswalk.json.
/// Returns a map of speciesCode -> list of crosswalk entries.
Map<String, List<Map<String, dynamic>>> _loadCrosswalkData() {
  final crosswalkBySpecies = <String, List<Map<String, dynamic>>>{};
  try {
    final file = File('crc_db/pid_crosswalk.json');
    if (!file.existsSync()) return crosswalkBySpecies;
    final jsonStr = file.readAsStringSync();
    final entries = json.decode(jsonStr) as List<dynamic>;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final code = entry['speciesCode']?.toString() ?? '';
      if (code.isEmpty) continue;
      crosswalkBySpecies.putIfAbsent(code, () => []).add(entry);
    }
  } catch (e) {
    stdout.writeln('Warning: Could not load crosswalk data: $e');
  }
  return crosswalkBySpecies;
}

/// Converts crosswalk alias entries to Genet-compatible alias maps.
List<Map<String, dynamic>> _crosswalkToAliases(
  Map<String, dynamic> crosswalkEntry,
) {
  final aliases = <Map<String, dynamic>>[];
  final rawAliases = crosswalkEntry['aliases'];
  if (rawAliases is List) {
    for (final alias in rawAliases) {
      if (alias is! Map) continue;
      final id = alias['id']?.toString() ?? '';
      final org = alias['org']?.toString() ?? 'unknown';
      if (id.isEmpty) continue;
      // Use value only (no separate label) to avoid duplication
      // in ProvenanceRecord._parseAliasLabels which reads both label+value
      aliases.add({
        'sourceSystem': org,
        'value': id,
      });
    }
  }
  return aliases;
}

Future<List<Genet>> _seedGenetPool({
  required GenetRepository genetRepo,
  required Random rand,
  required List<Species> speciesSeed,
}) async {
  final crosswalkBySpecies = _loadCrosswalkData();
  final usedCrosswalkIndices = <String, int>{};

  final genetPool = <Genet>[];
  for (final sp in speciesSeed) {
    final n = 10 + rand.nextInt(8);
    final crosswalkEntries = crosswalkBySpecies[sp.code] ?? const [];
    usedCrosswalkIndices[sp.code] = 0;

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
        Duration(days: rand.nextInt(365 * 6)),
      );
      final provenance = <String, String>{
        'reefOfOrigin': '${sp.name} Reef ${i + 1}',
        'collectionDate': _formatDate(
          crossDate.subtract(const Duration(days: 60)),
        ),
        'depth': (6 + rand.nextInt(15)).toString(),
        'habitatType': rand.nextBool() ? 'patch_reef' : 'reef_crest',
        'collectingInstitution': 'SeaFoundry Research',
        'latitude': (24.0 + rand.nextDouble()).toStringAsFixed(5),
        'longitude': (-80.0 - rand.nextDouble()).toStringAsFixed(5),
        'description': 'Seeded inventory specimen',
      };
      final damGametes = List.generate(
        2,
        (idx) => 'DAM-${sp.code}-${i + 1}-${idx + 1}',
      );
      final sireGametes = List.generate(
        2,
        (idx) => 'SIRE-${sp.code}-${i + 1}-${idx + 1}',
      );
      final provenanceTypeId = typeRoll < 50
          ? ProvenanceType.wild.id
          : (typeRoll < 75
              ? ProvenanceType.cohort.id
              : ProvenanceType.graduatedIndividual.id);

      // For ACER and APAL, assign crosswalk data to 50% of genets
      // (even-indexed genets get crosswalk associations)
      final useCrosswalk = crosswalkEntries.isNotEmpty &&
          (sp.code == 'ACER' || sp.code == 'APAL') &&
          i % 2 == 0;

      String provenanceId;
      String clonalId;
      String accessionNumber;
      List<Map<String, dynamic>>? aliases;

      if (useCrosswalk) {
        final cwIndex = usedCrosswalkIndices[sp.code]!;
        final entry = crosswalkEntries[cwIndex % crosswalkEntries.length];
        usedCrosswalkIndices[sp.code] = cwIndex + 1;

        provenanceId = entry['provenanceId']?.toString() ?? 'PID-${sp.code}-${(i + 1).toString().padLeft(4, '0')}';
        clonalId = entry['masterClonalId']?.toString() ?? 'CLN-${sp.code}-${i + 1}';
        accessionNumber = entry['accessionNumber']?.toString() ?? 'ACC-${sp.code}-${2000 + i}';
        aliases = _crosswalkToAliases(entry);
        stdout.writeln(
          '  [crosswalk] ${sp.code} genet ${i + 1}: PID=$provenanceId, clonalId=$clonalId, aliases=${aliases.length}',
        );
      } else {
        provenanceId = 'seed-${sp.code}-${i + 1}';
        clonalId = 'CLN-${sp.code}-${i + 1}';
        accessionNumber = 'ACC-${sp.code}-${2000 + i}';
        aliases = null;
      }

      final genet = await genetRepo.createGenet(
        Genet.partial(
          name: '${sp.code}-$typeName-${i + 1}'.toUpperCase(),
          speciesId: sp.id,
          provenanceTypeId: provenanceTypeId,
          slug: slug,
          provenanceId: provenanceId,
          clonalId: clonalId,
          accessionNumber: accessionNumber,
          aliases: aliases,
          notes: useCrosswalk
              ? 'CRC/HOG crosswalk genet (PID: $provenanceId)'
              : 'Seeded genet ${i + 1} for demo reset.',
          provenance: provenance,
          parentGameteIds: <String>{...damGametes, ...sireGametes}.toList(),
          parentCohortId: typeId == 'genet_type_cohort'
              ? 'COHORT-${sp.code}-${i % 4 + 1}'
              : null,
          donorGenotypeId: typeId == 'genet_type_sexual_recruit'
              ? 'DONOR-${sp.code}-${i % 3 + 1}'
              : null,
          damGameteIds: damGametes,
          sireGameteIds: sireGametes,
          crossDate: crossDate,
        ),
      );
      genetPool.add(genet);
    }
  }
  return genetPool;
}

Future<void> _clearOrganizationData({
  required SiteRepository siteRepo,
  required GroupRepository groupRepo,
  required OrganismRecordRepository organismRepo,
  required Organization organization,
}) async {
  final sites = await siteRepo.streamAll.first;
  for (final site in sites) {
    await _deleteGroupTree(siteRepo, groupRepo, organismRepo, site);
    await siteRepo.deleteRecord(site);
  }
}

Future<Site> _ensureSite({
  required List<Site> existingSites,
  required SiteRepository siteRepo,
  required Organization organization,
  required String siteName,
  required SiteType siteType,
}) async {
  final existing = existingSites.firstWhereOrNull(
    (site) => site.name == siteName,
  );
  if (existing != null) {
    return existing;
  }
  final created = await siteRepo.createRecord(
    Site.partial(name: siteName, siteTypeId: siteType.id),
    organization,
  );
  existingSites.add(created);
  return created;
}

Future<void> _deleteGroupTree(
  SiteRepository siteRepo,
  GroupRepository groupRepo,
  OrganismRecordRepository organismRepo,
  Site site,
) async {
  Future<void> deleteGroupAndChildren(Group group) async {
    final childGroups = await groupRepo.getRecordsForUrlPath(
      group.urlPath,
      shallow: true,
    );
    final organisms = await organismRepo.getRecordsForUrlPath(
      group.urlPath,
      shallow: true,
    );
    for (final o in organisms) {
      await organismRepo.deleteRecord(o);
    }
    for (final g in childGroups) {
      await deleteGroupAndChildren(g);
      await groupRepo.deleteRecord(g);
    }
  }

  final topGroups = await groupRepo.getRecordsForUrlPath(
    site.urlPath,
    shallow: true,
  );
  for (final g in topGroups) {
    await deleteGroupAndChildren(g);
    await groupRepo.deleteRecord(g);
  }
}

Future<void> _populateExSituSite(
  GroupRepository groupRepo,
  OrganismRecordRepository organismRepo,
  List<Genet> genetPool,
  Site site,
  Random rand, {
  _Range structuresRange = const _Range(10, 15),
  required _Range racksPerStructure,
  _Range fragmentsPerRack = const _Range(20, 60),
  _Range genetsPerRack = const _Range(3, 5),
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
        final provenanceType = _provenanceForGenet(g);
        await organismRepo.createRecord(
          OrganismRecord.partial(
            slug: '${g.slug}-ind-${i + 1}',
            organismKind: OrganismKind.coral,
            lifeStage: _lifeStageSpecFor(provenanceType),
            measurement: PopulationMeasurement(
              value: 1,
              unit: MeasurementUnit.count,
            ),
            speciesId: g.speciesId,
            provenanceType: provenanceType,
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
  _Range structuresRange = const _Range(10, 15),
  required _Range racksPerStructure,
  _Range fragmentsPerStructure = const _Range(20, 60),
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
    final genet = genetPool[rand.nextInt(genetPool.length)];
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
        final provenanceType = _provenanceForGenet(genet);
        await organismRepo.createRecord(
          OrganismRecord.partial(
            organismKind: OrganismKind.coral,
            lifeStage: _lifeStageSpecFor(provenanceType),
            measurement: PopulationMeasurement(
              value: actual.toDouble(),
              unit: MeasurementUnit.count,
            ),
            speciesId: genet.speciesId,
            provenanceType: provenanceType,
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
    fragmentsPerRack: const _Range(15, 30),
    genetsPerRack: const _Range(1, 3),
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
    final provenanceType = _provenanceForGenet(genet);
    await organismRepo.createRecord(
      OrganismRecord.partial(
        organismKind: OrganismKind.coral,
        lifeStage: _lifeStageSpecFor(provenanceType),
        measurement: PopulationMeasurement(
          value: quantity.toDouble(),
          unit: MeasurementUnit.count,
        ),
        speciesId: genet.speciesId,
        provenanceType: provenanceType,
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

Future<void> _seedOutplantEvents({
  required EventRepository eventRepo,
  required OrganismRecordRepository organismRepo,
  required Site outplantSite,
  required Random rand,
  int eventCount = 4,
  int allocationsPerEvent = 3,
}) async {
  final organisms = await organismRepo.getAll();
  if (organisms.isEmpty || eventCount <= 0 || allocationsPerEvent <= 0) return;

  for (int i = 0; i < eventCount; i++) {
    organisms.shuffle(rand);
    final selected = organisms.take(allocationsPerEvent).toList();
    final allocations = <OutplantAllocation>[];
    for (final organism in selected) {
      final maxQty = organism.measurement.value.toInt();
      final qty = max(1, rand.nextInt(max(1, maxQty)) + 1);
      allocations.add(
        OutplantAllocation(
          organismId: organism.id,
          recordName: organism.localId ?? 'Organism',
          speciesId: organism.speciesId ?? '',
          genetId: organism.genetId ?? '',
          quantity: qty,
          sourcePath: organism.urlPath,
          snapshot: organism.toJson(),
          tagId: null,
          tagName: null,
          tagPath: null,
        ),
      );
    }

    if (allocations.isEmpty) continue;

    final baseName = 'Outplant Event ${i + 1}';
    final uniqueName = await eventRepo.ensureUniqueOutplantName(baseName);
    await eventRepo.createOutplantEvent(
      name: uniqueName,
      site: outplantSite,
      allocations: allocations,
      percentCover: rand.nextDouble() * 100,
      percentBleaching: rand.nextDouble() * 20,
      percentDisease: rand.nextDouble() * 10,
      healthStatus: rand.nextBool() ? 'healthy' : 'mixed',
      comment: 'Seeded outplant event ${i + 1}',
    );
  }
}

Future<List<_MonitoringSeedContext>> _seedMonitoringSites({
  required Future<Site> Function(String name, SiteType type) ensureSite,
  required GroupRepository groupRepo,
  required OrganismRecordRepository organismRepo,
  required List<Species> speciesSeed,
  required Random rand,
}) async {
  final results = <_MonitoringSeedContext>[];
  final configs = [
    ('Baseline Reef', SiteType.baselineSite),
    ('Reference Reef', SiteType.referenceSite),
  ];

  for (final config in configs) {
    final site = await ensureSite(config.$1, config.$2);
    final groups = <Group>[];
    for (int i = 1; i <= 2; i++) {
      groups.add(
        await groupRepo.createRecord(
          Group.partial(
            name: 'Transect ${i.toString().padLeft(2, '0')}',
            groupTypeId: GroupType.plotTransect.id,
          ),
          site,
        ),
      );
    }

    final organisms = <OrganismRecord>[];
    final organismCount = 5 + rand.nextInt(4); // 5-8 per monitoring site
    for (int i = 0; i < organismCount; i++) {
      final species = speciesSeed[rand.nextInt(speciesSeed.length)];
      final formId = rand.nextBool() ? 'colony' : 'fragment';
      final sizeBand = ['small', 'medium', 'large'][rand.nextInt(3)];
      final organism = await organismRepo.createRecord(
        OrganismRecord.partial(
          organismKind: OrganismKind.coral,
          speciesId: species.id,
          slug:
              '${species.code.toLowerCase()}-${config.$1.toLowerCase().replaceAll(' ', '-')}-${i + 1}',
          measurement: PopulationMeasurement(
            value: 1,
            unit: MeasurementUnit.count,
          ),
          lifeStage: const LifeStageSpec(stage: LifeStage.adult),
          provenanceType: ProvenanceType.wild,
          physicalForm: PhysicalFormInstance(
            formId: formId,
            sizeBandId: sizeBand,
          ),
          sizeSpec: SizeSpec(sizeClass: sizeBand),
          metadata: {
            'healthStatus': HealthStatus.healthy.id,
          },
        ),
        groups[i % groups.length],
      );
      organisms.add(organism);
    }

    results.add(_MonitoringSeedContext(site: site, organisms: organisms));
  }

  return results;
}

Future<void> _seedMonitoringEvents({
  required MonitoringRepository monitoringRepo,
  required OrganismRecordRepository organismRepo,
  required Site site,
  required Random rand,
  int eventCount = 3,
  List<OrganismRecord>? organisms,
}) async {
  final allOrganisms = organisms ?? await organismRepo.getAll();
  final siteOrganisms =
      allOrganisms.where((record) => record.siteId == site.id).toList();
  if (siteOrganisms.isEmpty || eventCount <= 0) return;

  for (int i = 0; i < eventCount; i++) {
    siteOrganisms.shuffle(rand);
    final selected = siteOrganisms.take(min(6, siteOrganisms.length)).toList();
    final entries = <MonitoringEntry>[];
    const morphologyOptions = [
      'branching',
      'massive',
      'plating',
      'encrusting',
      'columnar',
      'digitate',
      'foliose',
      'submassive',
      'laminar',
      'bushy',
      'mounding',
      'other',
    ];
    for (final organism in selected) {
      final morphology = morphologyOptions[rand.nextInt(morphologyOptions.length)];
      final tagId = 'TAG-${organism.slug.toUpperCase()}';
      final genetId = organism.genetId ?? '';
      entries.add(
        MonitoringEntry(
          genetId: genetId,
          tagId: tagId,
          morphology: morphology,
          notes: rand.nextBool() ? 'Seeded monitoring note' : null,
          healthStatus: rand.nextBool() ? 'healthy' : 'stressed',
          percentCover: 50 + rand.nextDouble() * 50,
          percentBleaching: rand.nextDouble() * 20,
          percentDisease: rand.nextDouble() * 10,
          measurements: {
            'organismId': organism.id,
            'physicalFormId': organism.physicalForm?.formId ?? 'fragment',
            'sizeClass': organism.sizeSpec.sizeClass ?? 'M',
            'coralCount': max(1, organism.measurement.value.toInt()),
            'estimatedVolumeMm3': 1000 + rand.nextDouble() * 5000,
            'tagId': tagId,
            'morphology': morphology,
          },
        ),
      );
    }

    if (entries.isEmpty) continue;

    await monitoringRepo.createMonitoringEvent(
      siteId: site.id,
      siteName: site.name,
      percentCover: rand.nextDouble() * 100,
      percentBleaching: rand.nextDouble() * 30,
      percentDisease: rand.nextDouble() * 15,
      healthStatus: rand.nextBool() ? 'healthy' : 'mixed',
      notes: 'Seeded monitoring event ${i + 1}',
      entries: entries,
      createdAt: DateTime.now().subtract(Duration(days: rand.nextInt(120))),
      forRecord: site,
    );
  }
}

class _MonitoringSeedContext {
  _MonitoringSeedContext({required this.site, required this.organisms});

  final Site site;
  final List<OrganismRecord> organisms;
}

ProvenanceType _provenanceForGenet(Genet genet) {
  final parsed = ProvenanceTypeX.tryParse(genet.provenanceTypeId);
  return parsed ?? ProvenanceType.wild;
}

LifeStageSpec _lifeStageSpecFor(ProvenanceType provenanceType) =>
    LifeStageSpec(stage: provenanceType.defaultLifeStage);

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
    final fromParent = groups.firstWhereOrNull(
      (g) => g.urlPath == fromParentPath,
    );
    final toParent = racks[rand.nextInt(racks.length)];
    if (fromParent == null || toParent.id == fromParent.id) continue;

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

_Range _parseRangeParam(String? raw, _Range fallback) {
  if (raw == null || raw.trim().isEmpty) return fallback;
  final parts = raw.split('-').map((part) => part.trim()).toList();
  if (parts.isEmpty) return fallback;
  final start = int.tryParse(parts.first);
  final end = parts.length > 1 ? int.tryParse(parts.last) : start;
  if (start == null) return fallback;
  if (end == null) return _Range(start, start);
  final minVal = start <= end ? start : end;
  final maxVal = start <= end ? end : start;
  return _Range(minVal, maxVal);
}

int _parseIntParam(String? raw, int fallback) {
  if (raw == null || raw.trim().isEmpty) return fallback;
  final value = int.tryParse(raw.trim());
  return value ?? fallback;
}

bool _parseBoolParam(Map<String, String> params, String key) {
  final raw = params[key];
  if (raw == null) return false;
  final normalized = raw.toLowerCase().trim();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
