// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/site_baseline.dart';

/// Immutable state for site baseline management in monitoring dialogs.
class SiteBaselineState extends Equatable {
  const SiteBaselineState({
    this.siteBaseline,
    this.baselineDraft = kSiteBaselineEmptyDraft,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  /// The persisted baseline for the current site/organism kind.
  final SiteBaseline? siteBaseline;

  /// Draft form values for editing (string-based for text field binding).
  final Map<String, String> baselineDraft;

  /// True while loading baseline from Firestore.
  final bool isLoading;

  /// True while saving or deleting baseline.
  final bool isSaving;

  /// Error message if the last operation failed.
  final String? error;

  /// Whether the draft has unsaved changes compared to the persisted baseline.
  bool get hasChanges => !siteBaselineDraftEquals(
        baselineDraft,
        siteBaselineDraftFrom(siteBaseline),
      );

  /// Whether a baseline exists for the current site/organism kind.
  bool get hasBaseline => siteBaseline != null;

  SiteBaselineState copyWith({
    SiteBaseline? siteBaseline,
    bool clearSiteBaseline = false,
    Map<String, String>? baselineDraft,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SiteBaselineState(
      siteBaseline: clearSiteBaseline ? null : siteBaseline ?? this.siteBaseline,
      baselineDraft: baselineDraft ?? this.baselineDraft,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        siteBaseline,
        baselineDraft,
        isLoading,
        isSaving,
        error,
      ];
}

// ---------------------------------------------------------------------------
// Constants and helpers for baseline draft management
// ---------------------------------------------------------------------------

const List<String> kSiteBaselineMetricKeys = [
  'temperatureC',
  'salinityPsu',
  'dissolvedOxygenMgL',
];

const String kSiteBaselineNotesKey = 'notes';

const Map<String, String> kSiteBaselineEmptyDraft = {
  'temperatureC': '',
  'salinityPsu': '',
  'dissolvedOxygenMgL': '',
  'notes': '',
};

/// Creates a draft map from a persisted [SiteBaseline] (or empty if null).
Map<String, String> siteBaselineDraftFrom(SiteBaseline? baseline) {
  final draft = Map<String, String>.from(kSiteBaselineEmptyDraft);
  if (baseline == null) {
    return draft;
  }
  for (final key in kSiteBaselineMetricKeys) {
    draft[key] = _stringifyMetric(baseline.metrics[key]);
  }
  draft[kSiteBaselineNotesKey] = baseline.notes ?? '';
  return draft;
}

/// Compares two draft maps for equality (ignoring whitespace differences).
bool siteBaselineDraftEquals(Map<String, String> a, Map<String, String> b) {
  for (final key in [...kSiteBaselineMetricKeys, kSiteBaselineNotesKey]) {
    final left = (a[key] ?? '').trim();
    final right = (b[key] ?? '').trim();
    if (left != right) {
      return false;
    }
  }
  return true;
}

String _stringifyMetric(dynamic value) {
  if (value == null) return '';
  if (value is num) return value.toString();
  return value.toString();
}
