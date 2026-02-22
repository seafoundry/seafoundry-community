// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/csv/v2/csv_v2_spec_extensions.dart';

// Canonical CSV schema metadata used by the import/export tooling. The intent
// is not to be exhaustive but to provide a single location where templates and
// their metadata (version, columns, etc.) live so that services can reason
// about supported versions.
//
// ---------------------------------------------------------------------------
// Canonical Column → ID Type Reference (Phase 2, Team Delta)
// ---------------------------------------------------------------------------
// Column Name           | ID Type              | Description
// ----------------------|----------------------|----------------------------
// organismId            | Firestore doc ID     | OrganismRecord document ID
// genetId               | Firestore doc ID     | Genet document ID
// provenanceId          | Lineage ID (PID-)    | Genet.provenanceId
// genetProvenanceId     | Lineage ID (PID-)    | Explicit genet lineage ID
// holdingId             | Firestore doc ID     | Holding document ID
// ---------------------------------------------------------------------------
// IMPORTANT: Do NOT use ambiguous aliases. Each column has exactly one
// expected ID type. Mixing doc IDs with provenance IDs causes import
// failures and data corruption.
// ---------------------------------------------------------------------------

enum CsvTemplateKind {
  genetics,
  inventory,
  inventoryMinimal,
  inventoryCoral,
  inventoryOyster,
  inventoryKelp,
  inventorySeagrass,
  inventoryMangrove,
  inventoryFinfish,
  inventoryCrab,
  outplanting,
  outplantAllocations,
  outplantConsolidated,
  monitoring,
  siteBaselines,
  husbandryObservations,
  husbandryTasks,
}

class CsvSchema {
  const CsvSchema({
    required this.kind,
    required this.version,
    required this.allColumns,
    this.metadataFields = const <String, String>{},
  });

  final CsvTemplateKind kind;
  final String version;
  final Map<String, String> metadataFields;
  final List<String> allColumns;
}

/// Canonical CSV column names with their expected ID types.
///
/// Use these constants instead of raw strings to prevent typos and
/// ensure consistent column naming across import/export pipelines.
class CsvColumnNames {
  CsvColumnNames._();

  // --- Firestore Document ID columns ---

  /// Firestore document ID for an OrganismRecord.
  /// Expected format: alphanumeric Firestore auto-ID (NOT a PID- lineage ID).
  static const String organismId = 'organismId';

  /// Firestore document ID for a Genet record.
  /// Expected format: alphanumeric Firestore auto-ID (NOT a PID- lineage ID).
  static const String genetId = 'genetId';

  /// Firestore document ID for a Holding record.
  /// Expected format: alphanumeric Firestore auto-ID (NOT a PID- lineage ID).
  static const String holdingId = 'holdingId';

  // --- Lineage ID columns ---

  /// Lineage identifier (Genet.provenanceId).
  /// Expected format: PID-Xxxx-NNN.
  static const String provenanceId = 'provenanceId';

  /// Explicit genet lineage identifier for linking organisms to genets.
  /// Expected format: PID-Xxxx-NNN.
  /// Use this column when the CSV needs to distinguish the organism's
  /// own provenanceId from the genet lineage reference.
  static const String genetProvenanceId = 'genetProvenanceId';

  /// Regular expression that matches provenance/lineage ID format.
  /// Values starting with PID- are lineage IDs, not Firestore doc IDs.
  static final RegExp provenanceIdPattern = RegExp(r'^PID-');

  /// Legacy provenance prefix that is no longer supported.
  static final RegExp legacyProvenanceIdPattern = RegExp(r'^SF-');

  /// Returns true if [value] looks like a provenance/lineage ID (PID- prefix).
  static bool isProvenanceIdFormat(String value) =>
      provenanceIdPattern.hasMatch(value.trim().toUpperCase());

  /// Returns true if [value] looks like a legacy provenance ID (SF- prefix).
  static bool isLegacyProvenanceIdFormat(String value) =>
      legacyProvenanceIdPattern.hasMatch(value.trim().toUpperCase());

  /// Returns true if [value] looks like a Firestore doc ID (not PID- prefix).
  static bool isDocIdFormat(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final normalized = trimmed.toUpperCase();
    return !provenanceIdPattern.hasMatch(normalized) &&
        !legacyProvenanceIdPattern.hasMatch(normalized);
  }
}

class CsvSchemas {
  CsvSchemas._();

  static const currentVersion = '2025.10';

