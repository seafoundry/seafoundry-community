import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/inventory/life_stage_transition_reason.dart';
import 'package:seafoundry_app/models/inventory/local_id_edit_scope.dart';
import 'package:seafoundry_app/models/inventory/physical_form_change_reason.dart';
import 'package:seafoundry_app/models/inventory/quantity_change.dart';
import 'package:seafoundry_app/services/identity_edit_service.dart';
import 'package:seafoundry_app/services/measurement_metrics_service.dart';
import 'package:seafoundry_app/services/organism_record_change_service.dart';

typedef OrganismRecordSaveCallback =
    Future<void> Function(
      OrganismRecord updatedRecord, {
      Map<String, dynamic>? eventMetadata,
    });

class OrganismRecordEditState extends Equatable {
  const OrganismRecordEditState({
    required this.originalRecord,
    required this.pendingRecord,
    required this.allowedFormIds,
    required this.changeSet,
    required this.quantityKind,
    required this.quantityUnit,
    required this.aliasEntries,
    this.currentOrganizationId,
    this.localIdOverride,
    this.recordNameOverride,
    this.lifeStageOverride,
    this.lifeStageReason,
    this.lifeStageValidationMessage,
    this.formIdOverride,
    this.physicalFormChangeReason,
    this.physicalFormValidationMessage,
    this.sizeClassOverride,
    this.measuredDimensionOverride,
    this.dimensionUnitOverride,
    this.sizeValidationMessage,
    this.countOverride,
    this.measurementFieldConfig,
    this.quantityOverride,
    this.quantityUnitOverride,
    this.quantityReason,
    this.mortalityReason,
    this.quantityComment,
    this.quantityValidationMessage,
    this.isSubmitting = false,
    this.submissionError,
    this.submissionSucceeded = false,
    this.minimumStageInterval,
    this.lastTransitionAt,
    this.underlyingGenet,
    this.clonalIdOverride,
    this.accessionNumberOverride,
    this.aliasIdOverride,
    this.provenanceIdOverride,
    this.selectedGenetOverride,
    this.provenanceSearch = const ProvenanceSearchState(),
    this.transferLockInfo = const TransferLockInfo(),
    this.externalAssociationInfo = const ExternalAssociationInfo(
      hasExternalAssociations: false,
    ),
    this.localIdConflictError,
    this.previewedNewPid,
    this.isLoadingPidPreview = false,
    this.pendingLocalIdScope,
    this.genetWideUpdateCount,
    this.genetWideUpdateWarning,
  });

  final OrganismRecord originalRecord;
  final OrganismRecord pendingRecord;
  final List<String> allowedFormIds;
  final OrganismRecordChangeSet changeSet;
  final List<GenetAliasEntry> aliasEntries;

  /// Override for the localGenetId (genet identifier, e.g., "ACER-001").
  /// Maps to PID and by association to clonalID/alias/accession.
  final String? localIdOverride;

  /// Override for the tagId (user-friendly distinguishing name, e.g., "Fluffy").
  /// Used to distinguish between multiple organism records of the same genet.
  final String? recordNameOverride;

  final LifeStage? lifeStageOverride;
  final LifeStageTransitionReason? lifeStageReason;
  final String? lifeStageValidationMessage;

  final String? formIdOverride;
  final PhysicalFormChangeReason? physicalFormChangeReason;
  final String? physicalFormValidationMessage;

  final String? sizeClassOverride;
  final double? measuredDimensionOverride;
  final MeasurementUnit? dimensionUnitOverride;
  final String? sizeValidationMessage;

  // Count metric override
  final int? countOverride;
  final MeasurementFieldConfig? measurementFieldConfig;

  final QuantityChangeKind quantityKind;
  final double? quantityOverride;
  final MeasurementUnit quantityUnit;
  final MeasurementUnit? quantityUnitOverride;
  final QuantityChangeReason? quantityReason;
  final PopulationLossReason? mortalityReason;
  final String? quantityComment;
  final String? quantityValidationMessage;

  final bool isSubmitting;
  final bool submissionSucceeded;
  final String? submissionError;

  final Duration? minimumStageInterval;
  final DateTime? lastTransitionAt;

