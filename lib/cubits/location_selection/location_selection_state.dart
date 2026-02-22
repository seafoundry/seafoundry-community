// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';

/// State for location selection dialog
class LocationSelectionState extends Equatable {
  const LocationSelectionState({this.selectedGroup});

  final GroupNode? selectedGroup;

  bool get hasSelection => selectedGroup != null;

  LocationSelectionState copyWith({GroupNode? selectedGroup}) {
    return LocationSelectionState(
      selectedGroup: selectedGroup ?? this.selectedGroup,
    );
  }

  @override
  List<Object?> get props => [selectedGroup];
}
