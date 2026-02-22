// @tier: community
// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/events/structure_maintenance_event.dart';
import 'package:seafoundry_app/models/types/record_type.dart';

/// Hierarchical category for group types within a site.
///
/// This defines the nesting hierarchy:
/// - Site can contain superstructures and structures (not substructures directly)
/// - Superstructures can contain structures or substructures directly
/// - Structures can contain substructures (organisms are placed within structures or substructures)
/// - Substructures cannot contain other groups (organisms are placed within them)
///
/// The flexible superstructure rules allow workflows like Zone → Tag
/// without requiring an intermediate structure (e.g., Grid).
enum GroupTypeCategory {
  /// Top-level grouping (e.g., Life Support System, Zone)
  /// Can contain structures but not organisms directly
  superstructure,

  /// Primary container (e.g., Tank, Tree, Table, Plot)
  /// Can contain organisms directly OR substructures
  structure,

  /// Subdivision within a structure (e.g., Tray, Branch, Tag, Rack)
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
  ///
  /// Hierarchy rules:
  /// - Superstructures can contain structures OR substructures directly.
  ///   This allows flexible workflows like Zone → Tag without requiring
  ///   an intermediate structure (e.g., Grid).
  /// - Structures can contain substructures only.
  /// - Substructures cannot contain other groups.
  Set<GroupTypeCategory> get validChildCategories {
    switch (category) {
      case GroupTypeCategory.superstructure:
        // Superstructures can contain structures or substructures directly.
        // Example: Zone can contain Grids (structures) or Tags (substructures).
        return {GroupTypeCategory.structure, GroupTypeCategory.substructure};
      case GroupTypeCategory.structure:
        return {GroupTypeCategory.substructure};
      case GroupTypeCategory.substructure:
        return {}; // Cannot contain other groups
    }
  }

  /// Check if a child category is valid for this type.
  bool canContainCategory(GroupTypeCategory childCategory) {
    return validChildCategories.contains(childCategory);
  }

  /// Get the site environment(s) this group type is applicable to.
  /// Note: Group types are already filtered by SiteType.groupTypes, but this
  /// provides a way to check environment compatibility directly.
  Set<SiteEnvironment> get applicableEnvironments {
    // Ex-situ only types (land-based facilities)
    if (_exSituOnlyTypes.contains(this)) {
      return {SiteEnvironment.exSitu};
    }
    // In-situ only types (ocean-based)
    if (_inSituOnlyTypes.contains(this)) {
      return {SiteEnvironment.inSitu};
    }
    // Universal types (applicable to both environments)
    return {SiteEnvironment.exSitu, SiteEnvironment.inSitu};
  }

  /// Whether this group type is applicable to the given site environment
  bool isApplicableTo(SiteEnvironment environment) {
    return applicableEnvironments.contains(environment);
  }

  /// Group types that are only valid in ex-situ (land-based) environments
  static final Set<GroupType> _exSituOnlyTypes = {
    lifeSupportSystem,
    tank,
    raceway,
    tray,
    pond,
    pen,
    linePen,
  };

