// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/constants/data_import_config.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// State for the data import availability cubit.
///
/// Tracks loading, error, and availability states for the 4-step
/// data import workflow based on organism-specific data counts.
class DataImportAvailabilityState extends Equatable {
  /// The step availability data.
  final StepAvailability availability;

  /// The currently selected organism filter.
  final OrganismKind selectedOrganism;

  /// Whether the cubit is loading data.
  final bool isLoading;

  /// Error message if stream failed.
  final String? error;

  const DataImportAvailabilityState({
    required this.availability,
    required this.selectedOrganism,
    this.isLoading = false,
    this.error,
  });

  /// Initial loading state.
  factory DataImportAvailabilityState.loading({
    required OrganismKind selectedOrganism,
  }) {
    return DataImportAvailabilityState(
      availability: const StepAvailability(),
      selectedOrganism: selectedOrganism,
      isLoading: true,
    );
  }

  /// Loaded state with availability data.
  factory DataImportAvailabilityState.loaded({
    required StepAvailability availability,
    required OrganismKind selectedOrganism,
  }) {
    return DataImportAvailabilityState(
      availability: availability,
      selectedOrganism: selectedOrganism,
      isLoading: false,
    );
  }

  /// Error state with message.
  factory DataImportAvailabilityState.error({
    required String message,
    required OrganismKind selectedOrganism,
  }) {
    return DataImportAvailabilityState(
      availability: const StepAvailability(),
      selectedOrganism: selectedOrganism,
      isLoading: false,
      error: message,
    );
  }

  /// Whether there is an error.
  bool get hasError => error != null;

  /// Create a copy with updated fields.
  DataImportAvailabilityState copyWith({
    StepAvailability? availability,
    OrganismKind? selectedOrganism,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DataImportAvailabilityState(
      availability: availability ?? this.availability,
      selectedOrganism: selectedOrganism ?? this.selectedOrganism,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [availability, selectedOrganism, isLoading, error];
}
