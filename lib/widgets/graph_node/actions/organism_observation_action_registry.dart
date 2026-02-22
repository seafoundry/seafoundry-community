// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/models/observation/observation_dialog_schema.dart';

class OrganismObservationAction {
  const OrganismObservationAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.dialogType,
    this.overrideDefault = true,
    this.allowedSiteTypes,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final ObservationDialogType dialogType;
  final bool overrideDefault;
  final Set<SiteType>? allowedSiteTypes;
}

class OrganismObservationActionRegistry {
  static final Map<OrganismKind, List<OrganismObservationAction>> _registry = {
    OrganismKind.coral: [
      OrganismObservationAction(
        icon: Icons.thermostat,
        iconColor: Colors.red,
        title: 'Record Thermal Stress',
        subtitle: 'Track thermal stress in outplanted corals',
        dialogType: ObservationDialogType.thermalStress,
        allowedSiteTypes: {
          SiteType.nurseryInSitu,
          SiteType.outplanting,
          SiteType.baselineSite,
          SiteType.referenceSite,
        },
      ),
      OrganismObservationAction(
        icon: Icons.palette,
        iconColor: Colors.amber,
        title: 'Record Bleaching',
        subtitle: 'Record coral bleaching observations',
        dialogType: ObservationDialogType.bleaching,
        allowedSiteTypes: {
          SiteType.nurseryInSitu,
          SiteType.outplanting,
          SiteType.baselineSite,
          SiteType.referenceSite,
        },
      ),
    ],
    OrganismKind.kelp: [
      OrganismObservationAction(
        icon: Icons.eco,
        iconColor: Colors.teal,
        title: 'Inspect Kelp Longline',
        subtitle: 'Log biofouling and blade condition',
        dialogType: ObservationDialogType.biofouling,
      ),
    ],
    OrganismKind.oyster: [
      OrganismObservationAction(
        icon: Icons.medical_services,
        iconColor: Colors.deepOrange,
        title: 'Check Oyster Bag Health',
        subtitle: 'Capture disease or stress indicators',
        dialogType: ObservationDialogType.disease,
      ),
    ],
    OrganismKind.finfish: [
      OrganismObservationAction(
        icon: Icons.health_and_safety,
        iconColor: Colors.blueGrey,
        title: 'Pen Health Inspection',
        subtitle: 'Record finfish behavior and stress cues',
        dialogType: ObservationDialogType.healthIssue,
      ),
    ],
    OrganismKind.crab: [
      OrganismObservationAction(
        icon: Icons.visibility,
        iconColor: Colors.brown,
        title: 'Pond Observation',
        subtitle: 'Log behavior or pond conditions',
        dialogType: ObservationDialogType.general,
      ),
    ],
    OrganismKind.seagrass: [
      OrganismObservationAction(
        icon: Icons.spa,
        iconColor: Colors.green,
        title: 'Monitor Seagrass Module',
        subtitle: 'Capture coverage and canopy notes',
        dialogType: ObservationDialogType.general,
      ),
    ],
    OrganismKind.mangrove: [
      OrganismObservationAction(
        icon: Icons.nature,
        iconColor: Colors.brown,
        title: 'Monitor Mangrove Plot',
        subtitle: 'Track color change or stress signals',
        dialogType: ObservationDialogType.discoloration,
      ),
    ],
    OrganismKind.echinoid: [
      OrganismObservationAction(
        icon: Icons.visibility,
        iconColor: Colors.deepPurple,
        title: 'Urchin Observation',
        subtitle: 'Log density and grazing behavior',
        dialogType: ObservationDialogType.general,
        overrideDefault: false,
      ),
    ],
    OrganismKind.seaCucumber: [
      OrganismObservationAction(
        icon: Icons.scatter_plot,
        iconColor: Colors.amber,
        title: 'Sea Cucumber Patrol',
        subtitle: 'Capture stress or disease indicators',
        dialogType: ObservationDialogType.healthIssue,
        overrideDefault: false,
      ),
    ],
  };

  static Map<OrganismKind, List<OrganismObservationAction>>? _testingOverrides;

  static List<OrganismObservationAction> actionsFor(OrganismKind kind) {
    final override = _testingOverrides?[kind];
    if (override != null) return override;
    return _registry[kind] ?? const [];
  }

  static bool hasActions(OrganismKind kind) => actionsFor(kind).isNotEmpty;

  @visibleForTesting
  static void debugOverrideActions(
    OrganismKind kind,
    List<OrganismObservationAction> actions,
  ) {
    _testingOverrides ??= {};
    _testingOverrides![kind] = List<OrganismObservationAction>.unmodifiable(
      actions,
    );
  }

  @visibleForTesting
  static void resetDebugOverrides() {
    _testingOverrides?.clear();
  }
}
