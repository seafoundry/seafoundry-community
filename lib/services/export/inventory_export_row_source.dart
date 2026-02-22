// @tier: community
import 'package:collection/collection.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/holding_record.dart';
import 'package:seafoundry_app/models/inventory/inventory_export_row.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/gamete_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seeded_line_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/crab_pond_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seagrass_module_repository.dart';
import 'package:seafoundry_app/repositories/inventory/mangrove_plot_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/archived_organism_record_repository.dart';
import 'package:seafoundry_app/services/export/inventory_holding_row_builder.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';

/// Builds canonical inventory export rows (coral + organism holdings) so both
/// workspace UX and API flows can share a single source of truth.
class InventoryExportRowSource {
  InventoryExportRowSource({
    required OrganismRecordRepository organismRecordRepository,
    ArchivedOrganismRecordRepository? archivedOrganismRecordRepository,
    required GroupRepository groupRepository,
    GenetRepository? genetRepository,
    OrganismHoldingLoader? holdingLoader,
    Map<OrganismKind, SeededLineRepository> seededLineRepositories = const {},
    Map<OrganismKind, OysterBagRepository> oysterBagRepositories = const {},
    Map<OrganismKind, GameteBatchRepository> gameteBatchRepositories = const {},
    Map<OrganismKind, LarvalBatchRepository> larvalBatchRepositories = const {},
    Map<OrganismKind, FinfishPenRepository> finfishPenRepositories = const {},
    Map<OrganismKind, CrabPondRepository> crabPondRepositories = const {},
    Map<OrganismKind, SeagrassModuleRepository> seagrassModuleRepositories =
        const {},
    Map<OrganismKind, MangrovePlotRepository> mangrovePlotRepositories =
        const {},
  })  : _organismRecordRepository = organismRecordRepository,
       _archivedOrganismRecordRepository = archivedOrganismRecordRepository,
       _groupRepository = groupRepository,
       _genetRepository = genetRepository,
       _holdingLoader = holdingLoader,
       _seededLineRepositories = seededLineRepositories,
       _oysterBagRepositories = oysterBagRepositories,
       _gameteBatchRepositories = gameteBatchRepositories,
       _larvalBatchRepositories = larvalBatchRepositories,
       _finfishPenRepositories = finfishPenRepositories,
       _crabPondRepositories = crabPondRepositories,
       _seagrassModuleRepositories = seagrassModuleRepositories,
       _mangrovePlotRepositories = mangrovePlotRepositories;

  final OrganismRecordRepository _organismRecordRepository;
  final ArchivedOrganismRecordRepository? _archivedOrganismRecordRepository;
  final GroupRepository _groupRepository;
  final GenetRepository? _genetRepository;
  final OrganismHoldingLoader? _holdingLoader;
  final Map<OrganismKind, SeededLineRepository> _seededLineRepositories;
  final Map<OrganismKind, OysterBagRepository> _oysterBagRepositories;
  final Map<OrganismKind, GameteBatchRepository> _gameteBatchRepositories;
  final Map<OrganismKind, LarvalBatchRepository> _larvalBatchRepositories;
  final Map<OrganismKind, FinfishPenRepository> _finfishPenRepositories;
  final Map<OrganismKind, CrabPondRepository> _crabPondRepositories;
  final Map<OrganismKind, SeagrassModuleRepository>
  _seagrassModuleRepositories;
  final Map<OrganismKind, MangrovePlotRepository> _mangrovePlotRepositories;

