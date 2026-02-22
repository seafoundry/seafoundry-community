// @tier: community
import 'package:seafoundry_app/models/events/structure_maintenance_event.dart';
import 'package:seafoundry_app/models/types/record_type.dart';

/// Builtin task types that define categories of husbandry/maintenance tasks.
///
/// These types serve as the base set of task categories that can be extended
/// with custom types by Pro tier organizations.
class TaskType extends BuiltinRecordType {
  final String? description;

  /// Which site environments this task type is applicable to.
  /// If empty, the type is applicable to all environments.
  final Set<SiteEnvironment> applicableEnvironments;

  const TaskType({
    required super.id,
    required super.name,
    this.description,
    this.applicableEnvironments = const {},
  });

  /// Whether this task type is applicable to all site environments
  bool get isUniversal => applicableEnvironments.isEmpty;

  /// Whether this task type is applicable to the given environment
  bool isApplicableTo(SiteEnvironment environment) {
    return isUniversal || applicableEnvironments.contains(environment);
  }

  /// Get task types applicable to a specific site environment
  static List<TaskType> valuesFor(SiteEnvironment environment) {
    return values.where((type) => type.isApplicableTo(environment)).toList();
  }

  // ==========================================================================
  // BUILTIN TASK TYPES
  // ==========================================================================

  static const TaskType general = TaskType(
    id: 'task_type_general',
    name: 'General',
    description: 'General husbandry task',
  );

  static const TaskType cleaning = TaskType(
    id: 'task_type_cleaning',
    name: 'Cleaning',
    description: 'Removing biofouling or debris',
  );

  static const TaskType treatment = TaskType(
    id: 'task_type_treatment',
    name: 'Treatment',
    description: 'Medical treatment for disease or health issues',
  );

  static const TaskType maintenance = TaskType(
    id: 'task_type_maintenance',
    name: 'Maintenance',
    description: 'Fixing physical or structural issues',
  );

  static const TaskType environmentalAdjustment = TaskType(
    id: 'task_type_environmental_adjustment',
    name: 'Environmental Adjustment',
    description: 'Changing environmental conditions',
    applicableEnvironments: {SiteEnvironment.exSitu},
  );

  static const TaskType waterQualityTest = TaskType(
    id: 'task_type_water_quality_test',
    name: 'Water Quality Test',
    description: 'Testing water parameters',
    applicableEnvironments: {SiteEnvironment.exSitu},
  );

  static const TaskType feeding = TaskType(
    id: 'task_type_feeding',
    name: 'Feeding',
    description: 'Providing nutrition to organisms',
  );

  static const TaskType acquireOrthomosaic = TaskType(
    id: 'task_type_acquire_orthomosaic',
    name: 'Acquire Orthomosaic',
    description: 'Capture orthomosaic imagery',
    applicableEnvironments: {SiteEnvironment.inSitu},
  );

  static const TaskType sitePrep = TaskType(
    id: 'task_type_site_prep',
    name: 'Site Prep',
    description: 'Prepare site for outplanting',
    applicableEnvironments: {SiteEnvironment.inSitu},
  );

  static const TaskType ecologicalSurvey = TaskType(
    id: 'task_type_ecological_survey',
    name: 'Ecological Survey',
    description: 'Record ecological survey data',
  );

  static const TaskType logWaterConditions = TaskType(
    id: 'task_type_log_water_conditions',
    name: 'Log Water Conditions',
    description: 'Record water quality parameters',
  );

  /// Ordered list of builtin task types
  static const List<TaskType> values = [
    general,
    cleaning,
    treatment,
    maintenance,
    environmentalAdjustment,
    waterQualityTest,
    feeding,
    acquireOrthomosaic,
    sitePrep,
    ecologicalSurvey,
    logWaterConditions,
  ];

  /// Map of ID to TaskType for quick lookup
  static final Map<String, TaskType> builtins = {
    for (final type in values) type.id: type,
  };

  /// Look up a builtin task type by ID
  static TaskType? fromId(String? id) {
    if (id == null) return null;
    return builtins[id];
  }
}
