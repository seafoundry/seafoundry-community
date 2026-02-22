// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/partial_move_selector/partial_move_selector_state.dart';
import 'package:seafoundry_app/models/movement/partial_move_selection.dart';

class PartialMoveSelectorCubit extends Cubit<PartialMoveSelectorState> {
  PartialMoveSelectorCubit({PartialMoveSelection? initialSelection})
      : super(
          PartialMoveSelectorState(
            selection: initialSelection ?? const PartialMoveSelection(),
          ),
        );

  void updateSelection(PartialMoveSelection selection) {
    emit(state.copyWith(selection: selection));
  }
}
