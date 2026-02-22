// @tier: community
// NOTE: Model is community for infrastructure, but threshold UI features
// are pro-gated via FeatureAccessService.
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/interfaces/organism_kind_entry.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';

enum EnvironmentalAlertSeverity { info, warning, critical }

class EnvironmentalThreshold extends Equatable implements OrganismKindEntry {
  const EnvironmentalThreshold({
    required this.id,
    required this.metric,
    required this.organismKind,
    this.siteId,
    this.lifeStage,
    this.minValue,
    this.maxValue,
    this.units,
    this.recommendedAction,
    this.severity = EnvironmentalAlertSeverity.warning,
  });

  factory EnvironmentalThreshold.fromMap(
    OrganismKind organismKind,
    Map<String, dynamic> map,
  ) {
    final metric = map['metric']?.toString() ?? 'unknownMetric';
    final lifeStage = LifeStageX.tryParse(map['lifeStage']?.toString());
    final minValue = safeDouble(map['min']);
    final maxValue = safeDouble(map['max']);
    final severity = EnvironmentalAlertSeverity.values.firstWhere(
      (value) => value.name == (map['severity']?.toString() ?? 'warning'),
      orElse: () => EnvironmentalAlertSeverity.warning,
    );
    return EnvironmentalThreshold(
      id:
          map['id']?.toString() ??
          _fallbackId(
            organismKind: organismKind,
            metric: metric,
            lifeStage: lifeStage,
            severity: severity,
            minValue: minValue,
            maxValue: maxValue,
          ),
      metric: metric,
      organismKind: organismKind,
      lifeStage: lifeStage,
      minValue: minValue,
      maxValue: maxValue,
      units: map['units']?.toString(),
      recommendedAction: map['action']?.toString(),
      severity: severity,
    );
  }

  @override
  final String id;
  final String metric;
  @override
  final OrganismKind organismKind;
  final String? siteId; // Optional: if null, applies to all sites for this organism
  final LifeStage? lifeStage;
  final double? minValue;
  final double? maxValue;
  final String? units;
  final String? recommendedAction;
  final EnvironmentalAlertSeverity severity;

  @override
  String get displayName => metric;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'metric': metric,
    'organismKind': organismKind.name,
    if (siteId != null) 'siteId': siteId,
    if (lifeStage != null) 'lifeStage': lifeStage!.id,
    if (minValue != null) 'min': minValue,
    if (maxValue != null) 'max': maxValue,
    if (units != null) 'units': units,
    if (recommendedAction != null) 'action': recommendedAction,
    'severity': severity.name,
  };

  @override
  List<Object?> get props => [
    id,
    metric,
    organismKind,
    siteId,
    lifeStage,
    minValue,
    maxValue,
    units,
    recommendedAction,
    severity,
  ];
}

class EnvironmentalAlert extends Equatable {
  const EnvironmentalAlert({required this.threshold, required this.value});

  final EnvironmentalThreshold threshold;
  final double value;

  @override
  List<Object?> get props => [threshold, value];
}

String _fallbackId({
  required OrganismKind organismKind,
  required String metric,
  required EnvironmentalAlertSeverity severity,
  LifeStage? lifeStage,
  double? minValue,
  double? maxValue,
}) {
  final parts = <String>[
    organismKind.name,
    slug(metric),
    lifeStage?.id ?? 'any',
    severity.name,
    'min_${minValue?.toString() ?? 'none'}',
    'max_${maxValue?.toString() ?? 'none'}',
  ];
  return parts.join('_');
}
