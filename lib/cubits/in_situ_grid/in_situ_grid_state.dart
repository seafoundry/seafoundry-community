// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/widgets/in_situ/grid_renderer.dart';

class InSituGridState extends Equatable {
  const InSituGridState({
    this.selectedCoordinate,
    this.zoom = 1.0,
    this.isUpdating = false,
  });

  final InSituGridCoordinate? selectedCoordinate;
  final double zoom;
  final bool isUpdating;

  InSituGridState copyWith({
    InSituGridCoordinate? selectedCoordinate,
    double? zoom,
    bool? isUpdating,
    bool clearSelectedCoordinate = false,
  }) {
    return InSituGridState(
      selectedCoordinate: clearSelectedCoordinate
          ? null
          : (selectedCoordinate ?? this.selectedCoordinate),
      zoom: zoom ?? this.zoom,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }

  @override
  List<Object?> get props => [selectedCoordinate, zoom, isUpdating];
}

