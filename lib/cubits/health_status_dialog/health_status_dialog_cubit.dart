// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/health_status_dialog/health_status_dialog_state.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

/// Cubit for managing health status dialog state
class HealthStatusDialogCubit extends Cubit<HealthStatusDialogState> {
  HealthStatusDialogCubit() : super(const HealthStatusDialogState());

  /// Update selected health status
  void healthStatusChanged(HealthStatus? status) {
    emit(state.copyWith(selectedHealthStatus: status));
  }

  /// Update notes
  void notesChanged(String notes) {
    emit(state.copyWith(notes: notes));
  }

  /// Set loading state
  void setLoading(bool loading) {
    emit(state.copyWith(loading: loading));
  }
}