  Future<List<InventoryExportRow>> loadRows({
    OrganismKind? organismFilter,
    bool includeArchived = false,
  }) async {
    final rows = <InventoryExportRow>[];
    final groups = await _groupRepository.getAll();
    final groupById = {for (final group in groups) group.id: group};

    if (organismFilter == null || organismFilter == OrganismKind.coral) {
      rows.addAll(await _buildCoralRows(groupById, includeArchived: includeArchived));
    }

    final shouldIncludeHoldings =
        organismFilter == null || organismFilter != OrganismKind.coral;
    if (shouldIncludeHoldings) {
      rows.addAll(
        await _buildHoldingRows(
          groupById: groupById,
          organismFilter: organismFilter,
        ),
      );
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> loadRowMaps({
    OrganismKind? organismFilter,
    bool includeArchived = false,
  }) async {
    final rows = await loadRows(organismFilter: organismFilter, includeArchived: includeArchived);
    return rows.map((row) => row.toMap()).toList(growable: false);
  }

  Stream<List<Map<String, dynamic>>> chunkedRowMaps({
    OrganismKind? organismFilter,
    int chunkSize = 500,
  }) async* {
    final rows = await loadRows(organismFilter: organismFilter);
    for (var i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows
          .skip(i)
          .take(chunkSize)
          .map((row) => row.toMap())
          .toList(growable: false);
      yield chunk;
    }
  }

  Future<List<InventoryExportRow>> _buildCoralRows(
    Map<String, Group> groupById, {
    bool includeArchived = false,
  }) async {
    final rows = <InventoryExportRow>[];

    // Get OrganismRecord coral rows
    final organismRecords = await _organismRecordRepository.getAll();
    final archivedRecords = includeArchived
        ? await _archivedOrganismRecordRepository?.getAll() ?? const <OrganismRecord>[]
        : const <OrganismRecord>[];
    final allRecords = <OrganismRecord>[
      ...organismRecords,
      ...archivedRecords,
    ];
    final dedupedById = <String, OrganismRecord>{
      for (final record in allRecords) record.id: record,
    };
    final coralOrganisms = dedupedById.values
        .where((record) => record.organismKind == OrganismKind.coral)
        .toList();

    // Bulk-load genets to resolve provenanceIds via genetId join
    final provenanceByGenetId = await _buildProvenanceIdLookup(coralOrganisms);

    for (final organismRecord in coralOrganisms) {
      final group = organismRecord.groupId != null
          ? groupById[organismRecord.groupId]
          : null;
      final provenanceId =
          provenanceByGenetId[organismRecord.genetId] ?? '';

      final rowMap = _organismRecordToMap(organismRecord, group, provenanceId);
      rows.add(InventoryExportRow.fromHoldingMap(rowMap));
    }

    return rows;
  }

  /// Builds a lookup from genetId → provenanceId by loading genets from
  /// the repository. Returns an empty map when no [GenetRepository] is
  /// available (graceful fallback).
  Future<Map<String, String>> _buildProvenanceIdLookup(
    List<OrganismRecord> organisms,
  ) async {
    if (_genetRepository == null) return const {};
    final genetIds = organisms
        .map((r) => r.genetId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (genetIds.isEmpty) return const {};

    final genets = await _genetRepository.getAll();
    return {
      for (final genet in genets)
        if (genetIds.contains(genet.id) && genet.provenanceId.isNotEmpty)
          genet.id: genet.provenanceId,
    };
  }

  /// Convert OrganismRecord to Map for export.
  ///
  /// [provenanceId] is resolved from the Genet record via [_buildProvenanceIdLookup].
  Map<String, dynamic> _organismRecordToMap(
    OrganismRecord organismRecord,
    Group? group,
    String provenanceId,
  ) {
    final recordName = organismRecord.recordName.trim();
    return {
      'id': organismRecord.id,
      'provenanceId': provenanceId,
      'localId': organismRecord.localId ?? '',
      'recordName': recordName,
      'organismKind': organismRecord.organismKind.name,
      'speciesId': organismRecord.speciesId,
      'siteId': organismRecord.siteId,
      'siteName': '', // Group doesn't have siteName, will be populated by formatter
      'groupId': group?.urlPath,
      'groupIdRaw': organismRecord.groupId,
      'groupName': group?.name,
      'lifeStageId': organismRecord.lifeStage.stage.id,
      'lifeStage': organismRecord.lifeStage.stage.name,
      'lifeStageLabel': organismRecord.lifeStage.stage.displayName,
      'physicalFormId': organismRecord.physicalForm?.formId ?? '',
      'physicalForm': organismRecord.physicalFormDisplayName ?? '',
      'sizeBandId': organismRecord.physicalForm?.sizeBandId ??
          organismRecord.sizeSpec.sizeBandId ??
          '',
      'measuredDimension':
          organismRecord.sizeSpec.measuredDimension?.toString() ?? '',
      'dimensionUnit': organismRecord.sizeSpec.dimensionUnit?.id ?? '',
      'organismsPerUnit':
          organismRecord.sizeSpec.organismsPerUnit?.toString() ?? '',
      'volumeAmount': organismRecord.sizeSpec.volumeAmount?.toString() ?? '',
      'volumeUnit': organismRecord.sizeSpec.volumeUnit?.id ?? '',
      'quantityValue': organismRecord.measurement.value.toString(),
      'measurementUnit': organismRecord.measurement.unit.id,
      'ownerOrganizationId': organismRecord.ownerOrganizationId,
      'managingOrganizationId': organismRecord.managingOrganizationId,
      'createdAt': organismRecord.createdAt,
      'updatedAt': organismRecord.updatedAt,
      'metadata': organismRecord.metadata,
      'provenanceType': organismRecord.provenanceType?.id,
      'provenanceKind': organismRecord.provenanceType?.defaultProvenanceKind.name,
      'aliases': organismRecord.aliases
          .map((a) => a.label ?? a.value)
          .where((s) => s.isNotEmpty)
          .toList(),
      // 3-field measurement metrics (count, volume, tissue area)
      'inventoryCount': organismRecord.sizeSpec.countOverride,
      'inventoryVolumeCm3': organismRecord.sizeSpec.volumeCm3Override,
      'inventoryTissueAreaCm2': organismRecord.sizeSpec.tissueAreaCm2Override,
    };
  }

  Future<List<InventoryExportRow>> _buildHoldingRows({
    required Map<String, Group> groupById,
    OrganismKind? organismFilter,
  }) async {
    final rows = <InventoryExportRow>[];
    final holdingMaps = await _loadHoldingMaps(
      groupById,
      organismFilter: organismFilter,
    );
    rows.addAll(holdingMaps.map(InventoryExportRow.fromHoldingMap));
    return rows;
  }

  Future<List<Map<String, dynamic>>> _loadHoldingMaps(
    Map<String, Group> groupById, {
    OrganismKind? organismFilter,
  }) async {
    if (_holdingLoader != null) {
      return _holdingLoader.loadRowsFor(organismKind: organismFilter);
    }
    return _loadHoldingMapsFromRepositories(
      groupById,
      organismFilter: organismFilter,
    );
  }

  Future<List<Map<String, dynamic>>> _loadHoldingMapsFromRepositories(
    Map<String, Group> groupById, {
    OrganismKind? organismFilter,
  }) async {
    final holders = <Map<String, dynamic>>[];
    final targetKinds = _targetHoldingKinds(organismFilter);

    for (final kind in targetKinds) {
      await _appendHoldingRows(
        repository: _seededLineRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.seededLineOverrides,
      );
      await _appendHoldingRows(
        repository: _oysterBagRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.oysterBagOverrides,
      );
      await _appendHoldingRows(
        repository: _gameteBatchRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.gameteOverrides,
      );
      await _appendHoldingRows(
        repository: _larvalBatchRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.larvalOverrides,
      );
      await _appendHoldingRows(
        repository: _finfishPenRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.finfishPenOverrides,
      );
      await _appendHoldingRows(
        repository: _crabPondRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.crabPondOverrides,
      );
      await _appendHoldingRows(
        repository: _seagrassModuleRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.seagrassModuleOverrides,
      );
      await _appendHoldingRows(
        repository: _mangrovePlotRepositories[kind],
        rows: holders,
        groupById: groupById,
        overridesBuilder: InventoryHoldingRowBuilder.mangrovePlotOverrides,
      );
    }

    return holders;
  }

  Future<void> _appendHoldingRows<T extends HoldingRecord>({
    required HoldingRepository<T>? repository,
    required List<Map<String, dynamic>> rows,
    required Map<String, Group> groupById,
    required Map<String, dynamic>? Function(T) overridesBuilder,
  }) async {
    if (repository == null) return;
    final holdings = await repository.fetchHoldings(
      organismKind: repository.organismContext.kind,
    );
    for (final holding in holdings) {
      rows.add(
        InventoryHoldingRowBuilder.build(
          holding: holding,
          holdingKind: repository.holdingKind,
          group: holding.groupId != null ? groupById[holding.groupId] : null,
          overrides: overridesBuilder(holding),
        ),
      );
    }
  }

  Iterable<OrganismKind> _targetHoldingKinds(OrganismKind? filter) {
    if (filter != null && filter != OrganismKind.coral) {
      return [filter];
    }
    final kinds = <OrganismKind>{
      ..._seededLineRepositories.keys,
      ..._oysterBagRepositories.keys,
      ..._gameteBatchRepositories.keys,
      ..._larvalBatchRepositories.keys,
      ..._finfishPenRepositories.keys,
      ..._crabPondRepositories.keys,
      ..._seagrassModuleRepositories.keys,
      ..._mangrovePlotRepositories.keys,
    };
    return kinds.sorted((a, b) => a.name.compareTo(b.name));
  }
}
