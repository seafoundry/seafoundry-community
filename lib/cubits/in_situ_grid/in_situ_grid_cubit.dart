import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/in_situ_grid/in_situ_grid_state.dart';
import 'package:seafoundry_app/widgets/in_situ/grid_renderer.dart';

class InSituGridCubit extends Cubit<InSituGridState> {
  InSituGridCubit() : super(const InSituGridState());

  void selectCoordinate(InSituGridCoordinate? coordinate) {
    emit(state.copyWith(selectedCoordinate: coordinate));
  }

  void clearSelection() {
    emit(state.copyWith(clearSelectedCoordinate: true));
  }

  void zoomIn() {
    final newZoom = (state.zoom + 0.2).clamp(0.5, 2.5);
    if (newZoom != state.zoom) {
      emit(state.copyWith(zoom: newZoom));
    }
  }

  void zoomOut() {
    final newZoom = (state.zoom - 0.2).clamp(0.5, 2.5);
    if (newZoom != state.zoom) {
      emit(state.copyWith(zoom: newZoom));
    }
  }

  void setUpdating(bool updating) {
    emit(state.copyWith(isUpdating: updating));
  }
}

