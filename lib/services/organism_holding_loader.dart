// @tier: community
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/crab_pond_repository.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/gamete_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/mangrove_plot_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seagrass_module_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seeded_line_repository.dart';
import 'package:seafoundry_app/services/export/inventory_holding_row_builder.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Aggregates holdings across organism-specific repositories so spreadsheets,
/// dialogs, and exports can reuse the same combined dataset.
class OrganismHoldingLoader {
  factory OrganismHoldingLoader({
    required List<Map<OrganismKind, HoldingRepository>> holdingRepositories,
    required GroupRepository groupRepository,
  }) = OrganismHoldingLoader._internal;

  OrganismHoldingLoader._internal({
    required List<Map<OrganismKind, HoldingRepository>> holdingRepositories,
    required this.groupRepository,
  }) : _holdingRepositories =
           List<Map<OrganismKind, HoldingRepository>>.unmodifiable(
             holdingRepositories.map(
               (map) => Map<OrganismKind, HoldingRepository>.unmodifiable(map),
             ),
           );

  factory OrganismHoldingLoader.fromContext(BuildContext context) {
    final loader = OrganismHoldingLoader.maybeFromContext(context);
    if (loader == null) {
      throw StateError(
        'OrganismHoldingLoader dependencies not found in the widget tree.',
      );
    }
    return loader;
  }

  static OrganismHoldingLoader? maybeFromContext(BuildContext context) {
    final repositoryMaps = <Map<OrganismKind, HoldingRepository>>[];

    void addMap<T extends HoldingRepository>(Map<OrganismKind, T> typed) {
      if (typed.isEmpty) return;
      repositoryMaps.add(
        typed.map(
          (key, value) => MapEntry<OrganismKind, HoldingRepository>(key, value),
        ),
      );
    }

    Map<OrganismKind, T> readTypedMap<T extends HoldingRepository>() {
      try {
        final map = Provider.of<Map<OrganismKind, T>>(context, listen: false);
        return map;
      } catch (_) {
        return const {};
      }
    }

    final seededLineRepositories = readTypedMap<SeededLineRepository>();
    final oysterBagRepositories = readTypedMap<OysterBagRepository>();
    final gameteBatchRepositories = readTypedMap<GameteBatchRepository>();
    final larvalBatchRepositories = readTypedMap<LarvalBatchRepository>();
    final finfishPenRepositories = readTypedMap<FinfishPenRepository>();
    final crabPondRepositories = readTypedMap<CrabPondRepository>();
    final seagrassModuleRepositories = readTypedMap<SeagrassModuleRepository>();
    final mangrovePlotRepositories = readTypedMap<MangrovePlotRepository>();

    addMap(seededLineRepositories);
    addMap(oysterBagRepositories);
    addMap(gameteBatchRepositories);
    addMap(larvalBatchRepositories);
    addMap(finfishPenRepositories);
    addMap(crabPondRepositories);
    addMap(seagrassModuleRepositories);
    addMap(mangrovePlotRepositories);

    GroupRepository? groupRepository;
    try {
      groupRepository = Provider.of<GroupRepository>(context, listen: false);
    } catch (_) {
      groupRepository = null;
    }
    if (groupRepository == null) {
      return null;
    }
    if (repositoryMaps.isEmpty) {
      return null;
    }
    return OrganismHoldingLoader._internal(
      holdingRepositories: repositoryMaps,
      groupRepository: groupRepository,
    );
  }

  final List<Map<OrganismKind, HoldingRepository>> _holdingRepositories;
  final GroupRepository groupRepository;
  Map<String, Group>? _groupLookupCache;

  bool supports(OrganismKind kind) =>
      _holdingRepositories.any((map) => map.containsKey(kind));

  Future<List<Map<String, dynamic>>> loadRows(OrganismKind kind) {
    return loadRowsFor(organismKind: kind);
  }

  Future<List<Map<String, dynamic>>> loadRowsFor({
    OrganismKind? organismKind,
  }) async {
    final groupLookup = await _groupLookup();
    final rows = <Map<String, dynamic>>[];
    final kinds = organismKind != null
        ? {organismKind}
        : {for (final map in _holdingRepositories) ...map.keys};

    for (final kind in kinds) {
      for (final repositoryMap in _holdingRepositories) {
        final repository = repositoryMap[kind];
        if (repository == null) continue;
        await _appendRows(repository, rows, groupLookup, kind);
      }
    }
    return rows;
  }

  void clearGroupCache() {
    _groupLookupCache = null;
  }

  Future<Map<String, Group>> _groupLookup() async {
    if (_groupLookupCache != null) {
      return _groupLookupCache!;
    }
    final groups = await groupRepository.getAll();
    _groupLookupCache = {for (final group in groups) group.id: group};
    return _groupLookupCache!;
  }

  Future<void> _appendRows(
    HoldingRepository repository,
    List<Map<String, dynamic>> rows,
    Map<String, Group> groupLookup,
    OrganismKind effectiveKind,
  ) async {
    try {
      final holdings = await repository.fetchHoldings(
        organismKind: effectiveKind,
      );
      for (final holding in holdings) {
        rows.add(
          InventoryHoldingRowBuilder.build(
            holding: holding,
            holdingKind: repository.holdingKind,
            group: holding.groupId != null ? groupLookup[holding.groupId] : null,
          ),
        );
      }
    } catch (error, stackTrace) {
    LoggingService.instance.error(
      'Failed to load holdings for ${repository.holdingKind} (${effectiveKind.name})',
      error,
      stackTrace,
    );
    // Continue to next repository so a single failure doesn't break the panel.
  }
}
}
