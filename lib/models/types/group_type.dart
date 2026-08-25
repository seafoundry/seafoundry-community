// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_community/models/types/record_type.dart';

/// Hierarchical category for group types within a site.
///
/// Simplified to structures only for coral nurseries.
/// All group types are structures (primary containers that hold organisms).
enum GroupTypeCategory {
  /// Top-level grouping (e.g., Life Support System, Zone)
  /// Can contain structures but not organisms directly
  superstructure,

  /// Primary container (e.g., Tank, Tree, Table)
  /// Can contain organisms directly OR substructures
  structure,

  /// Subdivision within a structure (e.g., Tray, Branch, Tag)
  /// Can contain organisms but NOT other substructures
  substructure,
}

class GroupType extends BuiltinRecordType {
  final GroupTypeCategory category;

  const GroupType({
    required super.id,
    required super.name,
    required this.category,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Whether this is a superstructure (top-level grouping)
  bool get isSuperstructure => category == GroupTypeCategory.superstructure;

  /// Whether this is a structure (primary container)
  bool get isStructure => category == GroupTypeCategory.structure;

  /// Whether this is a substructure (subdivision within a structure)
  bool get isSubstructure => category == GroupTypeCategory.substructure;

  /// Returns true if this type can contain organisms directly.
  /// Structures and substructures can contain organisms.
  /// Superstructures cannot contain organisms directly.
  bool get canContainOrganisms =>
      category == GroupTypeCategory.structure ||
      category == GroupTypeCategory.substructure;

  /// Returns true if this type can contain other groups.
  /// Superstructures can contain structures.
  /// Structures can contain substructures.
  /// Substructures cannot contain other groups.
  bool get canContainGroups =>
      category == GroupTypeCategory.superstructure ||
      category == GroupTypeCategory.structure;

  /// Returns valid child categories for this type.
  Set<GroupTypeCategory> get validChildCategories {
    switch (category) {
      case GroupTypeCategory.superstructure:
        return {GroupTypeCategory.structure, GroupTypeCategory.substructure};
      case GroupTypeCategory.structure:
        return {GroupTypeCategory.substructure};
      case GroupTypeCategory.substructure:
        return {};
    }
  }

  /// Check if a child category is valid for this type.
  bool canContainCategory(GroupTypeCategory childCategory) {
    return validChildCategories.contains(childCategory);
  }

  /// All superstructure types (computed from builtins)
  static Set<GroupType> get superstructures => uniqueBuiltins
      .where((g) => g.category == GroupTypeCategory.superstructure)
      .toSet();

  /// All structure types (computed from builtins)
  static Set<GroupType> get structures => uniqueBuiltins
      .where((g) => g.category == GroupTypeCategory.structure)
      .toSet();

  /// All substructure types (computed from builtins)
  static Set<GroupType> get substructures => uniqueBuiltins
      .where((g) => g.category == GroupTypeCategory.substructure)
      .toSet();

  /// Unique builtin GroupType instances (deduplicates aliases in builtins map)
  static Set<GroupType> get uniqueBuiltins => builtins.values.toSet();

  static final Map<String, GroupType> builtins = {
    tank.id: tank,
    'tank': tank,
    raceway.id: raceway,
    'rwy': raceway,
    group.id: group,
    'grp': group,
    patch.id: patch,
    'group_type_patch': patch,
    tree.id: tree,
    'tree': tree,
    dome.id: dome,
    'dome': dome,
    reebarTable.id: reebarTable,
    'rtb': reebarTable,
    cradle.id: cradle,
    'crd': cradle,
    aframe.id: aframe,
    'afra': aframe,
    // Legacy aliases — map deleted group types to nearest equivalent
    'group_type_life_support_system': tank,
    'lss': tank,
    'group_type_tray': tank,
    'tray': tank,
    'group_type_tree_branch': tree,
    'tb': tree,
    'group_type_zone': group,
    'zone': group,
    'group_type_grid': group,
    'grid': group,
    'group_type_grid_cell': group,
    'grdc': group,
    'group_type_tag': group,
    'tag': group,
    'group_type_longline': group,
    'longline': group,
    'group_type_raft': group,
    'raft': group,
    'group_type_dropper_line': group,
    'dropperline': group,
    'group_type_pen': group,
    'pen': group,
    'group_type_pond': group,
    'pond': group,
    'group_type_reef_patch': group,
    'reefpatch': group,
    'group_type_bag': group,
    'bag': group,
    'group_type_rack': group,
    'rack': group,
    'group_type_cage': group,
    'cage': group,
    'group_type_plot_transect': group,
    'plot_transect': group,
    'group_type_quadrat': group,
    'quadrat': group,
    'group_type_belt_transect': group,
    'belt_transect': group,
    'group_type_line_pen': group,
    'line_pen': group,
    'group_type_boat_drop': group,
    'boat_drop': group,
  };

  // ==========================================================================
  // STRUCTURES - Primary containers for coral nurseries
  // ==========================================================================

  /// Tank - Ex-situ structure for holding organisms
  static const GroupType tank = GroupType(
    id: 'group_type_tank',
    name: 'Tank',
    category: GroupTypeCategory.structure,
  );

  /// Raceway - Ex-situ flow-through structure
  static const GroupType raceway = GroupType(
    id: 'group_type_raceway',
    name: 'Raceway',
    category: GroupTypeCategory.structure,
  );

  /// Tree - In-situ nursery structure
  static const GroupType tree = GroupType(
    id: 'group_type_tree',
    name: 'Tree',
    category: GroupTypeCategory.structure,
  );

  /// Dome - In-situ nursery structure
  static const GroupType dome = GroupType(
    id: 'group_type_dome',
    name: 'Dome',
    category: GroupTypeCategory.structure,
  );

  /// Rebar Table - In-situ nursery structure
  static const GroupType reebarTable = GroupType(
    id: 'group_type_reebar_table',
    name: 'Rebar Table',
    category: GroupTypeCategory.structure,
  );

  /// Cradle - In-situ nursery structure
  static const GroupType cradle = GroupType(
    id: 'group_type_cradle',
    name: 'Cradle',
    category: GroupTypeCategory.structure,
  );

  /// A-Frame - In-situ nursery structure
  static const GroupType aframe = GroupType(
    id: 'group_type_aframe',
    name: 'A-Frame',
    category: GroupTypeCategory.structure,
  );

  /// Group - Generic universal structure
  static const GroupType group = GroupType(
    id: 'group_type_group',
    name: 'Group',
    category: GroupTypeCategory.structure,
  );

  /// Patch - Generic universal structure
  static const GroupType patch = GroupType(
    id: 'patch',
    name: 'Patch',
    category: GroupTypeCategory.structure,
  );
}
