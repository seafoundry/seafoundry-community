// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

class GraphNodeActionsState extends Equatable {
  const GraphNodeActionsState({
    this.activeCategory,
    this.activeOrganism,
  });

  final SiteActionCategory? activeCategory;
  final OrganismKind? activeOrganism;

  GraphNodeActionsState copyWith({
    SiteActionCategory? Function()? activeCategory,
    OrganismKind? Function()? activeOrganism,
  }) {
    return GraphNodeActionsState(
      activeCategory: activeCategory != null
          ? activeCategory()
          : this.activeCategory,
      activeOrganism: activeOrganism != null
          ? activeOrganism()
          : this.activeOrganism,
    );
  }

  @override
  List<Object?> get props => [activeCategory, activeOrganism];
}
