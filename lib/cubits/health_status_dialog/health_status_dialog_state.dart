// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

/// State for HealthStatusDialog
class HealthStatusDialogState extends Equatable {
  final HealthStatus? selectedHealthStatus;
  final String notes;
  final bool loading;

  const HealthStatusDialogState({
    this.selectedHealthStatus,
    this.notes = '',
    this.loading = false,
  });

  HealthStatusDialogState copyWith({
    HealthStatus? selectedHealthStatus,
    String? notes,
    bool? loading,
  }) {
    return HealthStatusDialogState(
      selectedHealthStatus: selectedHealthStatus ?? this.selectedHealthStatus,
      notes: notes ?? this.notes,
      loading: loading ?? this.loading,
    );
  }

  bool get canSubmit => selectedHealthStatus != null && !loading;

  @override
  List<Object?> get props => [selectedHealthStatus, notes, loading];
}

