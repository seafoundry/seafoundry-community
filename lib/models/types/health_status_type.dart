// @tier: community
import 'package:seafoundry_app/models/types/status_event_type.dart';

/// Types of coral health issues that can be observed
class HealthStatusType extends StatusEventType {
  const HealthStatusType._({required super.id, required super.name, required this.description});

  final String description;

  static final Map<String, HealthStatusType> builtins = {
    biofouling.id: biofouling,
    disease.id: disease,
    discoloration.id: discoloration,
  };

  /// Biofouling - Unwanted growth of organisms on coral surface
  static const HealthStatusType biofouling = HealthStatusType._(
    id: 'health_status_biofouling',
    name: 'Biofouling',
    description: 'Unwanted growth of organisms on coral surface',
  );

  /// Disease - Signs of coral disease or infection
  static const HealthStatusType disease = HealthStatusType._(
    id: 'health_status_disease',
    name: 'Disease',
    description: 'Signs of coral disease or infection',
  );

  /// Stressed - Signs of coral stress
  static const HealthStatusType stressed = HealthStatusType._(
    id: 'health_status_stressed',
    name: 'Stressed',
    description: 'Signs of coral stress',
  );

  /// Discoloration - Abnormal coloration or bleaching
  static const HealthStatusType discoloration = HealthStatusType._(
    id: 'health_status_discoloration',
    name: 'Discoloration',
    description: 'Abnormal coloration or bleaching',
  );
}