  // Genet / Provenance fields
  final Genet? underlyingGenet;
  final String? clonalIdOverride;
  final String? accessionNumberOverride;
  final String? aliasIdOverride;
  final String? provenanceIdOverride;
  final Genet? selectedGenetOverride;
  final ProvenanceSearchState provenanceSearch;

  /// Transfer lock information for identity fields.
  final TransferLockInfo transferLockInfo;

  /// External association information for warning dialogs.
  final ExternalAssociationInfo externalAssociationInfo;

  /// Error message when localID conflicts with existing records.
  final String? localIdConflictError;

  /// Previewed new PID that will be generated if a new genet is created.
  final String? previewedNewPid;

  /// Whether the PID preview is currently loading.
  final bool isLoadingPidPreview;

  /// The scope for applying localID changes (record-only or genet-wide).
  /// Only set when user explicitly chooses a scope via the scope dialog.
  final LocalIdEditScope? pendingLocalIdScope;

  /// Number of records updated during genet-wide localID update.
  /// Set after successful genet-wide update to show in success message.
  final int? genetWideUpdateCount;

  /// Warning message when genet-wide update fails but record save succeeded.
  /// Displayed to user so they know to manually update remaining records.
  final String? genetWideUpdateWarning;

  /// Whether identity fields are locked due to transfer metadata.
  bool get isIdentityLocked => transferLockInfo.isLocked;

  /// The current user's organization ID (kept for legacy state shape).
  final String? currentOrganizationId;

  bool get hasLocalIdChange => localIdOverride != null;
  bool get hasRecordNameChange => recordNameOverride != null;
  bool get hasLifeStageChange => lifeStageOverride != null;
  bool get hasPhysicalFormChange => formIdOverride != null;
  bool get hasSizeChange =>
      sizeClassOverride != null ||
      measuredDimensionOverride != null ||
      dimensionUnitOverride != null;
  bool get hasMetricsChange => countOverride != null;
  bool get hasQuantityChange =>
      quantityOverride != null || quantityUnitOverride != null;

  bool get hasProvenanceChange =>
      clonalIdOverride != null ||
      accessionNumberOverride != null ||
      aliasIdOverride != null ||
      provenanceIdOverride != null ||
      provenanceSearch.resolvedProvenanceId != null ||
      selectedGenetOverride != null &&
          selectedGenetOverride?.id != underlyingGenet?.id;

  /// Whether the organism has no genet assigned and needs one selected.
  /// A genet is considered assigned if:
  /// - There's a selected genet override, OR
  /// - There's a localGenetId override, OR
  /// - There's an underlying genet, OR
  /// - The original record has a localGenetId
  bool get isMissingGenet =>
      selectedGenetOverride == null &&
      localIdOverride == null &&
      underlyingGenet == null &&
      originalRecord.localGenetId == null;

  bool get canSubmit =>
      changeSet.hasChanges && !_hasBlockingValidation && !isSubmitting;

  /// Only block submission when there's a validation error for an actual change.
  /// This prevents stale validation messages from blocking unrelated edits.
  /// Also blocks when no genet is assigned (localGenetId is required).
  bool get _hasBlockingValidation =>
      isMissingGenet ||
      (hasLifeStageChange && lifeStageValidationMessage != null) ||
      (hasPhysicalFormChange && physicalFormValidationMessage != null) ||
      (hasSizeChange && sizeValidationMessage != null) ||
      (hasQuantityChange && quantityValidationMessage != null) ||
      (hasLocalIdChange && localIdConflictError != null);

