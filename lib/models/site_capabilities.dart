// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

/// High-level action categories for the site action dock.
enum SiteActionCategory {
  inventory,
  observations,
}

/// Capability matrix for a site type. Single source of truth for what
/// actions, labels, and behaviors a site type supports.
class SiteCapabilities {
  const SiteCapabilities({
    required this.siteType,
    required this.childSectionTitle,
    required this.childLabelOverrides,
    required this.enabledActionCategories,
    required this.allowOutplantActions,
    required this.allowMoveActions,
    required this.defaultVisibleEventTypes,
    this.supportsGeometry = false,
    this.supportsPermitUpload = true,
    this.canReceiveTransfers = true,
  });

  final SiteType siteType;
  final String childSectionTitle;
  final Map<GroupType, String> childLabelOverrides;
  final Set<SiteActionCategory> enabledActionCategories;
  final bool allowOutplantActions;
  final bool allowMoveActions;
  final Set<EventType> defaultVisibleEventTypes;
  final bool supportsGeometry;
  final bool supportsPermitUpload;
  final bool canReceiveTransfers;

  /// Coral-only build.
  Set<OrganismKind> get supportedOrganisms => const {OrganismKind.coral};

  static final Map<SiteType, SiteCapabilities> _byType = {
    SiteType.nursery: SiteCapabilities(
      siteType: SiteType.nursery,
      childSectionTitle: 'Structures',
      childLabelOverrides: {
        GroupType.tank: 'Tanks',
        GroupType.raceway: 'Raceways',
        GroupType.tree: 'Trees',
        GroupType.dome: 'Domes',
        GroupType.reebarTable: 'Rebar Tables',
        GroupType.cradle: 'Cradles',
        GroupType.aframe: 'A-Frames',
        GroupType.group: 'Groups',
        GroupType.patch: 'Patches',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
      },
      allowOutplantActions: true,
      allowMoveActions: true,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.observation,
      },
    ),
    SiteType.outplanting: SiteCapabilities(
      siteType: SiteType.outplanting,
      childSectionTitle: 'Zones',
      childLabelOverrides: {
        GroupType.group: 'Groups',
        GroupType.patch: 'Patches',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
      },
      allowOutplantActions: false,
      allowMoveActions: false,
      canReceiveTransfers: false,
      supportsGeometry: true,
      supportsPermitUpload: true,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.observation,
      },
    ),
  };

  /// Resolve capabilities for a given site type.
  static SiteCapabilities resolve(SiteType siteType) {
    return _byType[siteType] ?? _byType[SiteType.nursery]!;
  }

  /// In the coral-only build, always returns [OrganismKind.coral].
  static List<OrganismKind> defaultOrganismsForSite(
    SiteType siteType,
    Iterable<OrganismKind> organizationKinds,
  ) {
    return const [OrganismKind.coral];
  }

  /// Human-friendly label for a group type.
  String labelForGroupType(GroupType groupType) {
    return childLabelOverrides[groupType] ?? groupType.name;
  }

  /// Build an initial filter map for the activity feed.
  Map<EventType, bool> initialFilterState(Iterable<Event> events) {
    final eventTypes = events.map((event) => event.eventType).toSet();
    final visibleTypeIds =
        defaultVisibleEventTypes.map((type) => type.id).toSet();

    if (visibleTypeIds.isEmpty) {
      return {for (final type in eventTypes) type: true};
    }

    return {
      for (final type in eventTypes) type: visibleTypeIds.contains(type.id),
    };
  }
}
