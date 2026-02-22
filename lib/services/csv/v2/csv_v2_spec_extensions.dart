// @tier: community
import 'dart:collection';

import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Additional helpers layered on top of `CsvV2Spec` so adapters/validators can
/// reason about recurring column groups (e.g., the canonical five-axis record
/// fields) without duplicating string literals everywhere.
class CsvV2SpecExtensions {
  const CsvV2SpecExtensions._();

  /// Columns that describe the canonical OrganismRecord axes regardless of
  /// organism.
  static const List<String> axisColumns = [
    'provenanceType',
    'lifeStage',
    'lifeStageSubtype',
    'physicalFormId',
    'physicalForm',
    'sizeBandId',
    'measuredDimension',
    'dimensionUnit',
    'organismsPerUnit',
    'volumeAmount',
    'volumeUnit',
  ];

  // ============================================================
  // MINIMAL IMPORT COLUMNS (5-axis only)
  // These are the absolute minimum columns required for each import type.
  // Validation should focus only on these fields.
  // ============================================================

  /// Minimal columns for genetics/provenance import.
  /// Focuses on identity and provenance (2 of the 5 axes).
  static const List<String> minimalGeneticsInputs = [
    'organismKind',
    'speciesCode',
    'provenanceId',
    'provenanceKind', // or provenanceType
  ];

  /// Minimal columns for inventory import.
  /// Covers all 5 axes: Taxonomy, Provenance, Location, Life Stage, Measurement.
  static const List<String> minimalInventoryInputs = [
    'organismKind', // Taxonomy axis
    'speciesCode', // Taxonomy axis
    'localId', // Required identifier
    'recordName', // Required record label
    'provenanceId', // Provenance axis
    'lifeStage', // Life Stage axis
    'quantityValue', // Measurement axis
    'measurementUnit', // Measurement axis
    // Location axis: groupId (required)
  ];

  /// Location columns for inventory import - at least one must be provided.
  static const List<String> inventoryLocationInputs = [
    'groupId',
  ];

  /// Minimal columns for outplanting import.
  static const List<String> minimalOutplantingInputs = [
    'siteUrlPath', // Location axis
    'eventDate', // Event date
    'totalQuantity', // Measurement axis
    'provenanceId', // Provenance axis
  ];

  /// Minimal columns for monitoring import.
  static const List<String> minimalMonitoringInputs = [
    'monitoringDate', // Required event date
    'outplantEventId', // Required outplant event reference
    // At least one metric should be present, but not all required
  ];

  // ============================================================
  // LEGACY: Full required inputs (kept for backwards compatibility)
  // ============================================================

  /// Base columns that imports must provide before we can derive the canonical
  /// axis fields.
  /// @deprecated Use minimalInventoryInputs for simplified import validation.
  static const List<String> holdingRequiredInputs = [
    'organismKind',
    'speciesScientific',
    'speciesCode',
    'localId',
    'recordName',
    'lifeStage',
    'eventType',
    'eventDate',
    'measurementUnit',
    'quantityValue',
  ];

  /// Columns required for holding rows in addition to [axisColumns].
  static const List<String> holdingRequiredColumns = [
    ...holdingRequiredInputs,
    ...axisColumns,
  ];

  /// Aliases that travel with organism records so CSV pipelines keep canonical IDs.
  static const List<String> aliasColumns = [
    'aliasesJson',
    'aliases',
  ];

  /// Columns that must exist (even if blank) when exporting/importing holdings.
  static const List<String> holdingCanonicalColumns = [
    ...holdingRequiredColumns,
    'groupId',
    'siteId',
    'provenanceId',
    'cohortId',
    'structureType',
  ];

  /// Organism/identity columns shared across CSV v2 payloads.
  static const List<String> identityColumns = [
    'organismKind',
    'speciesScientific',
    'speciesCode',
    'speciesId',
    'localId',
    'recordName',
    'accessionId',
    'provenanceId',
    'provenanceKind',
    'provenanceLabel',
    'cohortId',
  ];

  /// Provenance metadata that rides along with the five-axis payload.
  static const List<String> provenanceColumns = [
    'provenanceType',
    'provenanceTypeLabel',
    'parentProvenanceIds',
  ];

  /// Measurement columns required to describe a holding’s population payload.
  static const List<String> quantityColumns = [
    'measurementUnit',
    'quantityValue',
    'qualityFlag',
  ];

  /// Site + enclosure metadata (minus geometry and permit sections).
  static const List<String> siteColumns = [
    'siteId',
    'siteName',
    'enclosureId',
    'groupId',
    'structureType',
    'inSituRow',
    'inSituCol',
    'lineId',
    'dropperId',
  ];

