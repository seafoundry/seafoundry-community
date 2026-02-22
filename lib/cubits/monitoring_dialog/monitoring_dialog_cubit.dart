// @tier: community
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/monitoring_dialog/monitoring_dialog_state.dart';
import 'package:seafoundry_app/cubits/monitoring_dialog/site_baseline_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

/// Coordinates site/outplant loading, organism candidate preparation, and local
/// form state for [MonitoringDialog]. Handles all data lookups so the dialog
/// widget can stay focused on presentation.
///
class MonitoringDialogCubit extends Cubit<MonitoringDialogState> {
  // TODO(backlog): Make sample size configurable via settings or dialog parameter.
  // Current default of 10 provides a reasonable subset for monitoring without
  // overwhelming the UI, but should be tunable based on site-specific needs.
  static const int _defaultMonitoringSampleSize = 10;

  MonitoringDialogCubit({
    required OrganismRecordRepository organismRecordRepository,
    required EventRepository eventRepository,
    required SiteRepository siteRepository,
    SiteBaselineCubit? siteBaselineCubit,
    OrganismContext? organismContext,
    Site? initialSite,
    String? initialSiteId,
    OutplantEvent? referenceOutplantEvent,
  }) : _organismRecordRepository = organismRecordRepository,
       _eventRepository = eventRepository,
       _siteRepository = siteRepository,
       _siteBaselineCubit = siteBaselineCubit,
       _organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       super(
         MonitoringDialogState(
           organismContext:
               organismContext ?? OrganismContext.forKind(OrganismKind.coral),
           initialSiteId: initialSiteId ?? initialSite?.id,
           referenceOutplantEvent: referenceOutplantEvent,
           prefilledGeometry: referenceOutplantEvent?.geometry,
           selectedSite: initialSite,
           appliedInitialSite: initialSite != null,
           isLoadingSites: true,
           isLoadingOutplantEvents: initialSite != null,
           siteBaselineEnabled: siteBaselineCubit != null,
         ),
       ) {
    _initialize();
  }

  final OrganismRecordRepository _organismRecordRepository;
  final EventRepository _eventRepository;
  final SiteRepository _siteRepository;
  final SiteBaselineCubit? _siteBaselineCubit;
  OrganismContext _organismContext;

  OrganismContext get organismContext => _organismContext;

  /// Cached outplant events per site to avoid re-querying Firestore as the user
  /// toggles between sites.
  final Map<String, List<OutplantEvent>> _outplantEventsCache = {};

  void _initialize() {
    _loadSites();
    final initialSite = state.selectedSite;
    if (initialSite != null) {
      _loadOutplantEventsForSite(initialSite);
      _siteBaselineCubit?.loadBaseline(
        site: initialSite,
        organismKind: _organismContext.kind,
        resetDraft: false,
      );
    }
    if (state.referenceOutplantEvent != null && initialSite != null) {
      loadOrganismsForMonitoring();
    }
  }

  void organismKindSelected(OrganismKind kind) {
    if (_organismContext.kind == kind) {
      return;
    }
    final selectedSite = state.selectedSite;
    final baselineCubit = _siteBaselineCubit;
    _organismContext = OrganismContext.forKind(kind);
    emit(
      state.copyWith(
        organismContext: _organismContext,
        clearOrganisms: true,
        isLoadingOrganisms: false,
      ),
    );
    if (baselineCubit != null && selectedSite != null) {
      baselineCubit.loadBaseline(
        site: selectedSite,
        organismKind: kind,
        resetDraft: false,
      );
    }
    loadOrganismsForMonitoring();
  }

  void siteSelected(Site? site) {
    emit(
      state.copyWith(
        selectedSite: site,
        clearOrganisms: true,
        resetSelectedOutplanting: true,
        resetPrefilledGeometry: true,
        appliedInitialSite: true,
        availableOutplantEvents: const [],
        isLoadingOutplantEvents: site != null,
      ),
    );
    if (site == null) {
      _siteBaselineCubit?.clearState();
      return;
    }
    _loadOutplantEventsForSite(site);
    _siteBaselineCubit?.loadBaseline(
      site: site,
      organismKind: _organismContext.kind,
    );
    loadOrganismsForMonitoring();
  }

