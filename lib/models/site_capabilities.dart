// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/structure_maintenance_event.dart';
import 'package:seafoundry_app/models/site_action_config.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

/// Enumerates the high-level action categories that can surface on the site
/// action dock (Inventory, Observations, Husbandry, Tasks, etc).
enum SiteActionCategory {
  inventory,
  observations,
  husbandry,
  tasks,
  observationHusbandry,
  tasksChats
}

/// Encapsulates the guardrails for a site type. This object centralises the
/// capability matrix so UI layers can ask a single source of truth for:
/// - Which action categories to show
/// - Which detailed actions should be available (propagation/outplant/move/etc)
/// - How to label child collections (structures, plots, tags)
/// - Which event filters should be active by default in the activity feed
/// - How to render summary cards (handled via [summaryStyle])
class SiteCapabilities {
  const SiteCapabilities({
    required this.siteType,
    required this.childSectionTitle,
    required this.childLabelOverrides,
    required this.enabledActionCategories,
    required this.allowPropagationActions,
    required this.allowOutplantActions,
    required this.allowMoveActions,
    required this.allowEnvironmentalAdjustment,
    required this.supportsMonitoringFab,
    required this.defaultVisibleEventTypes,
    required this.supportedOrganisms,
    this.supportsPermitUpload = true,
    this.canReceiveTransfers = true,
  });

  final SiteType siteType;

  /// Title that prefixes the child section list (e.g. Structures, Plots & Tags).
  final String childSectionTitle;

  /// Friendly labels for group types within this site.
  final Map<GroupType, String> childLabelOverrides;

  /// High-level action categories that should be exposed in the FAB dock.
  final Set<SiteActionCategory> enabledActionCategories;

  /// Whether propagation actions should be surfaced (nursery only).
  final bool allowPropagationActions;

  /// Whether outplant actions should be surfaced (nursery only).
  final bool allowOutplantActions;

  /// Whether move/move-partial actions are allowed from this site.
  final bool allowMoveActions;

  /// Whether environmental adjustment should remain available.
  final bool allowEnvironmentalAdjustment;

  /// Whether the monitoring FAB shortcut should be visible.
  final bool supportsMonitoringFab;

  /// Event types that should start enabled when rendering the activity feed.
  final Set<EventType> defaultVisibleEventTypes;

  /// Whether permit uploads/metadata should be exposed for the site type.
  final bool supportsPermitUpload;

  /// Whether this site type can receive organisms from transfers or internal moves.
  /// Monitoring-only sites (baseline, reference) set this to false.
  final bool canReceiveTransfers;

  /// Organisms this site type is configured to support by default.
  final Set<OrganismKind> supportedOrganisms;

  /// Action configuration for this site type.
  SiteActionConfig get actionConfig {
    switch (siteType) {
      case SiteType.nurseryExSitu:
        return SiteActionConfig.forNursery;
      case SiteType.nurseryInSitu:
        return SiteActionConfig.forNurseryInSitu;
      case SiteType.outplanting:
        return SiteActionConfig.forOutplanting;
      case SiteType.geneBank:
        return SiteActionConfig.forGeneBank;
      case SiteType.fieldCollection:
        return SiteActionConfig.forFieldCollection;
      case SiteType.baselineSite:
      case SiteType.referenceSite:
        return SiteActionConfig.forMonitoringOnly;
      default:
        // Fallback to nursery config based on environment for unknown site types
        return siteType.environment == SiteEnvironment.inSitu
            ? SiteActionConfig.forNurseryInSitu
            : SiteActionConfig.forNursery;
    }
  }

