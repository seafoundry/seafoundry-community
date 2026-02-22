// @tier: community
import 'package:equatable/equatable.dart';

/// Types of coral health issues that can be observed
class HealthIssueType extends Equatable {
  final String id;
  final String label;
  final String description;

  const HealthIssueType._({
    required this.id,
    required this.label,
    required this.description,
  });

  /// Create a HealthIssueType from an ID
  static HealthIssueType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => HealthIssueType._(
        id: id,
        label: 'Custom',
        description: 'Custom health issue type',
      ),
    );
  }

  /// General - Observation without a specific issue type
  static const HealthIssueType general = HealthIssueType._(
    id: 'general',
    label: 'General',
    description: 'Observation without a specific issue type',
  );

  /// Biofouling - Unwanted growth of organisms on coral surface
  static const HealthIssueType biofouling = HealthIssueType._(
    id: 'biofouling',
    label: 'Biofouling',
    description: 'Unwanted growth of organisms on coral surface',
  );

  /// Disease - Signs of coral disease or infection
  static const HealthIssueType disease = HealthIssueType._(
    id: 'disease',
    label: 'Disease',
    description: 'Signs of coral disease or infection',
  );

  /// Maintenance Needed - Physical damage or structural issues requiring maintenance
  static const HealthIssueType maintenanceNeeded = HealthIssueType._(
    id: 'maintenance_needed',
    label: 'Maintenance Needed',
    description: 'Physical damage or structural issues requiring maintenance',
  );

  /// Discoloration - Abnormal coloration or bleaching
  static const HealthIssueType discoloration = HealthIssueType._(
    id: 'discoloration',
    label: 'Discoloration',
    description: 'Abnormal coloration or bleaching',
  );

  /// Thermal Stress - Stress response due to elevated temperatures
  static const HealthIssueType thermalStress = HealthIssueType._(
    id: 'thermal_stress',
    label: 'Thermal Stress',
    description: 'Stress response caused by elevated temperatures',
  );

  /// List of all standard health issue types
  static const List<HealthIssueType> values = [
    general,
    biofouling,
    disease,
    maintenanceNeeded,
    discoloration,
    thermalStress,
  ];

  @override
  List<Object?> get props => [id];
}