  OrganismRecordEditState copyWith({
    OrganismRecord? pendingRecord,
    List<String>? allowedFormIds,
    List<GenetAliasEntry>? aliasEntries,
    Object? localIdOverride = _sentinel,
    Object? recordNameOverride = _sentinel,
    Object? lifeStageOverride = _sentinel,
    Object? lifeStageReason = _sentinel,
    Object? lifeStageValidationMessage = _sentinel,
    Object? formIdOverride = _sentinel,
    Object? physicalFormChangeReason = _sentinel,
    Object? physicalFormValidationMessage = _sentinel,
    Object? sizeClassOverride = _sentinel,
    Object? measuredDimensionOverride = _sentinel,
    Object? dimensionUnitOverride = _sentinel,
    Object? sizeValidationMessage = _sentinel,
    Object? countOverride = _sentinel,
    Object? measurementFieldConfig = _sentinel,
    QuantityChangeKind? quantityKind,
    Object? quantityOverride = _sentinel,
    MeasurementUnit? quantityUnit,
    Object? quantityUnitOverride = _sentinel,
    Object? quantityReason = _sentinel,
    Object? mortalityReason = _sentinel,
    Object? quantityComment = _sentinel,
    Object? quantityValidationMessage = _sentinel,
    bool? isSubmitting,
    bool? submissionSucceeded,
    Object? submissionError = _sentinel,
    OrganismRecordChangeSet? changeSet,
    Object? minimumStageInterval = _sentinel,
    Object? lastTransitionAt = _sentinel,
    Object? underlyingGenet = _sentinel,
    Object? clonalIdOverride = _sentinel,
    Object? accessionNumberOverride = _sentinel,
    Object? aliasIdOverride = _sentinel,
    Object? provenanceIdOverride = _sentinel,
    Object? selectedGenetOverride = _sentinel,
    ProvenanceSearchState? provenanceSearch,
    TransferLockInfo? transferLockInfo,
    ExternalAssociationInfo? externalAssociationInfo,
    Object? localIdConflictError = _sentinel,
    Object? previewedNewPid = _sentinel,
    bool? isLoadingPidPreview,
    Object? pendingLocalIdScope = _sentinel,
    Object? genetWideUpdateCount = _sentinel,
    Object? genetWideUpdateWarning = _sentinel,
  }) {
    return OrganismRecordEditState(
      originalRecord: originalRecord,
      pendingRecord: pendingRecord ?? this.pendingRecord,
      allowedFormIds: allowedFormIds ?? this.allowedFormIds,
      aliasEntries: aliasEntries ?? this.aliasEntries,
      currentOrganizationId: currentOrganizationId,
      localIdOverride: localIdOverride == _sentinel
          ? this.localIdOverride
          : localIdOverride as String?,
      recordNameOverride: recordNameOverride == _sentinel
          ? this.recordNameOverride
          : recordNameOverride as String?,
      changeSet: changeSet ?? this.changeSet,
      lifeStageOverride: lifeStageOverride == _sentinel
          ? this.lifeStageOverride
          : lifeStageOverride as LifeStage?,
      lifeStageReason: lifeStageReason == _sentinel
          ? this.lifeStageReason
          : lifeStageReason as LifeStageTransitionReason?,
      lifeStageValidationMessage: lifeStageValidationMessage == _sentinel
          ? this.lifeStageValidationMessage
          : lifeStageValidationMessage as String?,
      formIdOverride: formIdOverride == _sentinel
          ? this.formIdOverride
          : formIdOverride as String?,
      physicalFormChangeReason: physicalFormChangeReason == _sentinel
          ? this.physicalFormChangeReason
          : physicalFormChangeReason as PhysicalFormChangeReason?,
      physicalFormValidationMessage: physicalFormValidationMessage == _sentinel
          ? this.physicalFormValidationMessage
          : physicalFormValidationMessage as String?,
      sizeClassOverride: sizeClassOverride == _sentinel
          ? this.sizeClassOverride
          : sizeClassOverride as String?,
      measuredDimensionOverride: measuredDimensionOverride == _sentinel
          ? this.measuredDimensionOverride
          : measuredDimensionOverride as double?,
      dimensionUnitOverride: dimensionUnitOverride == _sentinel
          ? this.dimensionUnitOverride
          : dimensionUnitOverride as MeasurementUnit?,
      sizeValidationMessage: sizeValidationMessage == _sentinel
          ? this.sizeValidationMessage
          : sizeValidationMessage as String?,
      countOverride: countOverride == _sentinel
          ? this.countOverride
          : countOverride as int?,
      measurementFieldConfig: measurementFieldConfig == _sentinel
          ? this.measurementFieldConfig
          : measurementFieldConfig as MeasurementFieldConfig?,
      quantityKind: quantityKind ?? this.quantityKind,
      quantityOverride: quantityOverride == _sentinel
          ? this.quantityOverride
          : quantityOverride as double?,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      quantityUnitOverride: quantityUnitOverride == _sentinel
          ? this.quantityUnitOverride
          : quantityUnitOverride as MeasurementUnit?,
      quantityReason: quantityReason == _sentinel
          ? this.quantityReason
          : quantityReason as QuantityChangeReason?,
      mortalityReason: mortalityReason == _sentinel
          ? this.mortalityReason
          : mortalityReason as PopulationLossReason?,
      quantityComment: quantityComment == _sentinel
          ? this.quantityComment
          : quantityComment as String?,
      quantityValidationMessage: quantityValidationMessage == _sentinel
          ? this.quantityValidationMessage
          : quantityValidationMessage as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionSucceeded: submissionSucceeded ?? this.submissionSucceeded,
      submissionError: submissionError == _sentinel
          ? this.submissionError
          : submissionError as String?,
      minimumStageInterval: minimumStageInterval == _sentinel
          ? this.minimumStageInterval
          : minimumStageInterval as Duration?,
      lastTransitionAt: lastTransitionAt == _sentinel
          ? this.lastTransitionAt
          : lastTransitionAt as DateTime?,
      underlyingGenet: underlyingGenet == _sentinel
          ? this.underlyingGenet
          : underlyingGenet as Genet?,
      clonalIdOverride: clonalIdOverride == _sentinel
          ? this.clonalIdOverride
          : clonalIdOverride as String?,
      accessionNumberOverride: accessionNumberOverride == _sentinel
          ? this.accessionNumberOverride
          : accessionNumberOverride as String?,
      aliasIdOverride: aliasIdOverride == _sentinel
          ? this.aliasIdOverride
          : aliasIdOverride as String?,
      provenanceIdOverride: provenanceIdOverride == _sentinel
          ? this.provenanceIdOverride
          : provenanceIdOverride as String?,
      selectedGenetOverride: selectedGenetOverride == _sentinel
          ? this.selectedGenetOverride
          : selectedGenetOverride as Genet?,
      provenanceSearch: provenanceSearch ?? this.provenanceSearch,
      transferLockInfo: transferLockInfo ?? this.transferLockInfo,
      externalAssociationInfo:
          externalAssociationInfo ?? this.externalAssociationInfo,
      localIdConflictError: localIdConflictError == _sentinel
          ? this.localIdConflictError
          : localIdConflictError as String?,
      previewedNewPid: previewedNewPid == _sentinel
          ? this.previewedNewPid
          : previewedNewPid as String?,
      isLoadingPidPreview: isLoadingPidPreview ?? this.isLoadingPidPreview,
      pendingLocalIdScope: pendingLocalIdScope == _sentinel
          ? this.pendingLocalIdScope
          : pendingLocalIdScope as LocalIdEditScope?,
      genetWideUpdateCount: genetWideUpdateCount == _sentinel
          ? this.genetWideUpdateCount
          : genetWideUpdateCount as int?,
      genetWideUpdateWarning: genetWideUpdateWarning == _sentinel
          ? this.genetWideUpdateWarning
          : genetWideUpdateWarning as String?,
    );
  }

