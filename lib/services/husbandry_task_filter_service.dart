// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/task_event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/location_display_service.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';
import 'package:seafoundry_app/widgets/spreadsheet/husbandry_filter_metadata.dart';
import 'package:seafoundry_app/widgets/workspaces/husbandry_task_filter.dart';

class HusbandryTaskData {
  const HusbandryTaskData({
    required this.tasks,
    required this.rows,
    required this.rowByTaskId,
    required this.metadata,
  });

  final List<TaskEvent> tasks;
  final List<Map<String, dynamic>> rows;
  final Map<String, Map<String, dynamic>> rowByTaskId;
  final HusbandryFilterMetadata metadata;

  factory HusbandryTaskData.empty() => const HusbandryTaskData(
        tasks: [],
        rows: [],
        rowByTaskId: {},
        metadata: HusbandryFilterMetadata(
          siteNames: {},
          structurePaths: {},
          speciesIds: {},
          genetIds: {},
          lifeStageIds: {},
          provenanceTypes: {},
          issueTypeIds: {},
        ),
      );
}

class HusbandryTaskFilterService {
  const HusbandryTaskFilterService();

  Future<HusbandryTaskData> buildTaskData({
    required List<TaskEvent> tasks,
    required RecordRepository recordRepository,
    String? organizationId,
    String? organizationDomain,
  }) async {
    if (tasks.isEmpty) {
      return HusbandryTaskData.empty();
    }

    final resolvedOrganizationId =
        organizationId ?? _firstOrganizationId(tasks);
    final organismCache = <String, OrganismRecord?>{};
    final genetCache = <String, Genet?>{};
    final siteCache = <String, Site?>{};
    final userNames = <String, String>{};

    Future<OrganismRecord?> loadOrganism(String id) async {
      if (organismCache.containsKey(id)) {
        return organismCache[id];
      }
      try {
        final organism = await recordRepository.getRecord<OrganismRecord>(
          ModelType.organismRecord,
          id,
          organizationId: resolvedOrganizationId,
        );
        organismCache[id] = organism;
        return organism;
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to load organism $id for husbandry task metadata',
          error,
          stackTrace,
        );
        organismCache[id] = null;
        return null;
      }
    }

