// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/cubits/location_selection/location_selection_state.dart';

/// Cubit that tracks the selected location (group) in the dialog
class LocationSelectionCubit extends Cubit<LocationSelectionState> {
  LocationSelectionCubit({GroupNode? initialSelection})
      : super(LocationSelectionState(selectedGroup: initialSelection));

  /// Update the selected group
  void selectGroup(GroupNode? group) {
    emit(state.copyWith(selectedGroup: group));
  }
}
