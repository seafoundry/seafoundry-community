// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/monitoring_dialog/site_baseline_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/site_baseline_service.dart';

/// Manages site baseline metrics for monitoring dialogs.
///
/// Extracted from [MonitoringDialogCubit] to provide focused baseline
/// management with clear state boundaries. Handles loading, saving, and
/// clearing baseline data for a specific site and organism kind.
class SiteBaselineCubit extends Cubit<SiteBaselineState> {
  SiteBaselineCubit({
    required SiteBaselineService siteBaselineService,
  })  : _siteBaselineService = siteBaselineService,
        super(const SiteBaselineState());

  final SiteBaselineService _siteBaselineService;

  /// Request ID to prevent stale async responses from overwriting newer state.
  int _loadRequestId = 0;

  /// The current site being managed (null if none selected).
  Site? _currentSite;

  /// The current organism kind for baseline lookup.
  OrganismKind _currentOrganismKind = OrganismKind.coral;

  /// Loads the baseline for a site and organism kind.
  ///
  /// If [resetDraft] is true (default), the draft form is reset to match the
  /// loaded baseline. Set to false when refreshing to preserve user edits.
  Future<void> loadBaseline({
    required Site site,
    required OrganismKind organismKind,
    bool resetDraft = true,
    bool forceRefresh = false,
  }) async {
    _currentSite = site;
    _currentOrganismKind = organismKind;
    final requestId = ++_loadRequestId;

    if (resetDraft) {
      emit(state.copyWith(
        isLoading: true,
        clearError: true,
        clearSiteBaseline: true,
        baselineDraft: siteBaselineDraftFrom(null),
      ));
    } else {
      emit(state.copyWith(isLoading: true, clearError: true));
    }

    try {
      final baseline = await _siteBaselineService.getBaseline(
        siteId: site.id,
        organismKind: organismKind,
        forceRefresh: forceRefresh,
      );

      // Discard result if a newer request was made or cubit closed
      if (_loadRequestId != requestId || isClosed) return;

      emit(state.copyWith(
        isLoading: false,
        siteBaseline: baseline,
        clearSiteBaseline: baseline == null,
        baselineDraft: siteBaselineDraftFrom(baseline),
      ));
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load site baseline for ${site.id}',
        e,
        stackTrace,
      );
      if (_loadRequestId != requestId || isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        error: 'Unable to load baseline: $e',
      ));
    }
  }

  /// Refreshes the baseline from Firestore without resetting the draft.
  Future<void> refresh() async {
    final site = _currentSite;
    if (site == null) return;
    await loadBaseline(
      site: site,
      organismKind: _currentOrganismKind,
      resetDraft: false,
      forceRefresh: true,
    );
  }

  /// Updates a field in the baseline draft.
  void updateField(String key, String value) {
    if (!state.baselineDraft.containsKey(key)) return;
    final updated = Map<String, String>.from(state.baselineDraft)..[key] = value;
    emit(state.copyWith(baselineDraft: updated));
  }

  /// Saves the current draft to Firestore.
  Future<void> save() async {
    final site = _currentSite;
    if (site == null) return;

    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      final metrics = <String, dynamic>{};
      for (final key in kSiteBaselineMetricKeys) {
        final raw = state.baselineDraft[key];
        if (raw == null || raw.trim().isEmpty) continue;
        final parsed = double.tryParse(raw);
        metrics[key] = parsed ?? raw.trim();
      }

      final notes = state.baselineDraft[kSiteBaselineNotesKey]?.trim();
      final baseline = SiteBaseline(
        siteId: site.id,
        organismKind: _currentOrganismKind,
        metrics: metrics,
        notes: notes?.isEmpty ?? true ? null : notes,
        updatedAt: DateTime.now(),
      );

      await _siteBaselineService.upsertBaseline(baseline);
      if (isClosed) return;

      emit(state.copyWith(
        isSaving: false,
        siteBaseline: baseline,
        baselineDraft: siteBaselineDraftFrom(baseline),
      ));
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to save site baseline', e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(
        isSaving: false,
        error: 'Unable to save baseline: $e',
      ));
    }
  }

  /// Deletes the baseline for the current site/organism kind.
  Future<void> clear() async {
    final site = _currentSite;
    if (site == null || state.siteBaseline == null) return;

    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      await _siteBaselineService.deleteBaseline(
        siteId: site.id,
        organismKind: _currentOrganismKind,
      );
      if (isClosed) return;

      emit(state.copyWith(
        isSaving: false,
        clearSiteBaseline: true,
        baselineDraft: siteBaselineDraftFrom(null),
      ));
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to clear site baseline', e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(
        isSaving: false,
        error: 'Unable to delete baseline: $e',
      ));
    }
  }

  /// Resets state when no site is selected.
  void clearState() {
    _currentSite = null;
    emit(const SiteBaselineState());
  }
}
