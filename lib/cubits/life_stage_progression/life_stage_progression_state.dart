// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/inventory_change_reason.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';

/// State for Life Stage Progression Dialog
class LifeStageProgressionState extends Equatable {
  const LifeStageProgressionState({
    this.selectedLifeStage,
    this.availableForms = const [],
    this.selectedForm,
    this.selectedSizeBand,
    this.reason,
    this.notes = '',
    this.loading = false,
    this.loadingForms = false,
    this.error,
  });

  /// Selected target life stage
  final LifeStage? selectedLifeStage;

  /// Available physical forms for selected life stage
  final List<PhysicalFormConfig> availableForms;

  /// Selected physical form
  final PhysicalFormConfig? selectedForm;

  /// Selected size band
  final SizeBandConfig? selectedSizeBand;

  /// Reason for transition
  final LifeStageTransitionReason? reason;

  /// Optional notes about the progression
  final String notes;

  /// Loading state for form submission
  final bool loading;

  /// Loading state for fetching available forms
  final bool loadingForms;

  /// Error message if any
  final String? error;

  /// Check if form is valid for submission
  /// Check if form is valid for submission
  bool get isValid =>
      selectedLifeStage != null &&
      selectedForm != null &&
      selectedSizeBand != null &&
      reason != null;

  LifeStageProgressionState copyWith({
    LifeStage? selectedLifeStage,
    List<PhysicalFormConfig>? availableForms,
    PhysicalFormConfig? selectedForm,
    SizeBandConfig? selectedSizeBand,
    LifeStageTransitionReason? reason,
    String? notes,
    bool? loading,
    bool? loadingForms,
    String? error,
  }) {
    return LifeStageProgressionState(
      selectedLifeStage: selectedLifeStage ?? this.selectedLifeStage,
      availableForms: availableForms ?? this.availableForms,
      selectedForm: selectedForm ?? this.selectedForm,
      selectedSizeBand: selectedSizeBand ?? this.selectedSizeBand,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      loading: loading ?? this.loading,
      loadingForms: loadingForms ?? this.loadingForms,
      error: error,
    );
  }

  /// Reset form selection when changing life stage
  LifeStageProgressionState resetFormSelection({
    required LifeStage lifeStage,
    required List<PhysicalFormConfig> forms,
  }) {
    return copyWith(
      selectedLifeStage: lifeStage,
      availableForms: forms,
      selectedForm: null,
      selectedSizeBand: null,
    );
  }

  @override
  List<Object?> get props => [
        selectedLifeStage,
        availableForms,
        selectedForm,
        selectedSizeBand,
        reason,
        notes,
        loading,
        loadingForms,
        error,
      ];
}