  static const Map<String, String> _defaultMetadataFields = {
    'provenanceCsvVersion': 'Canonical template version',
    'provenanceCsvTemplate': 'Template identifier',
    'generatedAt': 'ISO8601 timestamp of export',
    'orgDomain': 'Organization domain of export',
    'provenanceTranslationAdapter':
        'Optional adapter identifier for partner mappings',
  };

  static const List<String> _geneticsColumns = <String>[
    'provenanceId',
    'name',
    'speciesId',
    'organismKind',
    'genetTypeId',
    'clonalId',
    'aliases',
    'parentGameteIds',
    'donorGenotypeId',
    'archived',
    'archivedAt',
    'provenance.habitatType',
    'provenance.collectionDate',
    'provenance.notes',
  ];

  // Note: inventoryColumns() already includes inventoryMetricColumns internally,
  // so we don't need to addAll separately. The returned list is unmodifiable.
  static final List<String> _inventoryColumns =
      CsvV2SpecExtensions.inventoryColumns();

  // Minimal inventory columns - just the 5-axis essentials for simple imports
  static const List<String> _inventoryMinimalColumns = <String>[
    'organismKind',
    'speciesCode',
    'localId',
    'recordName',
    'provenanceId',
    'lifeStage',
    'quantityValue',
    'measurementUnit',
    'groupId',
    'groupUrlPath',
    'eventDate',
    'notes',
  ];

  // Organism-specific inventory columns - filtered by organism kind
  static final List<String> _inventoryCoralColumns =
      CsvV2SpecExtensions.inventoryColumns(organismKind: OrganismKind.coral);
  static final List<String> _inventoryOysterColumns =
      CsvV2SpecExtensions.inventoryColumns(organismKind: OrganismKind.oyster);
  static final List<String> _inventoryKelpColumns =
      CsvV2SpecExtensions.inventoryColumns(organismKind: OrganismKind.kelp);
  static final List<String> _inventorySeagrassColumns =
      CsvV2SpecExtensions.inventoryColumns(organismKind: OrganismKind.seagrass);
  static final List<String> _inventoryMangroveColumns =
      CsvV2SpecExtensions.inventoryColumns(organismKind: OrganismKind.mangrove);
  static final List<String> _inventoryFinfishColumns =
      CsvV2SpecExtensions.inventoryColumns(organismKind: OrganismKind.finfish);
  static final List<String> _inventoryCrabColumns =
      CsvV2SpecExtensions.inventoryColumns(organismKind: OrganismKind.crab);

  static const List<String> _outplantColumns = <String>[
    'eventId',
    'siteUrlPath',
    'eventDate',
    'totalQuantity',
    'allocations',
    'deductFromInventory',
    'notes',
    'permitType',
    'permitId',
    'issuingAuthority',
    'validFrom',
    'validTo',
    'permitAttachmentUrls',
    'siteJurisdiction',
    'habitatType',
    'protectedAreaFlag',
    'geometryType',
    'geometryCoordinates',
    'geometrySource',
    'geometryKmlStoragePath',
    'geometryUpdatedAt',
  ];

  static const List<String> _outplantAllocationColumns = <String>[
    'eventId',
    'allocationIndex',
    'organismId',
    'recordName',
    'quantity',
    'allocationVolumeCm3',
    'allocationTissueAreaCm2',
    'sourcePath',
    'tagId',
    'tagName',
    'tagPath',
  ];

  /// Consolidated outplant template (v2025.11) - flat row-per-allocation format.
  /// Event-level fields are duplicated per row; first occurrence is canonical.
  static const List<String> _outplantConsolidatedColumns = <String>[
    // Event-level (duplicated per row, first occurrence canonical)
    'eventId', // Required, groups rows
    'eventDate', // Required, ISO-8601
    'siteName', // Required, human-readable
    'eventNotes', // Optional

    // Allocation-level (unique per row)
    'structureName', // Optional, substructure
    'localId', // Required, links to inventory
    'recordName', // Optional, display name
    'quantity', // Required, positive integer
    'tagId', // Optional
  ];

  static const List<String> _monitoringColumns = <String>[
    'eventId',
    'outplantEventId',
    'siteUrlPath',
    'monitoringDate',
    'percentCover',
    'percentBleaching',
    'percentDisease',
    'healthIssueTypeId',
    'imageUrl',
    'notes',
    'ageDays',
    'ageMonths',
    'tagId',
    'recordName',
    'physicalFormId',
    'sizeBandId',
    'estimatedVolumeMm3',
    'growthDeltaMm3',
    'growthPercentChange',
    'growthPerDayMm3',
  ];

