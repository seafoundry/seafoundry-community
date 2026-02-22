// @tier: community
// NOTE: Service is community for infrastructure, but threshold UI features
// are pro-gated via FeatureAccessService.
import 'package:seafoundry_app/models/environment/environmental_threshold.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/environmental_threshold_registry.dart';

class EnvironmentalThresholdService {
  EnvironmentalThresholdService({EnvironmentalThresholdRegistry? registry})
    : _registry = registry ?? EnvironmentalThresholdRegistry.instance;

  final EnvironmentalThresholdRegistry _registry;

  List<EnvironmentalAlert> evaluate({
    required OrganismKind organismKind,
    LifeStage? lifeStage,
    required Map<String, num> measurements,
  }) {
    final alerts = <EnvironmentalAlert>[];
    for (final entry in _registry.thresholdsFor(
      organismKind: organismKind,
      lifeStage: lifeStage,
    )) {
      final measurement = measurements[entry.metric]?.toDouble();
      if (measurement == null) continue;
      final breached = _violates(entry, measurement);
      if (breached) {
        alerts.add(EnvironmentalAlert(threshold: entry, value: measurement));
      }
    }
    return alerts;
  }

  bool _violates(EnvironmentalThreshold threshold, double value) {
    if (threshold.minValue != null && value < threshold.minValue!) {
      return true;
    }
    if (threshold.maxValue != null && value > threshold.maxValue!) {
      return true;
    }
    return false;
  }
}
