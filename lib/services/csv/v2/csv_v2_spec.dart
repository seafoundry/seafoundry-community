// @tier: community

/// Canonical metadata for the SeaFoundry Universal CSV v2 template.
///
/// Mirrors `SeaFoundry_Universal_CSV_v2_spec.json` so that adapters, validators,
/// and UI layers can reason about the new organism-aware schema without
/// duplicating string literals throughout the codebase.
///
/// The data below is sourced from:
/// - `docs/taxonomy/README.md` - Consolidated multi-organism architecture
///   and CSV v2 schema
/// - `SeaFoundry_Universal_CSV_v2_spec.json`
///
/// Nothing in this file enforces behavior at runtime yet; it simply provides a
/// typed contract so the forthcoming `UniversalCsvAdapterV2` can consume a
/// strongly-typed spec rather than parsing JSON at runtime.
library;

import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Canonical life stages per organism (mirrors the doc + JSON spec).
enum CsvV2LifeStage {
  gamete,
  larvae,
  recruit,
  juvenile,
  colony,
  fragment,
  spat,
  growOut,
  reef,
  seed,
  shoot,
  plot,
  spore,
  seededTwine,
  longline,
  harvest,
  propagule,
  nursery,
  sapling,
  adult,
  broodstock,
  zoea,
  megalopa,
  fry,
  fingerling,
  egg,
}

/// Enumerates supported measurement units. These groupings enable validation
/// rules for organism-specific measurements.
enum CsvV2MeasurementUnitCategory {
  count,
  length,
  area,
  volume,
  mass,
  environmental,
}

class CsvV2MeasurementUnit {
  const CsvV2MeasurementUnit(this.value, this.category);
  final String value;
  final CsvV2MeasurementUnitCategory category;

  static const List<CsvV2MeasurementUnit> values = [
    CsvV2MeasurementUnit('count', CsvV2MeasurementUnitCategory.count),
    CsvV2MeasurementUnit('colonies', CsvV2MeasurementUnitCategory.count),
    CsvV2MeasurementUnit('fragments', CsvV2MeasurementUnitCategory.count),
    CsvV2MeasurementUnit('individuals', CsvV2MeasurementUnitCategory.count),
    CsvV2MeasurementUnit('mm', CsvV2MeasurementUnitCategory.length),
    CsvV2MeasurementUnit('cm', CsvV2MeasurementUnitCategory.length),
    CsvV2MeasurementUnit('m', CsvV2MeasurementUnitCategory.length),
    CsvV2MeasurementUnit('m2', CsvV2MeasurementUnitCategory.area),
    CsvV2MeasurementUnit('ha', CsvV2MeasurementUnitCategory.area),
    CsvV2MeasurementUnit('L', CsvV2MeasurementUnitCategory.volume),
    CsvV2MeasurementUnit('m3', CsvV2MeasurementUnitCategory.volume),
    CsvV2MeasurementUnit('g', CsvV2MeasurementUnitCategory.mass),
    CsvV2MeasurementUnit('kg', CsvV2MeasurementUnitCategory.mass),
    CsvV2MeasurementUnit('kg_per_m', CsvV2MeasurementUnitCategory.mass),
    CsvV2MeasurementUnit('degC', CsvV2MeasurementUnitCategory.environmental),
    CsvV2MeasurementUnit('ppt', CsvV2MeasurementUnitCategory.environmental),
    CsvV2MeasurementUnit('psu', CsvV2MeasurementUnitCategory.environmental),
    CsvV2MeasurementUnit(
      'mg_per_L',
      CsvV2MeasurementUnitCategory.environmental,
    ),
    CsvV2MeasurementUnit('percent', CsvV2MeasurementUnitCategory.environmental),
  ];
}

/// Static helper describing every column group in CSV v2.
class CsvV2Spec {
  CsvV2Spec._();

  static const String version = '2.0.0-beta';

  /// Base identity + quantity fields required for every row.
  static const List<String> coreColumns = [
    'organismKind',
    'speciesScientific',
    'speciesCode',
    'provenanceId',
    'provenanceKind',
    'cohortId',
    'lifeStage',
    'localId',
    'tagId',
    'accessionId',
    'measurementUnit',
    'quantityValue',
    'eventType',
    'eventDate',
  ];

  /// 3-field measurement metrics columns for detailed organism measurements.
  /// These are enabled/disabled per physical form via PhysicalFormRegistry.
  static const List<String> metricsColumns = [
    'metricsCount',      // Number of individuals (int?)
    'metricsVolumeCm3', // Volume in cubic centimeters (double?)
    'metricsTissueAreaCm2', // Tissue area in square centimeters (double?)
  ];

  static const List<String> siteColumns = [
    'siteId',
    'siteName',
    'enclosureId',
    'groupId',
    'structureType',
    'inSituRow',
    'inSituCol',
    'geometryFormat',
    'geometryWkt',
    'geometryGeojson',
    'lineId',
    'dropperId',
  ];

  static const List<String> permitColumns = [
    'permitId',
    'permitType',
    'issuingAuthority',
    'validFrom',
    'validTo',
    'habitatType',
    'siteJurisdiction',
    'protectedAreaFlag',
  ];

  static const List<String> mrvColumns = [
    'carbonPool.total',
    'carbonPool.aboveGround',
    'carbonPool.belowGround',
    'stockTCo2e',
    'fluxTCo2eYr',
    'uncertaintyPct',
    'permanenceRiskScore',
  ];

  static const List<String> environmentalPanelColumns = [
    'environmentalPanel.temperatureC',
    'environmentalPanel.salinityPsu',
    'environmentalPanel.dissolvedOxygenMgL',
    'environmentalPanel.ammoniaMgL',
    'environmentalPanel.nitriteMgL',
    'environmentalPanel.nitrateMgL',
    'environmentalPanel.alkalinityMgLAsCaCo3',
    'environmentalPanel.pH',
  ];

  static const Map<OrganismKind, List<CsvV2LifeStage>> lifeStages = {
    OrganismKind.coral: [
      CsvV2LifeStage.gamete,
      CsvV2LifeStage.larvae,
      CsvV2LifeStage.recruit,
      CsvV2LifeStage.juvenile,
      CsvV2LifeStage.colony,
      CsvV2LifeStage.fragment,
    ],
  };

  /// Organism-specific metric columns (subset used by validation + UI).
  static const Map<OrganismKind, List<String>> organismSpecificColumns = {
    OrganismKind.coral: [
      'bleachingState',
      'diseaseCode',
      'partialMortalityPct',
      'benthicCoverPct',
    ],
  };
}
