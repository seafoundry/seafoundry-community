// @tier: community
import 'package:flutter/widgets.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/location_display_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';

import 'genetics_columns.dart';

class GeneticsSpreadsheetHelper {
  static void populateSpeciesLookup(
    Map<String, String> speciesLookup, {
    Organization? organization,
    Iterable<String> fallbackSpeciesIds = const [],
  }) {
    if (organization != null) {
      for (final speciesId in organization.speciesIds) {
        final species = SpeciesRegistry.globalById(speciesId);
        if (species != null && species.id.isNotEmpty) {
          speciesLookup[speciesId] = species.name;
        }
      }
    }

    for (final speciesId in fallbackSpeciesIds) {
      final species = SpeciesRegistry.globalById(speciesId);
      if (species != null && species.id.isNotEmpty) {
        speciesLookup.putIfAbsent(speciesId, () => species.name);
      }
    }

    for (final species in SpeciesRegistry.globalAll()) {
      speciesLookup.putIfAbsent(species.id, () => species.name);
    }
  }

  static String resolveSpeciesName(
    String speciesId,
    Map<String, String> speciesLookup,
  ) {
    if (speciesId.isEmpty) return 'Unknown';
    final cached = speciesLookup[speciesId];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final species = SpeciesRegistry.globalById(speciesId);
    if (species != null && species.id.isNotEmpty) {
      speciesLookup[speciesId] = species.name;
      return species.name;
    }

    return speciesId;
  }

  static List<SpreadsheetColumn> buildColumns(
    List<GeneticsColumnDefinition> columns,
  ) => GeneticsColumnBuilders.buildColumns(columns);

  static SpreadsheetRow buildRow(
    BuildContext context,
    Map<String, dynamic> row,
    List<GeneticsColumnDefinition> columns, {
    int rowIndex = 0,
    void Function(BuildContext, Map<String, dynamic>)? onEdit,
    Widget Function(BuildContext, Map<String, dynamic>)? rowActionsBuilder,
  }) => GeneticsColumnBuilders.buildRow(
    context,
    row,
    columns,
    rowIndex: rowIndex,
    onEdit: onEdit,
    rowActionsBuilder: rowActionsBuilder,
  );

  static String formatLocations(dynamic locationsField) {
    if (locationsField is List) {
      final entries = locationsField
          .map((value) {
            if (value is String) return value;
            if (value is Map) {
              final label = value['label'] ?? value['name'] ?? value['path'];
              if (label is String && label.isNotEmpty) {
                return label;
              }
              final path = value['urlPath'] ?? value['path'];
              return path is String ? path : null;
            }
            return value?.toString();
          })
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      final list = entries.toList();
      if (list.isEmpty) {
        return 'No Locations';
      }
      if (list.length <= 2) {
        return list.join(', ');
      }
      return '${list.take(2).join(', ')} +${list.length - 2} more';
    }

    if (locationsField is String && locationsField.isNotEmpty) {
      return locationsField;
    }

    return 'No Locations';
  }