  void outplantingSelected(OutplantEvent? event) {
    emit(
      state.copyWith(
        selectedOutplanting: event,
        referenceOutplantEvent: null,
        prefilledGeometry: event?.geometry,
        clearOrganisms: true,
      ),
    );
    if (event != null) {
      loadOrganismsForMonitoring();
    }
  }

  void healthStatusChanged(String organismId, HealthStatus? status) {
    final updatedStatuses = Map<String, HealthStatus?>.from(
      state.healthStatuses,
    );
    updatedStatuses[organismId] = status;

    final updatedCreateTasks = Map<String, bool>.from(state.createTasks);
    // Auto-create task for concerning statuses
    if (status != null &&
        status != HealthStatus.healthy &&
        status != HealthStatus.recovering) {
      updatedCreateTasks[organismId] = true;
    }

    emit(
      state.copyWith(
        healthStatuses: updatedStatuses,
        createTasks: updatedCreateTasks,
      ),
    );
  }

  void createTaskChanged(String organismId, bool createTask) {
    final updated = Map<String, bool>.from(state.createTasks);
    updated[organismId] = createTask;
    emit(state.copyWith(createTasks: updated));
  }

  void globalCommentChanged(String comment) {
    emit(state.copyWith(globalComment: comment));
  }

  void percentCoverChanged(String value) {
    emit(state.copyWith(percentCover: value));
  }

  void percentBleachingChanged(String value) {
    emit(state.copyWith(percentBleaching: value));
  }

  void percentDiseaseChanged(String value) {
    emit(state.copyWith(percentDisease: value));
  }

  void permitIdChanged(String value) {
    emit(state.copyWith(permitId: value));
  }

  void permitTypeChanged(String value) {
    emit(state.copyWith(permitType: value));
  }

  void permitIssuingAuthorityChanged(String value) {
    emit(state.copyWith(permitIssuingAuthority: value));
  }

  void permitAttachmentUrlsChanged(String value) {
    emit(state.copyWith(permitAttachmentUrls: value));
  }

  void permitValidFromChanged(DateTime? date) {
    DateTime? adjustedEnd = state.permitValidTo;
    if (date != null && adjustedEnd != null && date.isAfter(adjustedEnd)) {
      adjustedEnd = date;
    }
    emit(state.copyWith(permitValidFrom: date, permitValidTo: adjustedEnd));
  }

  void permitValidToChanged(DateTime? date) {
    DateTime? adjustedStart = state.permitValidFrom;
    if (date != null && adjustedStart != null && date.isBefore(adjustedStart)) {
      adjustedStart = date;
    }
    emit(state.copyWith(permitValidFrom: adjustedStart, permitValidTo: date));
  }

  void commentChanged(String organismId, String comment) {
    final updated = Map<String, String>.from(state.comments);
    updated[organismId] = comment;
    emit(state.copyWith(comments: updated));
  }

  void tagChanged(String organismId, String tag) {
    final updated = Map<String, String>.from(state.tags);
    updated[organismId] = tag;
    emit(state.copyWith(tags: updated));
  }

  void selectAllHealthy() {
    final updatedStatuses = <String, HealthStatus?>{};
    final updatedCreateTasks = <String, bool>{};

    for (final candidate in state.organismsToMonitor) {
      updatedStatuses[candidate.organism.id] = HealthStatus.healthy;
      updatedCreateTasks[candidate.organism.id] = false;
    }

    emit(
      state.copyWith(
        healthStatuses: updatedStatuses,
        createTasks: updatedCreateTasks,
      ),
    );
  }

