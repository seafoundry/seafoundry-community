// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/graph_node_actions/graph_node_actions_state.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

class GraphNodeActionsCubit extends Cubit<GraphNodeActionsState> {
  GraphNodeActionsCubit() : super(const GraphNodeActionsState());

  void setActiveCategory(SiteActionCategory? category) {
    emit(state.copyWith(activeCategory: () => category));
  }

  void setActiveOrganism(OrganismKind organismKind) {
    emit(state.copyWith(activeOrganism: () => organismKind));
  }
}