  static const List<String> _siteBaselineColumns = <String>[
    'siteId',
    'siteName',
    'siteUrlPath',
    'siteType',
    'organismKind',
    'temperatureC',
    'salinityPsu',
    'dissolvedOxygenMgL',
    'baselineNotes',
    'baselineUpdatedAt',
    'baselineUpdatedBy',
    'metricsJson',
  ];

  static const List<String> _husbandryObservationColumns = <String>[
    'eventId',
    'recordModelType',
    'recordId',
    'recordPath',
    'observedAt',
    'observedBy',
    'observationType',
    'comment',
    'healthIssueTypeId',
    'oldHealthStatus',
    'newHealthStatus',
    'imageUrl',
    'followUpTaskId',
  ];

  static const List<String> _husbandryTaskColumns = <String>[
    'eventId',
    'recordModelType',
    'recordId',
    'recordPath',
    'title',
    'description',
    'husbandryActionTypeId',
    'priorityId',
    'assignedRoleId',
    'assignedUserId',
    'deadline',
    'completedAt',
    'completedById',
    'createdAt',
    'updatedAt',
    'notes',
    'sourceObservationId',
  ];

  static final CsvSchema genetics = CsvSchema(
    kind: CsvTemplateKind.genetics,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _geneticsColumns,
  );

  static final CsvSchema inventory = CsvSchema(
    kind: CsvTemplateKind.inventory,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryColumns,
  );

  static final CsvSchema inventoryMinimal = CsvSchema(
    kind: CsvTemplateKind.inventoryMinimal,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryMinimalColumns,
  );

  static final CsvSchema inventoryCoral = CsvSchema(
    kind: CsvTemplateKind.inventoryCoral,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryCoralColumns,
  );

  static final CsvSchema inventoryOyster = CsvSchema(
    kind: CsvTemplateKind.inventoryOyster,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryOysterColumns,
  );

  static final CsvSchema inventoryKelp = CsvSchema(
    kind: CsvTemplateKind.inventoryKelp,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryKelpColumns,
  );

  static final CsvSchema inventorySeagrass = CsvSchema(
    kind: CsvTemplateKind.inventorySeagrass,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventorySeagrassColumns,
  );

  static final CsvSchema inventoryMangrove = CsvSchema(
    kind: CsvTemplateKind.inventoryMangrove,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryMangroveColumns,
  );

  static final CsvSchema inventoryFinfish = CsvSchema(
    kind: CsvTemplateKind.inventoryFinfish,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryFinfishColumns,
  );

  static final CsvSchema inventoryCrab = CsvSchema(
    kind: CsvTemplateKind.inventoryCrab,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _inventoryCrabColumns,
  );

  static final CsvSchema outplanting = CsvSchema(
    kind: CsvTemplateKind.outplanting,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _outplantColumns,
  );

  static final CsvSchema outplantAllocations = CsvSchema(
    kind: CsvTemplateKind.outplantAllocations,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _outplantAllocationColumns,
  );

  /// Consolidated outplant template introduced in v2025.11.
  static final CsvSchema outplantConsolidated = CsvSchema(
    kind: CsvTemplateKind.outplantConsolidated,
    version: '2025.11',
    metadataFields: _defaultMetadataFields,
    allColumns: _outplantConsolidatedColumns,
  );

  static final CsvSchema monitoring = CsvSchema(
    kind: CsvTemplateKind.monitoring,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _monitoringColumns,
  );

  static final CsvSchema siteBaselines = CsvSchema(
    kind: CsvTemplateKind.siteBaselines,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _siteBaselineColumns,
  );

  static final CsvSchema husbandryObservations = CsvSchema(
    kind: CsvTemplateKind.husbandryObservations,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _husbandryObservationColumns,
  );

  static final CsvSchema husbandryTasks = CsvSchema(
    kind: CsvTemplateKind.husbandryTasks,
    version: currentVersion,
    metadataFields: _defaultMetadataFields,
    allColumns: _husbandryTaskColumns,
  );

  static final List<CsvSchema> all = <CsvSchema>[
    genetics,
    inventory,
    inventoryMinimal,
    inventoryCoral,
    inventoryOyster,
    inventoryKelp,
    inventorySeagrass,
    inventoryMangrove,
    inventoryFinfish,
    inventoryCrab,
    outplanting,
    outplantAllocations,
    outplantConsolidated,
    monitoring,
    siteBaselines,
    husbandryObservations,
    husbandryTasks,
  ];

  static CsvSchema schemaForKind(CsvTemplateKind kind) {
    return all.firstWhere((schema) => schema.kind == kind);
  }
}
