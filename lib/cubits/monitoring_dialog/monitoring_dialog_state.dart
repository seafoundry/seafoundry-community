// @tier: community
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/models.dart';

/// Immutable state consumed by [MonitoringDialog] & its cubit. Tracks site /
/// outplant selections, per-organism inputs, pending image attachments, and
/// async-loading flags so the UI can rebuild deterministically.
class MonitoringDialogState extends Equatable {
  const MonitoringDialogState({
    required this.organismContext,
    this.selectedSite,
    this.selectedOutplanting,
    this.organismsToMonitor = const [],
    this.healthStatuses = const {},
    this.createTasks = const {},
    this.isLoadingOrganisms = false,
    this.initialSiteId,
    this.referenceOutplantEvent,
    this.prefilledGeometry,
    this.appliedInitialSite = false,
    this.globalComment = '',
    this.percentCover = '',
    this.percentBleaching = '',
    this.percentDisease = '',
    this.comments = const {},
    this.tags = const {},
    this.pendingImageFiles = const [],
    this.pendingImageSelections = const {},
    this.error,
    this.isLoading = false,
    this.availableSites = const [],
    this.availableOutplantEvents = const [],
    this.isLoadingSites = false,
    this.isLoadingOutplantEvents = false,
    this.siteBaseline,
    this.baselineDraft = kMonitoringBaselineEmptyDraft,
    this.siteBaselineEnabled = false,
    this.isLoadingBaseline = false,
    this.isSavingBaseline = false,
    this.baselineError,
    this.permitId = '',
    this.permitType = '',
    this.permitIssuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
  });

  final OrganismContext organismContext;
  final Site? selectedSite;
  final OutplantEvent? selectedOutplanting;
  final List<OrganismMonitoringCandidate> organismsToMonitor;
  final Map<String, HealthStatus?> healthStatuses;
  final Map<String, bool> createTasks;
  final bool isLoadingOrganisms;
  final String? initialSiteId;
  final OutplantEvent? referenceOutplantEvent;
  final OutplantGeometry? prefilledGeometry;
  final bool appliedInitialSite;
  final String globalComment;
  final String percentCover;
  final String percentBleaching;
  final String percentDisease;
  final Map<String, String> comments;
  final Map<String, String> tags;
  final List<File> pendingImageFiles;
  final Map<int, ImageAttachmentSelection> pendingImageSelections;
  final String? error;
  final bool isLoading;
  final List<Site> availableSites;
  final List<OutplantEvent> availableOutplantEvents;
  final bool isLoadingSites;
  final bool isLoadingOutplantEvents;
  final SiteBaseline? siteBaseline;
  final Map<String, String> baselineDraft;
  final bool siteBaselineEnabled;
  final bool isLoadingBaseline;
  final bool isSavingBaseline;
  final String? baselineError;
  final String permitId;
  final String permitType;
  final String permitIssuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;

  bool get hasPermitMetadata =>
      permitId.trim().isNotEmpty ||
      permitType.trim().isNotEmpty ||
      permitIssuingAuthority.trim().isNotEmpty ||
      permitAttachmentUrls.trim().isNotEmpty ||
      permitValidFrom != null ||
      permitValidTo != null;

  bool get baselineHasChanges => !monitoringBaselineDraftEquals(
    baselineDraft,
    monitoringBaselineDraftFrom(siteBaseline),
  );

