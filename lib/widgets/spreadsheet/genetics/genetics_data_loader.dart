// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/location_display_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/genetics_spreadsheet_helper.dart';

class GeneticsSpreadsheetDataLoader {
  const GeneticsSpreadsheetDataLoader({
    required ProvenanceRepository provenanceRepository,
    required OrganismRecordRepository organismRepository,
  }) : _provenanceRepository = provenanceRepository,
       _organismRepository = organismRepository;

  final ProvenanceRepository _provenanceRepository;
  final OrganismRecordRepository _organismRepository;

  Future<List<Map<String, dynamic>>> loadRows({
    required bool includeInactiveCorals,
    bool includeArchivedGenets = false,
    String? speciesFilter,
    Organization? organization,
    required String Function(String) provenanceTypeLabel,
    required String Function(String) physicalFormLabel,
    required String Function(DateTime?) formatDate,
    required String Function(List<String>?) joinIds,
    required String Function(ProvenanceRecord) aggregateParentGametes,
    required String Function(ProvenanceRecord) genotypeProvenanceText,
  }) async {
    final genets = await _provenanceRepository.getAll();
    final organisms = await _organismRepository.getAll();
    final coralOrganisms = organisms
        .where((o) => o.organismKind == OrganismKind.coral)
        .toList();

    final filteredGenets = genets
        .where((genet) {
          if (!includeArchivedGenets && genet.isArchived) {
            return false;
          }
          if (speciesFilter != null && speciesFilter.isNotEmpty) {
            return genet.speciesId == speciesFilter;
          }
          return true;
        })
        .toList(growable: false);

    final speciesLookup = <String, String>{};
    GeneticsSpreadsheetHelper.populateSpeciesLookup(
      speciesLookup,
      organization: organization,
      fallbackSpeciesIds: filteredGenets.map((genet) => genet.speciesId),
    );

    final organismsByGenet = <String, List<OrganismRecord>>{};
    for (final organism in coralOrganisms) {
      final genetId = GenetIdResolver.resolve(organism) ?? '';
      if (genetId.isEmpty) continue;
      final healthStatus = organism.healthStatus;
      if (!includeInactiveCorals && !healthStatus.isActiveInventory) {
        continue;
      }
      organismsByGenet.putIfAbsent(genetId, () => <OrganismRecord>[]).add(organism);
    }

    final rows = <Map<String, dynamic>>[];
    for (final genet in filteredGenets) {
      final genetOrganisms = organismsByGenet[genet.id] ?? const <OrganismRecord>[];

      final totalQuantity = genetOrganisms.fold<int>(0, (sum, organism) {
        final quantity = _organismQuantity(organism);
        return sum + quantity;
      });

      final uniqueSites = genetOrganisms
          .map((organism) {
            final locationPath = LocationDisplayService.formatFromRecordPath(
              organism.urlPath,
              organizationDomain: organization?.domain,
              fallback: organism.urlPath,
            );
            final segments = locationPath
                .split('/')
                .where((segment) => segment.isNotEmpty)
                .toList();
            return segments.isNotEmpty ? segments.first : '';
          })
          .where((site) => site.isNotEmpty)
          .toSet();

      final row = GeneticsSpreadsheetHelper.buildGenetRow(
        genet: genet,
        speciesLookup: speciesLookup,
        organisms: genetOrganisms,
        totalQuantity: totalQuantity,
        nurseryCount: uniqueSites.length,
        organizationDomain: organization?.domain,
        provenanceTypeLabel: provenanceTypeLabel,
        physicalFormLabel: physicalFormLabel,
        formatDate: formatDate,
        joinIds: joinIds,
        aggregateParentGametes: aggregateParentGametes,
        genotypeProvenanceText: genotypeProvenanceText,
      );

      rows.add(row);
    }

    LoggingService.instance.debug(
      'Loaded ${rows.length} genetics rows (species filter: ${speciesFilter ?? 'none'})',
    );

    return rows;
  }

  int _organismQuantity(OrganismRecord organism) {
    final count = organism.inventoryMetrics.count;
    if (count != null) {
      return count;
    }
    if (organism.measurement.unit.category == MeasurementUnitCategory.count) {
      return organism.measurement.value.round();
    }
    return 1;
  }
}