    Future<Genet?> loadGenet(String id) async {
      if (genetCache.containsKey(id)) {
        return genetCache[id];
      }
      try {
        final genet = await recordRepository.getRecord<Genet>(
          ModelType.genet,
          id,
          organizationId: resolvedOrganizationId,
        );
        genetCache[id] = genet;
        return genet;
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to load genet $id for husbandry task metadata',
          error,
          stackTrace,
        );
        genetCache[id] = null;
        return null;
      }
    }

    Future<Site?> loadSite(String id) async {
      if (siteCache.containsKey(id)) {
        return siteCache[id];
      }
      try {
        final site = await recordRepository.getRecord<Site>(
          ModelType.site,
          id,
        );
        siteCache[id] = site;
        return site;
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to load site $id for husbandry task metadata',
          error,
          stackTrace,
        );
        siteCache[id] = null;
        return null;
      }
    }

    final organismIds = tasks
        .where(
          (event) =>
              event.recordModelType == ModelType.organismRecord &&
              event.recordId.isNotEmpty,
        )
        .map((event) => event.recordId)
        .toSet();
    await Future.wait(organismIds.map(loadOrganism));

    final genetIds = <String>{
      ...tasks
          .where(
            (event) =>
                event.recordModelType == ModelType.genet &&
                event.recordId.isNotEmpty,
          )
          .map((event) => event.recordId),
    };
    for (final organism in organismCache.values.whereType<OrganismRecord>()) {
      final genetId = GenetIdResolver.resolve(organism);
      if (genetId != null && genetId.isNotEmpty) {
        genetIds.add(genetId);
      }
    }
    await Future.wait(genetIds.map(loadGenet));

    final siteIds = <String>{
      ...tasks
          .where(
            (event) =>
                event.recordModelType == ModelType.site &&
                event.recordId.isNotEmpty,
          )
          .map((event) => event.recordId),
    };
    for (final organism in organismCache.values.whereType<OrganismRecord>()) {
      final siteId = organism.siteId;
      if (siteId != null && siteId.isNotEmpty) {
        siteIds.add(siteId);
      }
    }
    await Future.wait(siteIds.map(loadSite));

    final userIds = tasks
        .map((task) => task.createdById)
        .where((id) => id.isNotEmpty)
        .toSet();
    await Future.wait(
      userIds.map(
        (userId) => resolveUserDisplayName(
          recordRepository: recordRepository,
          userId: userId,
          cache: userNames,
        ),
      ),
    );

    final rows = <Map<String, dynamic>>[];
    final rowByTaskId = <String, Map<String, dynamic>>{};

    for (final task in tasks) {
      OrganismRecord? organism;
      Genet? genet;
      Site? site;
      ProvenanceLifeStageSelection? selection;
      String? genetId;

      if (task.recordModelType == ModelType.organismRecord &&
          task.recordId.isNotEmpty) {
        organism = organismCache[task.recordId];
        genetId = organism != null ? GenetIdResolver.resolve(organism) : null;
        if (genetId != null && genetId.isNotEmpty) {
          genet = genetCache[genetId];
        }
        final siteId = organism?.siteId;
        if (siteId != null && siteId.isNotEmpty) {
          site = siteCache[siteId];
        }
        if (organism != null) {
          selection = buildProvenanceSelection(
            organism: organism,
            provenance: genet,
          );
        }
      } else if (task.recordModelType == ModelType.genet &&
          task.recordId.isNotEmpty) {
        genetId = task.recordId;
        genet = genetCache[genetId];
        selection =
            genet != null ? ProvenanceLifeStageSelection.fromGenet(genet) : null;
      } else if (task.recordModelType == ModelType.site &&
          task.recordId.isNotEmpty) {
        site = siteCache[task.recordId];
      }

      final row = _buildRow(
        task,
        organism: organism,
        genet: genet,
        site: site,
        selection: selection,
        genetId: genetId,
        userDisplayName: userNames[task.createdById],
        organizationDomain: organizationDomain,
      );
      rows.add(row);
      rowByTaskId[task.id] = row;
    }

    final siteNames = <String, String>{
      for (final entry in siteCache.entries)
        if (entry.value != null) entry.key: entry.value!.name,
    };
    final metadata = HusbandryFilterMetadata(
      siteNames: siteNames,
      structurePaths: {
        for (final row in rows)
          if ((row['structurePath'])?.isNotEmpty ?? false)
            row['structurePath'] as String,
      },
      speciesIds: {
        for (final row in rows)
          if ((row['speciesId'])?.isNotEmpty ?? false)
            row['speciesId'] as String,
      },
      genetIds: {
        for (final row in rows)
          if ((row['genetId'])?.isNotEmpty ?? false)
            row['genetId'] as String,
      },
      lifeStageIds: {
        for (final row in rows)
          if ((row['lifeStageId'])?.isNotEmpty ?? false)
            row['lifeStageId'] as String,
      },
      provenanceTypes: {
        for (final row in rows)
          if ((row['provenanceType'])?.isNotEmpty ?? false)
            row['provenanceType'] as String,
      },
      issueTypeIds: rows
          .map((row) => row['issueTypeId'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet(),
    );

    return HusbandryTaskData(
      tasks: tasks,
      rows: rows,
      rowByTaskId: rowByTaskId,
      metadata: metadata,
    );
  }

  List<TaskEvent> filterTasks({
    required HusbandryTaskData data,
    Set<String> siteFilterIds = const {},
    Set<String> structureFilterIds = const {},
    Set<String> speciesFilterIds = const {},
    Set<String> genetFilterIds = const {},
    Set<String> lifeStageFilterIds = const {},
    Set<String> provenanceTypeFilterIds = const {},
    Set<String> issueTypeFilterIds = const {},
    DateTimeRange? dateRange,
    HusbandryTaskFilter taskFilter = HusbandryTaskFilter.all,
    bool bestEffort = true,
  }) {
    final rangeStart = dateRange != null ? DateRangePresets.startOfDay(dateRange.start) : null;
    final rangeEnd = dateRange != null ? DateRangePresets.endOfDay(dateRange.end) : null;

    /// Multiselect filter: match ANY selected value (OR logic).
    /// If filter set is empty, all values pass.
    bool matchesSet(String? actual, Set<String> filterValues) {
      if (filterValues.isEmpty) return true;
      if (actual == null || actual.isEmpty) return bestEffort;
      return filterValues.contains(actual);
    }

    /// Structure filter: match ANY selected value by prefix (OR logic).
    bool matchesStructureSet(String? actual, Set<String> filterValues) {
      if (filterValues.isEmpty) return true;
      if (actual == null || actual.isEmpty) return bestEffort;
      return filterValues.any((filter) => actual.startsWith(filter));
    }

    bool matchesDate(TaskEvent task, Map<String, dynamic>? row) {
      if (rangeStart == null || rangeEnd == null) return true;
      final raw = row?['timestamp']?.toString() ?? task.createdAt;
      final createdAt = DateTime.tryParse(raw);
      if (createdAt == null) {
        return bestEffort;
      }
      return !createdAt.isBefore(rangeStart) && !createdAt.isAfter(rangeEnd);
    }

    bool matchesStatus(TaskEvent task) {
      switch (taskFilter) {
        case HusbandryTaskFilter.all:
          return true;
        case HusbandryTaskFilter.completed:
          return task.isCompleted;
        case HusbandryTaskFilter.overdue:
          return task.isOverdue;
        case HusbandryTaskFilter.pending:
          return !task.isCompleted && !task.isOverdue;
      }
    }

    return data.tasks.where((task) {
      final row = data.rowByTaskId[task.id];
      if (row == null && !bestEffort) {
        return false;
      }
      if (!matchesSet(row?['siteId'] as String?, siteFilterIds)) {
        return false;
      }
      if (!matchesStructureSet(row?['structurePath'] as String?, structureFilterIds)) {
        return false;
      }
      if (!matchesSet(row?['speciesId'] as String?, speciesFilterIds)) {
        return false;
      }
      if (!matchesSet(row?['genetId'] as String?, genetFilterIds)) {
        return false;
      }
      if (!matchesSet(row?['lifeStageId'] as String?, lifeStageFilterIds)) {
        return false;
      }
      if (!matchesSet(
        row?['provenanceType'] as String?,
        provenanceTypeFilterIds,
      )) {
        return false;
      }
      if (!matchesSet(row?['issueTypeId'] as String?, issueTypeFilterIds)) {
        return false;
      }
      if (!matchesDate(task, row)) {
        return false;
      }
      return matchesStatus(task);
    }).toList();
  }

  List<Map<String, dynamic>> filterRows({
    required HusbandryTaskData data,
    Set<String> siteFilterIds = const {},
    Set<String> structureFilterIds = const {},
    Set<String> speciesFilterIds = const {},
    Set<String> genetFilterIds = const {},
    Set<String> lifeStageFilterIds = const {},
    Set<String> provenanceTypeFilterIds = const {},
    Set<String> issueTypeFilterIds = const {},
    DateTimeRange? dateRange,
    HusbandryTaskFilter taskFilter = HusbandryTaskFilter.all,
    bool bestEffort = true,
  }) {
    final tasks = filterTasks(
      data: data,
      siteFilterIds: siteFilterIds,
      structureFilterIds: structureFilterIds,
      speciesFilterIds: speciesFilterIds,
      genetFilterIds: genetFilterIds,
      lifeStageFilterIds: lifeStageFilterIds,
      provenanceTypeFilterIds: provenanceTypeFilterIds,
      issueTypeFilterIds: issueTypeFilterIds,
      dateRange: dateRange,
      taskFilter: taskFilter,
      bestEffort: bestEffort,
    );

    final filteredRows = <Map<String, dynamic>>[];
    for (final task in tasks) {
      final row = data.rowByTaskId[task.id];
      if (row != null) {
        filteredRows.add(row);
      } else if (bestEffort) {
        filteredRows.add(_buildRow(task));
      }
    }

    filteredRows.sort((a, b) {
      final aDate = DateTime.tryParse(a['timestamp']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['timestamp']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return filteredRows;
  }

  String? _firstOrganizationId(List<TaskEvent> tasks) {
    for (final task in tasks) {
      if (task.organizationId.isNotEmpty) return task.organizationId;
    }
    return null;
  }

  String? _structurePath(String urlPath) {
    final parts = urlPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (parts.length >= 3) {
      return parts.sublist(0, 3).join('/');
    }
    if (parts.length >= 2) {
      return parts.sublist(0, 2).join('/');
    }
    return parts.isNotEmpty ? parts.first : null;
  }

  Map<String, dynamic> _buildRow(
    TaskEvent task, {
    OrganismRecord? organism,
    Genet? genet,
    Site? site,
    ProvenanceLifeStageSelection? selection,
    String? genetId,
    String? userDisplayName,
    String? organizationDomain,
  }) {
    final structurePath = _structurePath(task.urlPath);
    final lifeStageId =
        selection?.lifeStage.id ?? organism?.lifeStage.stage.id ?? '';
    final provenanceTypeId =
        selection?.provenanceType.id ?? genet?.provenanceTypeId ?? '';
    final location = LocationDisplayService.formatFromEvent(
      task,
      organizationDomain: organizationDomain,
      fallback: task.urlPath,
    );
    return {
      'timestamp': task.createdAt,
      'user': userDisplayName ?? task.createdById,
      'location': location,
      'taskType': task.husbandryActionType.label,
      'issueTypeId': task.husbandryActionTypeId ?? '',
      'description': task.description ?? '',
      'priority': task.priority.label,
      'status': task.status.label,
      'completionTime': task.completedAt?.toIso8601String() ?? '',
      'notes': '',
      'siteId': organism?.siteId ?? site?.id ?? '',
      'siteName': site?.name ?? '',
      'structurePath': structurePath ?? '',
      'speciesId': organism?.speciesId ?? genet?.speciesId ?? '',
      'genetId': genetId ?? '',
      'genetTypeId': genet?.provenanceTypeId ?? '',
      'physicalFormId':
          organism?.physicalForm?.formId ?? '',
      'lifeStageId': lifeStageId,
      'provenanceType': provenanceTypeId,
    };
  }
}
