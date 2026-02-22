// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/group_selector/group_selector_state.dart';

class GroupSelectorCubit extends Cubit<GroupSelectorState> {
  GroupSelectorCubit() : super(const GroupSelectorState());

  void toggleExpanded(String nodeId) {
    final expanded = Set<String>.from(state.expandedNodeIds);
    if (expanded.contains(nodeId)) {
      expanded.remove(nodeId);
    } else {
      expanded.add(nodeId);
    }
    emit(state.copyWith(expandedNodeIds: expanded));
  }
}