  static Map<String, dynamic> buildGenetRow({
    required ProvenanceRecord genet,
    required Map<String, String> speciesLookup,
    required int totalQuantity,
    required int nurseryCount,
    String? organizationDomain,
    List<OrganismRecord> organisms = const [],
    String Function(String)? provenanceTypeLabel,
    String Function(String)? physicalFormLabel,
    String Function(DateTime?)? formatDate,
    String Function(List<String>?)? joinIds,
    String Function(ProvenanceRecord)? aggregateParentGametes,
    String Function(ProvenanceRecord)? genotypeProvenanceText,
  }) {
    final labelProvenanceType = provenanceTypeLabel ?? (value) => value;
    final labelPhysicalForm = physicalFormLabel ?? (value) => value;
    final dateFormatter = formatDate ?? _defaultFormatDate;
    final joiner = joinIds ?? _defaultJoinIds;
    final aggregateParents = aggregateParentGametes ?? _defaultAggregateParents;
    final provenanceText = genotypeProvenanceText ?? _defaultProvenanceText;

    final provenanceTypeId = genet.provenanceTypeId;
    final speciesName = resolveSpeciesName(genet.speciesId, speciesLookup);
    final createdBy = genet.createdById;
    final damGametes = joiner(genet.damGameteIds);
    final sireGametes = joiner(genet.sireGameteIds);
    final recruitParent = genet.parentProvenanceId ?? '';
    final donorGenotypeId = genet.donorGenotypeId;
    final aliasLabels = genet.aliasLabels;

    // Extract physical forms from organisms
    final physicalForms = organisms
        .map((o) => o.physicalForm?.formId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final locationBreadcrumbs = <String>{};
    final siteGrouped = <String, Set<String>>{};
    DateTime? latestOrganismCreatedAt;

    for (final organism in organisms) {
      final urlPath = organism.urlPath;
      final locationPath = LocationDisplayService.formatFromRecordPath(
        urlPath,
        organizationDomain: organizationDomain,
        fallback: urlPath,
      );
      final pathSegments = locationPath
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList();
      if (pathSegments.isEmpty) {
        if (locationPath.isNotEmpty) {
          locationBreadcrumbs.add(locationPath);
        }
        continue;
      }

      final String siteLabel = pathSegments.first;
      final String pathLabel = pathSegments.join('/');
      locationBreadcrumbs.add(pathLabel);
      siteGrouped.putIfAbsent(siteLabel, () => <String>{}).add(pathLabel);

      final createdAt = DateTime.parse(organism.createdAt);
      if (latestOrganismCreatedAt == null ||
          createdAt.isAfter(latestOrganismCreatedAt)) {
        latestOrganismCreatedAt = createdAt;
      }
    }

    final formattedLocations = locationBreadcrumbs.toList()..sort();
    final siteNames = siteGrouped.keys.toList()..sort();

    final String physicalFormValue = physicalForms.isEmpty
        ? ''
        : physicalForms.length == 1
            ? physicalForms.first
            : 'mixed';
    final clonalIdDisplay =
        ClonalIdDisplayService.resolveForProvenanceRecord(genet);

    final row = <String, dynamic>{
      'genetId': genet.id,
      'genetName': genet.displayName,
      'genetSlug': genet.id,
      'genetType': provenanceTypeId,
      'genetTypeLabel': labelProvenanceType(provenanceTypeId ?? ''),
      'speciesId': genet.speciesId,
      'speciesName': speciesName,
      'provenanceId': genet.provenanceId,
      'clonalId': genet.clonalId,
      'clonalIdDisplay': clonalIdDisplay ?? '',
      'accessionNumber': genet.accessionNumber,
      'genetNotes': genet.notes,
      'archived': genet.isArchived,
      'archivedAt': genet.archivedAt,
      'totalQuantity': totalQuantity,
      'numNurseries': nurseryCount,
      'createdAtDisplay': dateFormatter(DateTime.tryParse(genet.createdAt) ?? DateTime.now()),
      'createdBy': createdBy,
      'crossDate': dateFormatter(genet.crossDate),
      'damGameteIds': damGametes,
      'sireGameteIds': sireGametes,
      'genotypeProvenance': provenanceText(genet),
      'cohortParentGameteIds': aggregateParents(genet),
      'recruitParentCohortId': recruitParent,
      'gameteDonorGenotypeId': donorGenotypeId,
      'aliases': aliasLabels.join('; '),
      'aliasLabels': aliasLabels.join('; '),
      'nurseryLocations': formattedLocations,
      'locationBreadcrumbs': formattedLocations,
      'siteNames': siteNames,
      'createdAt': latestOrganismCreatedAt ?? DateTime.tryParse(genet.createdAt) ?? DateTime.now(),
      'recordIds': organisms.map((o) => o.id).where((id) => id.isNotEmpty).toList(),
      'recordNames': organisms.map((o) => o.name).where((id) => id.isNotEmpty).toList(),
      'organismKind': OrganismKind.coral.name,
      'organismCount': organisms.length,
      'physicalFormIds': physicalForms.toList()..sort(),
      'physicalForm': physicalFormValue,
      'coralCount': organisms.length,
      'clusterType': physicalForms.isEmpty
          ? 'None'
          : physicalForms.length == 1
              ? labelPhysicalForm(physicalForms.first)
              : 'Mixed',
      'coralNotes': organisms.isEmpty
          ? 'No associated organisms'
          : '${organisms.length} organism${organisms.length == 1 ? '' : 's'} in inventory',
      'locationPath': formattedLocations.isEmpty
          ? ''
          : formattedLocations.first,
      'heatTested': genet.heatTested,
      'diseaseTested': genet.diseaseTested,
      'heatTestingComment': genet.heatTestingComment,
      'diseaseTestingComment': genet.diseaseTestingComment,
    };

    // Use ProvenanceLifeStageSelection to properly check metadata first
    final provenanceSelection = ProvenanceLifeStageSelection.fromProvenanceRecord(genet);
    final resolvedProvenanceType = provenanceSelection.provenanceType;
    row.addAll({
      'provenanceKind': 'genet',
      'provenanceType': resolvedProvenanceType.id,
      'provenanceTypeLabel': resolvedProvenanceType.displayName,
    });

    final provenance = genet.provenance;
    if (provenance != null) {
      row.addAll({
        'reefOfOrigin': provenance['reefOfOrigin'] ?? provenance['reef_of_origin'] ?? '',
        'collectionDate': provenance['collectionDate'] ?? provenance['collection_date'] ?? '',
        'depth': provenance['depth']?.toString() ?? '',
        'habitatType': provenance['habitatType'] ?? provenance['habitat_type'] ?? '',
        'collectingInstitution': provenance['collectingInstitution'] ?? provenance['collecting_institution'] ?? '',
        'latitude': provenance['latitude']?.toString() ?? '',
        'longitude': provenance['longitude']?.toString() ?? '',
        'parentGenetId': provenance['parentGenetId'] ?? provenance['parent_genet_id'] ?? '',
        'parentGenetName': provenance['parentGenetName'] ?? provenance['parent_genet_name'] ?? '',
        'spawnDate': provenance['spawnDate'] ?? provenance['spawn_date'] ?? '',
        'settlementDate': provenance['settlementDate'] ?? provenance['settlement_date'] ?? '',
        'cohortSize': (provenance['cohortSize'] ?? provenance['cohort_size'])?.toString() ?? '',
        'cohortNotes': provenance['cohortNotes'] ?? provenance['cohort_notes'] ?? '',
        'sendingOrganization': provenance['sendingOrganization'] ?? provenance['sending_organization'] ?? '',
        'transferDate': provenance['transferDate'] ?? provenance['transfer_date'] ?? '',
        'transferNotes': provenance['transferNotes'] ?? provenance['transfer_notes'] ?? '',
      });
    }

    row['createdAtDisplay'] = dateFormatter(
      latestOrganismCreatedAt ?? DateTime.tryParse(genet.createdAt) ?? DateTime.now(),
    );

    if (organisms.isNotEmpty) {
      row.putIfAbsent('recordIds', () => organisms.map((o) => o.id).toList());
      row.putIfAbsent(
        'recordNames',
        () => organisms.map((o) => o.recordName).toList(),
      );
    }

    _addSnakeCaseAliases(row);

    return row;
  }

  static void _addSnakeCaseAliases(Map<String, dynamic> row) {
    void put(String camel, String snake) {
      if (row.containsKey(camel)) {
        row.putIfAbsent(snake, () => row[camel]);
      }
    }

    put('genetId', 'genet_id');
    put('genetName', 'genet_name');
    put('genetSlug', 'genet_slug');
    put('genetType', 'genet_type');
    put('genetTypeLabel', 'genet_type_label');
    put('speciesId', 'species_id');
    put('speciesName', 'species_name');
    put('provenanceId', 'provenance_id');
    put('clonalId', 'clonal_id');
    put('accessionNumber', 'accession_number');
    put('genetNotes', 'genet_notes');
    put('archivedAt', 'archived_at');
    put('totalQuantity', 'total_quantity');
    put('numNurseries', 'num_nurseries');
    put('coralCount', 'coral_count');
    put('organismCount', 'organism_count');
    put('physicalFormIds', 'physical_form_ids');
    put('physicalForm', 'physical_form');
    put('clusterType', 'cluster_type');
    put('coralNotes', 'coral_notes');
    put('locationBreadcrumbs', 'location_breadcrumbs');
    put('siteNames', 'site_names');
    put('createdAt', 'created_at');
    put('createdAtDisplay', 'created_at_display');
    put('createdBy', 'created_by');
    put('crossDate', 'cross_date');
    put('damGameteIds', 'dam_gamete_ids');
    put('sireGameteIds', 'sire_gamete_ids');
    put('genotypeProvenance', 'genotype_provenance');
    put('cohortParentGameteIds', 'cohort_parent_gamete_ids');
    put('recruitParentCohortId', 'recruit_parent_cohort_id');
    put('gameteDonorGenotypeId', 'gamete_donor_genotype_id');
    put('aliasLabels', 'alias_labels');
    put('recordIds', 'record_ids');
    put('recordNames', 'record_names');
    put('organismKind', 'organism_kind');
    put('heatTested', 'heat_tested');
    put('diseaseTested', 'disease_tested');
    put('heatTestingComment', 'heat_testing_comment');
    put('diseaseTestingComment', 'disease_testing_comment');
    put('reefOfOrigin', 'reef_of_origin');
    put('collectionDate', 'collection_date');
    put('collectingInstitution', 'collecting_institution');
    put('parentGenetId', 'parent_genet_id');
    put('parentGenetName', 'parent_genet_name');
    put('spawnDate', 'spawn_date');
    put('settlementDate', 'settlement_date');
    put('cohortSize', 'cohort_size');
    put('cohortNotes', 'cohort_notes');
    put('sendingOrganization', 'sending_organization');
    put('transferDate', 'transfer_date');
    put('transferNotes', 'transfer_notes');
  }

  static Map<String, int> summarizeCounts(List<Map<String, dynamic>> rows) {
    final stats = <String, int>{
      'genets': 0,
      'species': 0,
      'corals': 0,
      'coralRecords': 0,
    };
    stats['genets'] = rows
        .map((row) {
          final dynamic rawId = row['genetId'];
          return rawId == null ? '' : rawId.toString();
        })
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    stats['species'] = rows
        .map((row) {
          final dynamic rawId = row['speciesId'];
          return rawId == null ? '' : rawId.toString();
        })
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    stats['corals'] = rows.fold<int>(0, (sum, row) {
      final raw = row['totalQuantity'];
      if (raw is num) return sum + raw.round();
      if (raw is String) return sum + (int.tryParse(raw) ?? 0);
      return sum;
    });
    stats['coralRecords'] = rows.fold<int>(0, (sum, row) {
      final raw = row['organismCount'];
      if (raw is num) return sum + raw.round();
      if (raw is String) return sum + (int.tryParse(raw) ?? 0);
      return sum;
    });
    return stats;
  }

  static Map<String, int> countByField(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    final counts = <String, int>{};
    for (final row in rows) {
      final value = row[key];
      if (value is String && value.isNotEmpty) {
        counts[value] = (counts[value] ?? 0) + 1;
      }
    }
    return counts;
  }

  static String _defaultFormatDate(DateTime? date) {
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _defaultJoinIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) return '';
    return ids.join(', ');
  }