  /// Group types that are only valid in in-situ (ocean-based) environments
  static final Set<GroupType> _inSituOnlyTypes = {
    tree,
    treeBranch,
    dome,
    reebarTable,
    cradle,
    aframe,
    zone,
    grid,
    gridCell,
    tag,
    longline,
    raft,
    dropperLine,
    reefPatch,
    bag,
    rack,
    cage,
    plotTransect,
    quadrat,
    beltTransect,
    boatDrop,
  };

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
    lifeSupportSystem.id: lifeSupportSystem,
    'lss': lifeSupportSystem,
    tank.id: tank,
    'tank': tank,
    raceway.id: raceway,
    'rwy': raceway,
    tray.id: tray,
    'tray': tray,
    group.id: group,
    'grp': group,
    patch.id: patch,
    'group_type_patch': patch,
    tree.id: tree,
    'tree': tree,
    treeBranch.id: treeBranch,
    'tb': treeBranch,
    dome.id: dome,
    'dome': dome,
    reebarTable.id: reebarTable,
    'rtb': reebarTable,
    cradle.id: cradle,
    'crd': cradle,
    aframe.id: aframe,
    'afra': aframe,
    zone.id: zone,
    'zone': zone,
    grid.id: grid,
    'grid': grid,
    gridCell.id: gridCell,
    'grdc': gridCell,
    tag.id: tag,
    'tag': tag,
    longline.id: longline,
    'longline': longline,
    raft.id: raft,
    'raft': raft,
    dropperLine.id: dropperLine,
    'dropperline': dropperLine,
    pen.id: pen,
    'pen': pen,
    pond.id: pond,
    'pond': pond,
    reefPatch.id: reefPatch,
    'reefpatch': reefPatch,
    bag.id: bag,
    'bag': bag,
    rack.id: rack,
    'rack': rack,
    cage.id: cage,
    'cage': cage,
    plotTransect.id: plotTransect,
    'plot_transect': plotTransect,
    quadrat.id: quadrat,
    'quadrat': quadrat,
    beltTransect.id: beltTransect,
    'belt_transect': beltTransect,
    linePen.id: linePen,
    'line_pen': linePen,
    boatDrop.id: boatDrop,
    'boat_drop': boatDrop,
  };

  // ==========================================================================
  // SUPERSTRUCTURES - Top-level groupings that contain structures
  // ==========================================================================

  /// Life Support System - Ex-situ superstructure for grouping tanks/raceways
  static const GroupType lifeSupportSystem = GroupType(
    id: 'group_type_life_support_system',
    name: 'Life Support System',
    category: GroupTypeCategory.superstructure,
  );

  /// Zone - In-situ superstructure for grouping plots/grids in outplanting
  static const GroupType zone = GroupType(
    id: 'group_type_zone',
    name: 'Zone',
    category: GroupTypeCategory.superstructure,
  );

  // ==========================================================================
  // STRUCTURES - Primary containers that can hold organisms or substructures
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

  /// Pond - Ex-situ grow-out structure
  static const GroupType pond = GroupType(
    id: 'group_type_pond',
    name: 'Pond',
    category: GroupTypeCategory.structure,
  );

  /// Pen - Ex-situ enclosure structure
  static const GroupType pen = GroupType(
    id: 'group_type_pen',
    name: 'Pen',
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

  /// Longline - In-situ kelp/seaweed structure
  static const GroupType longline = GroupType(
    id: 'group_type_longline',
    name: 'Longline',
    category: GroupTypeCategory.structure,
  );

  /// Raft - In-situ floating structure
  static const GroupType raft = GroupType(
    id: 'group_type_raft',
    name: 'Raft',
    category: GroupTypeCategory.structure,
  );

  /// Reef Patch - In-situ reef aquaculture structure
  static const GroupType reefPatch = GroupType(
    id: 'group_type_reef_patch',
    name: 'Reef Patch',
    category: GroupTypeCategory.structure,
  );

  /// Cage - In-situ aquaculture structure
  static const GroupType cage = GroupType(
    id: 'group_type_cage',
    name: 'Cage',
    category: GroupTypeCategory.structure,
  );

  /// Plot Transect - In-situ monitoring/restoration structure
  static const GroupType plotTransect = GroupType(
    id: 'group_type_plot_transect',
    name: 'Plot Transect',
    category: GroupTypeCategory.structure,
  );

  /// Grid - In-situ outplanting structure
  static const GroupType grid = GroupType(
    id: 'group_type_grid',
    name: 'Grid',
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

  // ==========================================================================
  // SUBSTRUCTURES - Subdivisions within structures that hold organisms
  // ==========================================================================

  /// Tray - Ex-situ substructure within tanks
  static const GroupType tray = GroupType(
    id: 'group_type_tray',
    name: 'Tray',
    category: GroupTypeCategory.substructure,
  );

  /// Line Pen - Ex-situ substructure
  static const GroupType linePen = GroupType(
    id: 'group_type_line_pen',
    name: 'Line Pen',
    category: GroupTypeCategory.substructure,
  );

  /// Tree Branch - In-situ substructure on trees
  static const GroupType treeBranch = GroupType(
    id: 'group_type_tree_branch',
    name: 'Tree Branch',
    category: GroupTypeCategory.substructure,
  );

  /// Grid Cell - In-situ substructure within grids
  static const GroupType gridCell = GroupType(
    id: 'group_type_grid_cell',
    name: 'Grid Cell',
    category: GroupTypeCategory.substructure,
  );

  /// Tag - In-situ marker/identifier substructure
  static const GroupType tag = GroupType(
    id: 'group_type_tag',
    name: 'Tag',
    category: GroupTypeCategory.substructure,
  );

  /// Dropper Line - In-situ kelp substructure
  static const GroupType dropperLine = GroupType(
    id: 'group_type_dropper_line',
    name: 'Dropper Line',
    category: GroupTypeCategory.substructure,
  );

  /// Quadrat - In-situ seagrass substructure
  static const GroupType quadrat = GroupType(
    id: 'group_type_quadrat',
    name: 'Quadrat',
    category: GroupTypeCategory.substructure,
  );

  /// Belt Transect - In-situ mangrove substructure
  static const GroupType beltTransect = GroupType(
    id: 'group_type_belt_transect',
    name: 'Belt Transect',
    category: GroupTypeCategory.substructure,
  );

  /// Bag - In-situ oyster/shellfish substructure
  static const GroupType bag = GroupType(
    id: 'group_type_bag',
    name: 'Bag',
    category: GroupTypeCategory.substructure,
  );

  /// Rack - In-situ oyster/shellfish substructure
  static const GroupType rack = GroupType(
    id: 'group_type_rack',
    name: 'Rack',
    category: GroupTypeCategory.substructure,
  );

  /// Boat Drop - In-situ release point substructure
  static const GroupType boatDrop = GroupType(
    id: 'group_type_boat_drop',
    name: 'Boat Drop',
    category: GroupTypeCategory.substructure,
  );
}
