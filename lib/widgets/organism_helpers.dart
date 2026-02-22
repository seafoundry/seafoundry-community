// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Static helper class for determining organism icons based on life stage,
/// physical form, and organism kind.
class OrganismIconHelper {
  OrganismIconHelper._();

  /// Returns the appropriate icon for an organism based on life stage,
  /// physical form, and organism kind (in that priority order).
  static IconData getIcon(
    OrganismKind organismKind, [
    LifeStage? lifeStage,
    PhysicalFormInstance? physicalForm,
  ]) {
    // Priority 1: Life stage icons
    if (lifeStage != null && lifeStage != LifeStage.unknown) {
      switch (lifeStage) {
        case LifeStage.unknown:
          break; // Fall through to organism kind default
        case LifeStage.gamete:
          return Icons.science;
        case LifeStage.embryo:
          return Icons.lens;
        case LifeStage.larva:
          return Icons.bug_report;
        case LifeStage.juvenile:
          return Icons.spa;
        case LifeStage.adult:
          return Icons.pets;
        case LifeStage.broodstock:
          return Icons.favorite;
      }
    }

    // Priority 2: Physical form icons (if available)
    if (physicalForm != null) {
      final formId = physicalForm.formId.toLowerCase();
      if (formId.contains('fragment')) {
        return Icons.content_cut;
      } else if (formId.contains('substrate') || formId.contains('tile')) {
        return Icons.grid_on;
      } else if (formId.contains('colony')) {
        return Icons.scatter_plot;
      } else if (formId.contains('vial') || formId.contains('container')) {
        return Icons.water_drop;
      }
    }

    // Priority 3: Organism kind defaults
    switch (organismKind) {
      case OrganismKind.coral:
        return Icons.scatter_plot; // Coral-like icon representing polyp structure
      case OrganismKind.oyster:
        return Icons.water;
      case OrganismKind.seagrass:
        return Icons.grass;
      case OrganismKind.kelp:
        return Icons.waves;
      case OrganismKind.mangrove:
        return Icons.park;
      case OrganismKind.echinoid:
        return Icons.circle_outlined;
      case OrganismKind.crab:
        return Icons.set_meal;
      case OrganismKind.finfish:
        return Icons.water_damage;
      case OrganismKind.seaCucumber:
        return Icons.horizontal_rule;
    }
  }
}

/// Static helper class for determining organism colors based on health status,
/// size class, and organism kind.
class OrganismColorHelper {
  OrganismColorHelper._();

  /// Returns the appropriate color for an organism based on health status,
  /// size class, and organism kind (in that priority order).
  static Color getColor(
    OrganismKind organismKind, {
    SizeSpec? sizeSpec,
    HealthStatus? healthStatus,
  }) {
    // Priority 1: Health status colors (overrides everything)
    if (healthStatus != null) {
      if (healthStatus.isUnhealthy) {
        return AppColors.error;
      } else if (healthStatus == HealthStatus.recovering) {
        return AppColors.warning;
      } else if (healthStatus == HealthStatus.stressed) {
        return AppColors.warning;
      } else if (healthStatus.isHealthy) {
        return AppColors.success;
      } else if (healthStatus == HealthStatus.deceased ||
          healthStatus == HealthStatus.lost) {
        return AppColors.disabled;
      }
    }

    // Priority 2: Size class coloring
    if (sizeSpec != null && sizeSpec.sizeClass != null) {
      final sizeClass = sizeSpec.sizeClass!.toLowerCase();
      if (sizeClass == 'xs' || sizeClass == 'extra_small') {
        return Colors.blue;
      } else if (sizeClass == 's' || sizeClass == 'small') {
        return Colors.green;
      } else if (sizeClass == 'm' || sizeClass == 'medium') {
        return Colors.orange;
      } else if (sizeClass == 'l' || sizeClass == 'large') {
        return Colors.red;
      } else if (sizeClass == 'xl' || sizeClass == 'extra_large') {
        return Colors.deepPurple;
      }
    }

    // Priority 3: Organism kind defaults
    switch (organismKind) {
      case OrganismKind.coral:
        return AppColors.coralColor;
      case OrganismKind.oyster:
        return Colors.grey;
      case OrganismKind.seagrass:
        return Colors.lightGreen;
      case OrganismKind.kelp:
        return Colors.brown;
      case OrganismKind.mangrove:
        return Colors.green;
      case OrganismKind.echinoid:
        return Colors.purple;
      case OrganismKind.crab:
        return Colors.deepOrange;
      case OrganismKind.finfish:
        return Colors.cyan;
      case OrganismKind.seaCucumber:
        return Colors.teal;
    }
  }
}

/// Widget that renders an organism icon using OrganismIconHelper and
/// OrganismColorHelper to determine the appropriate icon and color.
class OrganismIconWidget extends StatelessWidget {
  const OrganismIconWidget({
    super.key,
    required this.organism,
    this.size = UI.iconSizeMd,
    this.showBackground = false,
  });

  final OrganismRecord organism;
  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final icon = OrganismIconHelper.getIcon(
      organism.organismKind,
      organism.lifeStage.stage,
      organism.physicalForm,
    );

    // Health status is stored in metadata
    final healthStatusId = organism.metadata?['healthStatus'] as String?;
    final healthStatus = HealthStatus.maybeFromId(healthStatusId);

    final color = OrganismColorHelper.getColor(
      organism.organismKind,
      sizeSpec: organism.sizeSpec,
      healthStatus: healthStatus,
    );

    if (showBackground) {
      return UI.roundedIcon(
        icon,
        size: size,
        backgroundColor: color.withValues(alpha: 0.1),
        iconColor: color,
      );
    }

    return Icon(
      icon,
      size: size,
      color: color,
    );
  }
}
