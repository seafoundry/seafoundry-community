// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/events/structure_maintenance_event.dart';
import 'package:seafoundry_app/models/types/health_issue_type.dart';

/// Types of husbandry actions that can be performed
class HusbandryActionType extends Equatable {
  static const String generalId = 'general';
  static const String maintenanceNeededId = 'maintenance_needed';
  static const String legacyMaintenanceCompletedId = 'maintenance_completed';

  final String id;
  final String label;
  final String description;
  final HealthIssueType? relatedHealthIssue;

  /// Which site environments this action type is applicable to.
  /// If empty, the type is applicable to all environments.
  final Set<SiteEnvironment> applicableEnvironments;

  const HusbandryActionType._({
    required this.id,
    required this.label,
    required this.description,
    this.relatedHealthIssue,
    this.applicableEnvironments = const {},
  });

  /// Whether this action type is applicable to all site environments
  bool get isUniversal => applicableEnvironments.isEmpty;

  /// Whether this action type is applicable to the given environment
  bool isApplicableTo(SiteEnvironment environment) {
    return isUniversal || applicableEnvironments.contains(environment);
  }

  /// Get HusbandryActionType by ID, returns null if not found.
  ///
  /// Use this when the action type is optional or when you need to handle
  /// missing/invalid IDs gracefully.
  static HusbandryActionType? maybeFromId(String? id) {
    if (id == null) return null;
    final normalizedId = id == legacyMaintenanceCompletedId
        ? maintenanceNeededId
        : id;
    for (final type in values) {
      if (type.id == normalizedId) return type;
    }
    return null;
  }

  /// Get HusbandryActionType by ID, returns a custom action type if not found.
  ///
  /// This never returns null - unknown IDs are wrapped in a custom action type.
  /// For nullable semantics, use [maybeFromId] instead.
  static HusbandryActionType fromId(String? id) {
    if (id == null) return general;
    return maybeFromId(id) ?? HusbandryActionType._(
      id: id,
      label: 'Custom',
      description: 'Custom husbandry action',
    );
  }

  /// General - Catch-all for tasks that don't fit a specific type
  static const HusbandryActionType general = HusbandryActionType._(
    id: generalId,
    label: 'General',
    description: 'General husbandry task',
  );

  /// Cleaning - Removing biofouling or debris
  static const HusbandryActionType cleaning = HusbandryActionType._(
    id: 'cleaning',
    label: 'Cleaning',
    description: 'Removing biofouling or debris',
    relatedHealthIssue: HealthIssueType.biofouling,
  );

  /// Treatment Required - Medical treatment for disease
  static const HusbandryActionType treatmentApplied = HusbandryActionType._(
    id: 'treatment_applied',
    label: 'Treatment Required',
    description: 'Medical treatment for disease',
    relatedHealthIssue: HealthIssueType.disease,
  );

  /// Maintenance Needed - Fixing physical or structural issues
  static const HusbandryActionType maintenanceNeeded = HusbandryActionType._(
    id: maintenanceNeededId,
    label: 'Maintenance Needed',
    description: 'Fixing physical or structural issues',
    relatedHealthIssue: HealthIssueType.maintenanceNeeded,
  );

  /// Environmental Adjustment - Changing environmental conditions
  /// Only applicable to ex-situ environments where parameters can be controlled
  static const HusbandryActionType environmentalAdjustment =
      HusbandryActionType._(
        id: 'environmental_adjustment',
        label: 'Environmental Adjustment',
        description: 'Changing environmental conditions',
        relatedHealthIssue: HealthIssueType.discoloration,
        applicableEnvironments: {SiteEnvironment.exSitu},
      );

  /// Water Quality Test - Testing water parameters
  /// Only applicable to ex-situ environments with controlled water systems
  static const HusbandryActionType waterQualityTest = HusbandryActionType._(
    id: 'water_quality_test',
    label: 'Water Quality Test',
    description: 'Testing water parameters',
    applicableEnvironments: {SiteEnvironment.exSitu},
  );

  /// Feeding - Providing nutrition to corals
  static const HusbandryActionType feeding = HusbandryActionType._(
    id: 'feeding',
    label: 'Feeding',
    description: 'Providing nutrition to corals',
  );

  /// List of all standard husbandry action types
  static const List<HusbandryActionType> values = [
    general,
    cleaning,
    treatmentApplied,
    maintenanceNeeded,
    environmentalAdjustment,
    waterQualityTest,
    feeding,
  ];

  /// Get husbandry action types applicable to a specific site environment
  static List<HusbandryActionType> valuesFor(SiteEnvironment environment) {
    return values.where((type) => type.isApplicableTo(environment)).toList();
  }

  /// Find the husbandry action type that corresponds to a health issue
  static HusbandryActionType? forHealthIssue(HealthIssueType healthIssue) {
    if (healthIssue.id == HealthIssueType.general.id) {
      return HusbandryActionType.general;
    }
    try {
      return values.firstWhere(
        (type) => type.relatedHealthIssue == healthIssue,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  List<Object?> get props => [id];
}
