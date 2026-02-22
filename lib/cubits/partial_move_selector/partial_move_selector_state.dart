// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/movement/partial_move_selection.dart';

class PartialMoveSelectorState extends Equatable {
  const PartialMoveSelectorState({required this.selection});

  final PartialMoveSelection selection;

  PartialMoveSelectorState copyWith({PartialMoveSelection? selection}) {
    return PartialMoveSelectorState(selection: selection ?? this.selection);
  }

  @override
  List<Object?> get props => [selection];
}