  MonitoringDialogState copyWith({
    OrganismContext? organismContext,
    Site? selectedSite,
    OutplantEvent? selectedOutplanting,
    List<OrganismMonitoringCandidate>? organismsToMonitor,
    Map<String, HealthStatus?>? healthStatuses,
    Map<String, bool>? createTasks,
    bool? isLoadingOrganisms,
    String? initialSiteId,
    OutplantEvent? referenceOutplantEvent,
    OutplantGeometry? prefilledGeometry,
    bool? appliedInitialSite,
    String? globalComment,
    String? percentCover,
    String? percentBleaching,
    String? percentDisease,
    Map<String, String>? comments,
    Map<String, String>? tags,
    List<File>? pendingImageFiles,
    Map<int, ImageAttachmentSelection>? pendingImageSelections,
    String? error,
    bool? isLoading,
    bool clearError = false,
    bool clearOrganisms = false,
    bool resetSelectedOutplanting = false,
    bool resetPrefilledGeometry = false,
    List<Site>? availableSites,
    List<OutplantEvent>? availableOutplantEvents,
    bool? isLoadingSites,
    bool? isLoadingOutplantEvents,
    SiteBaseline? siteBaseline,
    bool setSiteBaseline = false,
    Map<String, String>? baselineDraft,
    bool? siteBaselineEnabled,
    bool? isLoadingBaseline,
    bool? isSavingBaseline,
    String? baselineError,
    bool clearBaselineError = false,
    String? permitId,
    String? permitType,
    String? permitIssuingAuthority,
    String? permitAttachmentUrls,
    Object? permitValidFrom = _sentinel,
    Object? permitValidTo = _sentinel,
  }) {
    final shouldClear = clearOrganisms;
    final clearedStatuses = shouldClear ? <String, HealthStatus?>{} : null;
    final clearedTasks = shouldClear ? <String, bool>{} : null;
    final clearedComments = shouldClear ? <String, String>{} : null;
    final clearedTags = shouldClear ? <String, String>{} : null;
    final nextSelectedOutplanting = resetSelectedOutplanting
        ? null
        : selectedOutplanting ?? this.selectedOutplanting;
    final nextPrefilledGeometry = resetPrefilledGeometry
        ? null
        : prefilledGeometry ?? this.prefilledGeometry;

    return MonitoringDialogState(
      organismContext: organismContext ?? this.organismContext,
      selectedSite: selectedSite ?? this.selectedSite,
      selectedOutplanting: nextSelectedOutplanting,
      organismsToMonitor: clearOrganisms
          ? []
          : (organismsToMonitor ?? this.organismsToMonitor),
      healthStatuses: clearedStatuses ?? healthStatuses ?? this.healthStatuses,
      createTasks: clearedTasks ?? createTasks ?? this.createTasks,
      isLoadingOrganisms: isLoadingOrganisms ?? this.isLoadingOrganisms,
      initialSiteId: initialSiteId ?? this.initialSiteId,
      referenceOutplantEvent:
          referenceOutplantEvent ?? this.referenceOutplantEvent,
      prefilledGeometry: nextPrefilledGeometry,
      appliedInitialSite: appliedInitialSite ?? this.appliedInitialSite,
      globalComment: globalComment ?? this.globalComment,
      percentCover: percentCover ?? this.percentCover,
      percentBleaching: percentBleaching ?? this.percentBleaching,
      percentDisease: percentDisease ?? this.percentDisease,
      comments: clearedComments ?? comments ?? this.comments,
      tags: clearedTags ?? tags ?? this.tags,
      pendingImageFiles: pendingImageFiles ?? this.pendingImageFiles,
      pendingImageSelections:
          pendingImageSelections ?? this.pendingImageSelections,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      availableSites: availableSites ?? this.availableSites,
      availableOutplantEvents:
          availableOutplantEvents ?? this.availableOutplantEvents,
      isLoadingSites: isLoadingSites ?? this.isLoadingSites,
      isLoadingOutplantEvents:
          isLoadingOutplantEvents ?? this.isLoadingOutplantEvents,
      siteBaseline: setSiteBaseline ? siteBaseline : this.siteBaseline,
      baselineDraft: baselineDraft ?? this.baselineDraft,
      siteBaselineEnabled: siteBaselineEnabled ?? this.siteBaselineEnabled,
      isLoadingBaseline: isLoadingBaseline ?? this.isLoadingBaseline,
      isSavingBaseline: isSavingBaseline ?? this.isSavingBaseline,
      baselineError: clearBaselineError
          ? null
          : (baselineError ?? this.baselineError),
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      permitIssuingAuthority:
          permitIssuingAuthority ?? this.permitIssuingAuthority,
      permitAttachmentUrls: permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: permitValidFrom == _sentinel
          ? this.permitValidFrom
          : permitValidFrom as DateTime?,
      permitValidTo: permitValidTo == _sentinel
          ? this.permitValidTo
          : permitValidTo as DateTime?,
    );
  }

  bool get hasChanges {
    // Check if there are any health status changes
    final hasStatusChanges = healthStatuses.values.any((s) => s != null);

    // Check if there are any comments
    final hasComments =
        comments.values.any((c) => c.trim().isNotEmpty) ||
        globalComment.trim().isNotEmpty;

    // Check for tag edits
    bool tagEdited = false;
    for (final candidate in organismsToMonitor) {
      final tagValue = tags[candidate.organism.id]?.trim() ?? '';
      final defaultTag = candidate.defaultTag?.trim() ?? '';
      if ((tagValue.isNotEmpty) != (defaultTag.isNotEmpty) ||
          tagValue != defaultTag) {
        tagEdited = true;
        break;
      }
    }

    return hasStatusChanges || hasComments || tagEdited;
  }

