// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

class OrganismHusbandryAction {
  const OrganismHusbandryAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.eventType,
    this.overrideDefault = true,
    this.allowedSiteTypes,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final HusbandryEventType eventType;
  final bool overrideDefault;
  final Set<SiteType>? allowedSiteTypes;
}

class OrganismHusbandryActionRegistry {
  static final Map<OrganismKind, List<OrganismHusbandryAction>> _registry = {
    OrganismKind.kelp: [
      OrganismHusbandryAction(
        icon: Icons.cleaning_services,
        iconColor: Colors.teal,
        title: 'Clean Longline Hardware',
        subtitle: 'Remove fouling and rebalance tension',
        eventType: HusbandryEventType.cleaning,
      ),
    ],
    OrganismKind.oyster: [
      OrganismHusbandryAction(
        icon: Icons.build,
        iconColor: Colors.indigo,
        title: 'Bag Maintenance',
        subtitle: 'Repair racks, flip bags, and log work',
        eventType: HusbandryEventType.structureMaintenance,
      ),
    ],
    OrganismKind.finfish: [
      OrganismHusbandryAction(
        icon: Icons.restaurant,
        iconColor: Colors.orange,
        title: 'Feed Pen Cohort',
        subtitle: 'Log ration and feed conversion data',
        eventType: HusbandryEventType.feeding,
      ),
    ],
    OrganismKind.crab: [
      OrganismHusbandryAction(
        icon: Icons.water,
        iconColor: Colors.blueGrey,
        title: 'Log Pond Water Parameters',
        subtitle: 'Capture daily DO, pH, and nutrients',
        eventType: HusbandryEventType.logWaterConditions,
      ),
    ],
    OrganismKind.seagrass: [
      OrganismHusbandryAction(
        icon: Icons.map,
        iconColor: Colors.green,
        title: 'Ecological Survey',
        subtitle: 'Record module surveys for this plot',
        eventType: HusbandryEventType.ecologicalSurvey,
        allowedSiteTypes: {
          SiteType.outplanting,
          SiteType.baselineSite,
          SiteType.referenceSite,
          SiteType.seagrassPlot,
        },
      ),
    ],
    OrganismKind.mangrove: [
      OrganismHusbandryAction(
        icon: Icons.nature_people,
        iconColor: Colors.brown,
        title: 'Mangrove Site Prep',
        subtitle: 'Log sediment work and plot prep tasks',
        eventType: HusbandryEventType.sitePrep,
        allowedSiteTypes: {
          SiteType.outplanting,
          SiteType.mangroveOutplant,
        },
      ),
    ],
    OrganismKind.echinoid: [
      OrganismHusbandryAction(
        icon: Icons.cleaning_services,
        iconColor: Colors.deepPurple,
        title: 'Urchin Habitat Cleaning',
        subtitle: 'Rinse trays and remove macroalgae',
        eventType: HusbandryEventType.cleaning,
      ),
    ],
    OrganismKind.seaCucumber: [
      OrganismHusbandryAction(
        icon: Icons.emoji_nature,
        iconColor: Colors.teal,
        title: 'Sea Cucumber Site Prep',
        subtitle: 'Log sediment tilling and predator sweeps',
        eventType: HusbandryEventType.sitePrep,
        allowedSiteTypes: {
          SiteType.outplanting,
          SiteType.reefAquaculture,
        },
      ),
    ],
  };

  static Map<OrganismKind, List<OrganismHusbandryAction>>? _testingOverrides;

  static List<OrganismHusbandryAction> actionsFor(OrganismKind kind) {
    final override = _testingOverrides?[kind];
    if (override != null) return override;
    return _registry[kind] ?? const [];
  }

  static bool hasActions(OrganismKind kind) => actionsFor(kind).isNotEmpty;

  @visibleForTesting
  static void debugOverrideActions(
    OrganismKind kind,
    List<OrganismHusbandryAction> actions,
  ) {
    _testingOverrides ??= {};
    _testingOverrides![kind] = List<OrganismHusbandryAction>.unmodifiable(
      actions,
    );
  }

  @visibleForTesting
  static void resetDebugOverrides() {
    _testingOverrides?.clear();
  }
}