  static String _defaultAggregateParents(ProvenanceRecord genet) {
    final combined = <String>{};
    combined.addAll(genet.parentGameteIds);
    combined.addAll(genet.damGameteIds);
    combined.addAll(genet.sireGameteIds);
    final list = combined.toList()..sort();
    return list.join(', ');
  }

  /// Formats provenance data for display, filtering out internal type IDs.
  ///
  /// This is the canonical implementation - other locations should delegate here.
  static String formatProvenanceText(ProvenanceRecord genet) {
    final provenance = genet.provenance;
    if (provenance == null || provenance.isEmpty) return '';
    final description = provenance['description'];
    if (description is String && description.trim().isNotEmpty) {
      return description.trim();
    }
    // Filter out internal type ID keys that should not be displayed
    const internalKeys = {
      'provenanceType',
      'provenanceKind',
      'type',
      'kind',
      'id',
      'organismKind',
      'speciesId',
      'parentGenetId',
      'donorGenetId',
      'parentProvenanceId',
    };
    // Filter out values that look like internal IDs
    bool isInternalId(String value) {
      if (value.startsWith('provenance_type_')) return true;
      if (value.startsWith('life_stage_')) return true;
      if (value.startsWith('organism_kind_')) return true;
      if (value.startsWith('physical_form_')) return true;
      // UUID pattern check
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      if (uuidPattern.hasMatch(value)) return true;
      return false;
    }
    return provenance.entries
        .where((entry) => !internalKeys.contains(entry.key))
        .where((entry) => entry.value is String)
        .map((entry) => (entry.value as String).trim())
        .where((value) => value.isNotEmpty && !isInternalId(value))
        .join('; ');
  }

  static String _defaultProvenanceText(ProvenanceRecord genet) =>
      formatProvenanceText(genet);
}
