// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/operations/vessel.dart';

/// State for vessel management operations
class VesselState extends Equatable {
  final List<Vessel> vessels;
  final bool loading;
  final String? errorMessage;
  final Vessel? selectedVessel;

  const VesselState({
    this.vessels = const [],
    this.loading = false,
    this.errorMessage,
    this.selectedVessel,
  });

  VesselState copyWith({
    List<Vessel>? vessels,
    bool? loading,
    String? errorMessage,
    Vessel? selectedVessel,
  }) {
    return VesselState(
      vessels: vessels ?? this.vessels,
      loading: loading ?? this.loading,
      errorMessage: errorMessage,
      selectedVessel: selectedVessel ?? this.selectedVessel,
    );
  }

  @override
  List<Object?> get props => [vessels, loading, errorMessage, selectedVessel];
}