  @override
  List<Object?> get props => [
    organismContext,
    selectedSite,
    selectedOutplanting,
    organismsToMonitor,
    healthStatuses,
    createTasks,
    isLoadingOrganisms,
    initialSiteId,
    referenceOutplantEvent,
    prefilledGeometry,
    appliedInitialSite,
    globalComment,
    percentCover,
    percentBleaching,
    percentDisease,
    comments,
    tags,
    pendingImageFiles,
    pendingImageSelections,
    error,
    isLoading,
    availableSites,
    availableOutplantEvents,
    isLoadingSites,
    isLoadingOutplantEvents,
    siteBaseline,
    baselineDraft,
    siteBaselineEnabled,
    isLoadingBaseline,
    isSavingBaseline,
    baselineError,
    permitId,
    permitType,
    permitIssuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
  ];
}

const _sentinel = Object();

const List<String> kMonitoringBaselineMetricKeys = [
  'temperatureC',
  'salinityPsu',
  'dissolvedOxygenMgL',
];

const String kMonitoringBaselineNotesKey = 'notes';

const Map<String, String> kMonitoringBaselineEmptyDraft = {
  'temperatureC': '',
  'salinityPsu': '',
  'dissolvedOxygenMgL': '',
  'notes': '',
};

Map<String, String> monitoringBaselineDraftFrom(SiteBaseline? baseline) {
  final draft = Map<String, String>.from(kMonitoringBaselineEmptyDraft);
  if (baseline == null) {
    return draft;
  }
  for (final key in kMonitoringBaselineMetricKeys) {
    draft[key] = _stringifyBaselineMetric(baseline.metrics[key]);
  }
  draft[kMonitoringBaselineNotesKey] = baseline.notes ?? '';
  return draft;
}

bool monitoringBaselineDraftEquals(
  Map<String, String> a,
  Map<String, String> b,
) {
  for (final key in [
    ...kMonitoringBaselineMetricKeys,
    kMonitoringBaselineNotesKey,
  ]) {
    final left = (a[key] ?? '').trim();
    final right = (b[key] ?? '').trim();
    if (left != right) {
      return false;
    }
  }
  return true;
}

String _stringifyBaselineMetric(dynamic value) {
  if (value == null) return '';
  if (value is num) return value.toString();
  return value.toString();
}

/// Selection data for associating an image with organisms/groups.
class ImageAttachmentSelection extends Equatable {
  const ImageAttachmentSelection({
    this.coralIds = const [],
    this.groupIds = const [],
    this.tagIds = const [],
    this.isOrthomosaic = false,
    this.description,
  });

  final List<String> coralIds;
  final List<String> groupIds;
  final List<String> tagIds;
  final bool isOrthomosaic;
  final String? description;

  /// Returns true if this selection has specific targets (organisms/groups/tags).
  bool get hasSpecificTargets =>
      coralIds.isNotEmpty || groupIds.isNotEmpty || tagIds.isNotEmpty;

  ImageAttachmentSelection copyWith({
    List<String>? coralIds,
    List<String>? groupIds,
    List<String>? tagIds,
    bool? isOrthomosaic,
    String? description,
  }) {
    return ImageAttachmentSelection(
      coralIds: coralIds ?? this.coralIds,
      groupIds: groupIds ?? this.groupIds,
      tagIds: tagIds ?? this.tagIds,
      isOrthomosaic: isOrthomosaic ?? this.isOrthomosaic,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [
    coralIds,
    groupIds,
    tagIds,
    isOrthomosaic,
    description,
  ];
}

/// Candidate organism presented in the monitoring dialog before submission.
class OrganismMonitoringCandidate {
  final OrganismRecord organism;
  final String? defaultTag;
  final String? physicalForm;
  final String? morphologyId;
  final HealthStatus? currentHealthStatus;
  final Map<String, dynamic> seededMeasurements;
  final bool forceSubmission;

  const OrganismMonitoringCandidate({
    required this.organism,
    this.defaultTag,
    this.physicalForm,
    this.morphologyId,
    this.currentHealthStatus,
    Map<String, dynamic>? seededMeasurements,
    this.forceSubmission = false,
  }) : seededMeasurements = seededMeasurements ?? const {};
}

/// Observation payload processed during batch submission.
class MonitoringObservationItem {
  final OrganismRecord organism;
  final OrganismMonitoringData observation;

  const MonitoringObservationItem({
    required this.organism,
    required this.observation,
  });
}