  /// Geometry columns used by exports/imports.
  static const List<String> geometryColumns = [
    'geometryFormat',
    'geometryWkt',
    'geometryGeojson',
    'geometrySource',
    'geometryUpdatedAt',
  ];

  /// Event metadata for compliance/audit trails.
  static const List<String> eventColumns = [
    'eventType',
    'eventDate',
    'eventTimeZone',
    'observer',
    'sourceSystem',
    'notes',
    'photoUrl',
  ];

  /// Permit block required for deployments/spawns tracked in CSV v2.
  static const List<String> permitColumns = [
    'permitId',
    'permitType',
    'issuingAuthority',
    'validFrom',
    'validTo',
    'siteJurisdiction',
    'habitatType',
    'protectedAreaFlag',
  ];

  /// MRV (Monitoring, Reporting, Verification) carbon accounting fields.
  static const List<String> mrvColumns = [
    'carbonPool.total',
    'carbonPool.aboveGround',
    'carbonPool.belowGround',
    'stockTCo2e',
    'fluxTCo2eYr',
    'uncertaintyPct',
    'permanenceRiskScore',
  ];

  /// CSR (Corporate Social Responsibility) metadata surfaced in templates.
  static const List<String> csrColumns = [
    'volunteerHours',
    'trainingHours',
    'credentialId',
    'irisMetricIds[]',
    'sdgTargets[]',
  ];

  /// Environmental panel columns shared across organisms.
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

  /// Organism-specific detail columns called out in the CSV spec.
  static const Map<String, List<String>> organismSpecificColumns = {
    'coral': [
      'bleachingState',
      'diseaseCode',
      'partialMortalityPct',
      'benthicCoverPct',
    ],
    'oyster': [
      'shellHeightMm',
      'oysterDensityPerM2',
      'reefAreaM2',
      'reefHeightCm',
    ],
    'kelp': [
      'lineBiomassKgPerM',
      'bladeLengthCm',
      'foulingIndex05',
      'grazingDamageIndex',
    ],
    'seagrass': [
      'shootDensityPerM2',
      'coverPctOrClass',
      'secchiDepthM',
    ],
    'mangrove': [
      'dbhCm',
      'heightCm',
      'survivalPct',
    ],
    'echinoid': [
      'densityPerM2',
    ],
    'crab': [
      'carapaceWidthMm',
      'weightG',
      'moltStage',
      'eggsVisibleBool',
      'eggColor',
      'eggCountEst',
      'feedType',
      'feedRatePctBw',
      'mortalityPct',
    ],
    'finfish': [
      'weightG',
      'lengthMm',
      'fcr',
      'releaseCount',
      'healthCertificateId',
    ],
  };

  /// Canonical inventory columns (union of organism/provenance, five-axis,
  /// site, permit, geometry, MRV/CSR).
  static final List<String> inventoryBaseColumns =
      List<String>.unmodifiable(_buildInventoryBaseColumns());

  static const List<String> inventoryMetricColumns = [
    'inventoryCount',
    'inventoryVolumeCm3',
    'inventoryTissueAreaCm2',
  ];

  static List<String> inventoryColumns({
    bool includeOrganismSpecific = true,
    OrganismKind? organismKind,
  }) {
    final ordered = LinkedHashSet<String>.from(inventoryBaseColumns);
    if (includeOrganismSpecific) {
      if (organismKind != null) {
        final specific = organismSpecificColumns[organismKind.name];
        if (specific != null) {
          ordered.addAll(specific);
        }
      } else {
        for (final columns in organismSpecificColumns.values) {
          ordered.addAll(columns);
        }
      }
    }
    return List<String>.unmodifiable(ordered);
  }

  static List<String> _buildInventoryBaseColumns() {
    final ordered = <String>{};
    void addAll(List<String> columns) {
      for (final column in columns) {
        if (column.isEmpty) continue;
        ordered.add(column);
      }
    }

    addAll(identityColumns);
    addAll(aliasColumns);
    addAll(provenanceColumns);
    addAll(axisColumns);
    addAll(quantityColumns);
    addAll(inventoryMetricColumns);
    addAll(siteColumns);
    addAll(geometryColumns);
    addAll(eventColumns);
    addAll(permitColumns);
    addAll(mrvColumns);
    addAll(csrColumns);
    addAll(environmentalPanelColumns);
    addAll(['notes', 'photoUrl']);
    return ordered.toList(growable: false);
  }
}