  Future<void> _loadSites() async {
    emit(state.copyWith(isLoadingSites: true));
    try {
      var sites = await _siteRepository.getAll();
      if (isClosed) return;
      if (sites.isEmpty) {
        sites = await _loadSitesByOrganizationId();
        if (isClosed) return;
      }
      emit(state.copyWith(availableSites: sites, isLoadingSites: false));
      _applyInitialSiteSelection(sites);
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to load sites', e, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingSites: false,
          error: 'Failed to load sites: $e',
        ),
      );
    }
  }

  Future<List<Site>> _loadSitesByOrganizationId() async {
    final snapshot = await _siteRepository.collectionRef
        .where('organizationId', isEqualTo: _siteRepository.organization.id)
        .get();
    return snapshot.docs.map((doc) => Site.fromJson(doc.data())).toList();
  }

  void _applyInitialSiteSelection(List<Site> sites) {
    if (state.appliedInitialSite) {
      return;
    }
    final initialId = state.initialSiteId;
    if (initialId == null) {
      emit(state.copyWith(appliedInitialSite: true));
      return;
    }
    for (final site in sites) {
      if (site.id == initialId) {
        siteSelected(site);
        if (state.referenceOutplantEvent != null) {
          loadOrganismsForMonitoring();
        }
        return;
      }
    }
    LoggingService.instance.info(
      'Initial site id $initialId not found in available sites.',
    );
    emit(state.copyWith(appliedInitialSite: true));
  }

  Future<void> _loadOutplantEventsForSite(Site site) async {
    final cached = _outplantEventsCache[site.id];
    if (cached != null) {
      emit(
        state.copyWith(
          availableOutplantEvents: cached,
          isLoadingOutplantEvents: false,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoadingOutplantEvents: true));
    try {
      final events = await _eventRepository.fetchOutplantEvents(
        siteId: site.id,
      );
      if (isClosed) return;
      events.sort((a, b) {
        final aDate = DateTime.tryParse(a.createdAt);
        final bDate = DateTime.tryParse(b.createdAt);
        if (aDate == null && bDate == null) {
          return 0;
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });
      _outplantEventsCache[site.id] = events;
      emit(
        state.copyWith(
          availableOutplantEvents: events,
          isLoadingOutplantEvents: false,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load outplanting events',
        e,
        stackTrace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingOutplantEvents: false,
          availableOutplantEvents: const [],
          error: 'Failed to load outplanting events: $e',
        ),
      );
    }
  }

  void baselineFieldChanged(String key, String value) {
    _siteBaselineCubit?.updateField(key, value);
  }

  void refreshBaseline() {
    _siteBaselineCubit?.refresh();
  }

  Future<void> saveBaseline() async {
    await _siteBaselineCubit?.save();
  }

  Future<void> clearBaseline() async {
    await _siteBaselineCubit?.clear();
  }

  /// Loads the organisms that will appear in the dialog (either from an outplant
  /// allocation or a generic sample when no outplant context exists).
  Future<void> loadOrganismsForMonitoring() async {
    if (state.isLoadingOrganisms) return;

    emit(state.copyWith(isLoadingOrganisms: true, clearOrganisms: true));

    if (state.referenceOutplantEvent != null) {
      await _loadOrganismsFromOutplant(state.referenceOutplantEvent!);
      return;
    }
    if (state.selectedOutplanting != null) {
      await _loadOrganismsFromOutplant(state.selectedOutplanting!);
      return;
    }

    try {
      final organisms = await _organismRecordRepository.getAll();
      if (isClosed) return;
      final selectedSiteId = state.selectedSite?.id;
      final filtered = organisms
          .where((o) => o.organismKind == _organismContext.kind)
          .where((o) => selectedSiteId == null || o.siteId == selectedSiteId)
          .toList();
      final monitoringData = filtered.take(_defaultMonitoringSampleSize).map((
        organism,
      ) {
        final slug = organism.slug;
        final healthStatus = HealthStatus.fromId(
          organism.metadata?['healthStatus'] as String? ?? 'healthy',
        );

        final defaultTag = 'TAG-${slug.toUpperCase()}';
        final species = SpeciesRegistry.globalById(organism.speciesId);
        final defaultPhysicalForm = organism.physicalForm?.formId;
        return OrganismMonitoringCandidate(
          organism: organism,
          defaultTag: defaultTag,
          physicalForm: defaultPhysicalForm,
          morphologyId: species?.morphologyId,
          currentHealthStatus: healthStatus,
        );
      }).toList();

      emit(
        state.copyWith(
          organismsToMonitor: monitoringData,
          isLoadingOrganisms: false,
        ),
      );
      LoggingService.instance.info(
        'Prepared ${monitoringData.length} organisms for monitoring dialog',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to load organisms', e, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingOrganisms: false,
          error: 'Failed to load organisms: $e',
        ),
      );
    }
  }

  Future<void> _loadOrganismsFromOutplant(OutplantEvent event) async {
    try {
      final candidates = <OrganismMonitoringCandidate>[];
      final prefilledGeometry = state.prefilledGeometry ?? event.geometry;

      for (final allocation in event.allocations) {
        try {
          final organism = await _organismRecordRepository.getRecordForId(
            allocation.organismId,
          );
          if (isClosed) return;
          if (organism == null) {
            continue;
          }
          if (organism.organismKind != _organismContext.kind) {
            continue;
          }

          final healthStatus = HealthStatus.fromId(
            organism.metadata?['healthStatus'] as String? ?? 'healthy',
          );

          final seeded = <String, dynamic>{
            // Keep legacy key for compatibility with existing data
            'sourceOutplantId': event.id,
            // New explicit keys used by monitoring submissions
            'sourceOutplantEventId': event.id,
            'sourceOutplantSiteId': event.siteId,
            if (prefilledGeometry != null)
              'sourceOutplantGeometry': prefilledGeometry.toJson(),
            'allocationQuantity': allocation.quantity,
            if (allocation.tagId != null) 'tagId': allocation.tagId,
            if (allocation.tagName != null) 'tagName': allocation.tagName,
            if (allocation.tagPath != null) 'tagPath': allocation.tagPath,
          };
          final species = SpeciesRegistry.globalById(organism.speciesId);
          candidates.add(
            OrganismMonitoringCandidate(
              organism: organism,
              defaultTag: allocation.tagId ?? allocation.tagName,
              physicalForm: organism.physicalForm?.formId,
              morphologyId: species?.morphologyId,
              currentHealthStatus: healthStatus,
              seededMeasurements: seeded,
              forceSubmission: true,
            ),
          );
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to load organism ${allocation.organismId} for monitoring',
            error,
            stackTrace,
          );
        }
      }
      if (isClosed) return;

      emit(
        state.copyWith(
          organismsToMonitor: candidates,
          isLoadingOrganisms: false,
          prefilledGeometry: prefilledGeometry,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load outplant allocation organisms',
        e,
        stackTrace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingOrganisms: false,
          error: 'Failed to load organisms: $e',
        ),
      );
    }
  }

  // Morphology is resolved via SpeciesRegistry at call sites.

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  void setLoading(bool loading) {
    emit(state.copyWith(isLoading: loading));
  }

  String? validatePercent(String? value) {
    if (value == null || value.isEmpty) return null;
    final percent = double.tryParse(value);
    if (percent == null) return 'Invalid number';
    if (percent < 0 || percent > 100) return 'Must be 0-100';
    return null;
  }

  /// Add image files to pending uploads
  void addImageFiles(List<File> files) {
    final updated = List<File>.from(state.pendingImageFiles)..addAll(files);
    emit(state.copyWith(pendingImageFiles: updated));
  }

  /// Remove an image file from pending uploads
  void removeImageFile(int index) {
    final updated = List<File>.from(state.pendingImageFiles);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
      final updatedSelections = Map<int, ImageAttachmentSelection>.from(
        state.pendingImageSelections,
      );
      updatedSelections.remove(index);
      // Shift indices for files after the removed one
      final shiftedSelections = <int, ImageAttachmentSelection>{};
      for (final entry in updatedSelections.entries) {
        if (entry.key > index) {
          shiftedSelections[entry.key - 1] = entry.value;
        } else {
          shiftedSelections[entry.key] = entry.value;
        }
      }
      emit(
        state.copyWith(
          pendingImageFiles: updated,
          pendingImageSelections: shiftedSelections,
        ),
      );
    }
  }

  /// Update selection data for a specific image file
  void updateImageSelection(int index, ImageAttachmentSelection selection) {
    final updated = Map<int, ImageAttachmentSelection>.from(
      state.pendingImageSelections,
    );
    updated[index] = selection;
    emit(state.copyWith(pendingImageSelections: updated));
  }

  /// Clear all pending image files
  void clearImageFiles() {
    emit(
      state.copyWith(
        pendingImageFiles: const [],
        pendingImageSelections: const {},
      ),
    );
  }
}