  @override
  List<Object?> get props => [
    originalRecord,
    pendingRecord,
    allowedFormIds,
    changeSet,
    lifeStageOverride,
    lifeStageReason,
    lifeStageValidationMessage,
    formIdOverride,
    physicalFormChangeReason,
    physicalFormValidationMessage,
    sizeClassOverride,
    measuredDimensionOverride,
    dimensionUnitOverride,
    sizeValidationMessage,
    countOverride,
    measurementFieldConfig,
    quantityKind,
    quantityOverride,
    quantityUnit,
    quantityUnitOverride,
    quantityReason,
    mortalityReason,
    quantityComment,
    quantityValidationMessage,
    isSubmitting,
    submissionSucceeded,
    submissionError,
    minimumStageInterval,
    lastTransitionAt,
    aliasEntries,
    currentOrganizationId,
    localIdOverride,
    recordNameOverride,
    underlyingGenet,
    clonalIdOverride,
    accessionNumberOverride,
    aliasIdOverride,
    provenanceIdOverride,
    selectedGenetOverride,
    provenanceSearch,
    transferLockInfo,
    externalAssociationInfo,
    localIdConflictError,
    previewedNewPid,
    isLoadingPidPreview,
    pendingLocalIdScope,
    genetWideUpdateCount,
    genetWideUpdateWarning,
  ];
}

const _sentinel = Object();