  /// Static lookup table aligning each [SiteType] with its capabilities.
  static final Map<SiteType, SiteCapabilities> _byType = {
    SiteType.nurseryExSitu: SiteCapabilities(
      siteType: SiteType.nurseryExSitu,
      childSectionTitle: 'Structures',
      childLabelOverrides: {
        GroupType.lifeSupportSystem: 'Life Support Systems',
        GroupType.tank: 'Tanks',
        GroupType.raceway: 'Raceways',
        GroupType.tray: 'Trays',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: true,
      allowOutplantActions: true,
      allowMoveActions: true,
      allowEnvironmentalAdjustment: true,
      supportsMonitoringFab: false,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.task,
        EventType.observation,
        EventType.propagation,
        HusbandryEventType.cleaning,
        HusbandryEventType.feeding,
        HusbandryEventType.treatment,
        HusbandryEventType.environmentalAdjustment,
        HusbandryEventType.structureMaintenance,
        HusbandryEventType.waterQualityTest,
      },
      supportedOrganisms: {
        OrganismKind.coral,
        OrganismKind.echinoid,
        OrganismKind.crab,
        OrganismKind.seaCucumber,
      },
    ),
    SiteType.nurseryInSitu: SiteCapabilities(
      siteType: SiteType.nurseryInSitu,
      childSectionTitle: 'Nursery Layout',
      childLabelOverrides: {
        GroupType.tree: 'Trees',
        GroupType.treeBranch: 'Branches',
        GroupType.dome: 'Domes',
        GroupType.reebarTable: 'Rebar Tables',
        GroupType.cradle: 'Cradles',
        GroupType.aframe: 'A-Frames',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: true,
      allowOutplantActions: true,
      allowMoveActions: true,
      allowEnvironmentalAdjustment: true,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.task,
        EventType.observation,
        EventType.propagation,
        HusbandryEventType.cleaning,
        HusbandryEventType.feeding,
        HusbandryEventType.treatment,
        HusbandryEventType.environmentalAdjustment,
        HusbandryEventType.structureMaintenance,
      },
      supportedOrganisms: {OrganismKind.coral},
    ),
    SiteType.outplanting: SiteCapabilities(
      siteType: SiteType.outplanting,
      childSectionTitle: 'Plots & Tags',
      childLabelOverrides: {
        GroupType.zone: 'Plots',
        GroupType.grid: 'Grids',
        GroupType.gridCell: 'Grid Cells',
        GroupType.tag: 'Tags',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: true,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.outplant,
        EventType.observation,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {
        OrganismKind.coral,
        OrganismKind.oyster,
        OrganismKind.seagrass,
        OrganismKind.seaCucumber,
      },
    ),
    SiteType.geneBank: SiteCapabilities(
      siteType: SiteType.geneBank,
      childSectionTitle: 'Storage Units',
      childLabelOverrides: {
        GroupType.lifeSupportSystem: 'Life Support Systems',
        GroupType.tank: 'Tanks',
        GroupType.raceway: 'Raceways',
        GroupType.tray: 'Trays',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: false,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: false,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.observation,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {OrganismKind.coral},
    ),
    SiteType.fieldCollection: SiteCapabilities(
      siteType: SiteType.fieldCollection,
      childSectionTitle: 'Collection Areas',
      childLabelOverrides: {
        GroupType.zone: 'Zones',
        GroupType.grid: 'Grids',
        GroupType.gridCell: 'Grid Cells',
        GroupType.tag: 'Tags',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: false,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: false,
      defaultVisibleEventTypes: {
        EventType.observation,
        EventType.activity,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {OrganismKind.coral},
    ),
    SiteType.kelpFarm: SiteCapabilities(
      siteType: SiteType.kelpFarm,
      childSectionTitle: 'Farm Layout',
      childLabelOverrides: {
        GroupType.longline: 'Longlines',
        GroupType.dropperLine: 'Dropper Lines',
        GroupType.raft: 'Rafts',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: true,
      allowEnvironmentalAdjustment: true,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.observation,
        HusbandryEventType.environmentalAdjustment,
        HusbandryEventType.structureMaintenance,
      },
      supportedOrganisms: {OrganismKind.kelp},
    ),
    SiteType.reefAquaculture: SiteCapabilities(
      siteType: SiteType.reefAquaculture,
      childSectionTitle: 'Reef Structures',
      childLabelOverrides: {
        GroupType.reefPatch: 'Reef Patches',
        GroupType.bag: 'Bags',
        GroupType.rack: 'Racks',
        GroupType.cage: 'Cages',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: true,
      allowMoveActions: true,
      allowEnvironmentalAdjustment: true,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.observation,
        HusbandryEventType.feeding,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {OrganismKind.oyster},
    ),
    SiteType.seagrassPlot: SiteCapabilities(
      siteType: SiteType.seagrassPlot,
      childSectionTitle: 'Plots & Transects',
      childLabelOverrides: {
        GroupType.plotTransect: 'Transects',
        GroupType.quadrat: 'Quadrats',
        GroupType.grid: 'Grids',
        GroupType.tag: 'Tags',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: true,
      allowMoveActions: false,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.outplant,
        EventType.observation,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {OrganismKind.seagrass},
    ),
    SiteType.mangroveOutplant: SiteCapabilities(
      siteType: SiteType.mangroveOutplant,
      childSectionTitle: 'Plots & Transects',
      childLabelOverrides: {
        GroupType.plotTransect: 'Transects',
        GroupType.beltTransect: 'Belt Transects',
        GroupType.tag: 'Tags',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: true,
      allowMoveActions: false,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.outplant,
        EventType.observation,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {OrganismKind.mangrove},
    ),
    SiteType.growOutPond: SiteCapabilities(
      siteType: SiteType.growOutPond,
      childSectionTitle: 'Ponds & Pens',
      childLabelOverrides: {
        GroupType.pond: 'Ponds',
        GroupType.pen: 'Pens',
        GroupType.linePen: 'Line Pens',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: true,
      allowEnvironmentalAdjustment: true,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.observation,
        HusbandryEventType.feeding,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {OrganismKind.echinoid, OrganismKind.crab},
    ),
    SiteType.racewaySite: SiteCapabilities(
      siteType: SiteType.racewaySite,
      childSectionTitle: 'Raceways & Tanks',
      childLabelOverrides: {
        GroupType.raceway: 'Raceways',
        GroupType.tank: 'Tanks',
        GroupType.pen: 'Pens',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.husbandry,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: true,
      allowEnvironmentalAdjustment: true,
      supportsMonitoringFab: false,
      defaultVisibleEventTypes: {
        EventType.activity,
        EventType.observation,
        HusbandryEventType.feeding,
        HusbandryEventType.treatment,
      },
      supportedOrganisms: {OrganismKind.finfish},
    ),
    SiteType.releaseSite: SiteCapabilities(
      siteType: SiteType.releaseSite,
      childSectionTitle: 'Release Points',
      childLabelOverrides: {
        GroupType.boatDrop: 'Boat Drops',
        GroupType.tag: 'Tags',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.inventory,
        SiteActionCategory.observations,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: true,
      allowMoveActions: false,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: true,
      defaultVisibleEventTypes: {
        EventType.outplant,
        EventType.observation,
        EventType.activity,
      },
      supportedOrganisms: {OrganismKind.finfish},
    ),
    SiteType.baselineSite: SiteCapabilities(
      siteType: SiteType.baselineSite,
      childSectionTitle: 'Monitoring Plots',
      childLabelOverrides: {
        GroupType.zone: 'Zones',
        GroupType.grid: 'Grids',
        GroupType.gridCell: 'Grid Cells',
        GroupType.tag: 'Tags',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.observations,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: false,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: true,
      canReceiveTransfers: false,
      defaultVisibleEventTypes: {
        EventType.observation,
        EventType.activity,
      },
      supportedOrganisms: {
        OrganismKind.coral,
        OrganismKind.oyster,
        OrganismKind.seagrass,
      },
    ),
    SiteType.referenceSite: SiteCapabilities(
      siteType: SiteType.referenceSite,
      childSectionTitle: 'Monitoring Plots',
      childLabelOverrides: {
        GroupType.zone: 'Zones',
        GroupType.grid: 'Grids',
        GroupType.gridCell: 'Grid Cells',
        GroupType.tag: 'Tags',
        GroupType.group: 'Groups',
      },
      enabledActionCategories: {
        SiteActionCategory.observations,
        SiteActionCategory.tasks,
      },
      allowPropagationActions: false,
      allowOutplantActions: false,
      allowMoveActions: false,
      allowEnvironmentalAdjustment: false,
      supportsMonitoringFab: true,
      canReceiveTransfers: false,
      defaultVisibleEventTypes: {
        EventType.observation,
        EventType.activity,
      },
      supportedOrganisms: {
        OrganismKind.coral,
        OrganismKind.oyster,
        OrganismKind.seagrass,
      },
    ),
  };

  /// Resolve capabilities for a given site type.
  static SiteCapabilities resolve(SiteType siteType) {
    return _byType[siteType] ?? _byType[SiteType.nurseryExSitu]!;
  }

  /// Determine the default organism support list for a given site type and
  /// organization configuration.
  static List<OrganismKind> defaultOrganismsForSite(
    SiteType siteType,
    Iterable<OrganismKind> organizationKinds,
  ) {
    final allowed = resolve(siteType).supportedOrganisms;
    final orgSet = organizationKinds.toSet();
    final intersection = allowed
        .where((kind) => orgSet.contains(kind))
        .toList();
    if (intersection.isNotEmpty) {
      return List<OrganismKind>.unmodifiable(intersection);
    }
    if (allowed.isNotEmpty) {
      return List<OrganismKind>.unmodifiable(allowed.toList());
    }
    if (orgSet.isNotEmpty) {
      return [orgSet.first];
    }
    return const [OrganismKind.coral];
  }

  /// Human-friendly label for a group type. Falls back to the group type name.
  String labelForGroupType(GroupType groupType) {
    return childLabelOverrides[groupType] ?? groupType.name;
  }

  /// Build an initial filter map for the activity feed.
  Map<EventType, bool> initialFilterState(Iterable<Event> events) {
    final eventTypes = events.map((event) => event.eventType).toSet();
    final visibleTypeIds = defaultVisibleEventTypes
        .map((type) => type.id)
        .toSet();

    // If no defaults specified, fall back to enabling everything.
    if (visibleTypeIds.isEmpty) {
      return {for (final type in eventTypes) type: true};
    }

    return {
      for (final type in eventTypes) type: visibleTypeIds.contains(type.id),
    };
  }
}
