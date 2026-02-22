// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';

/// Dialog categories supported by the consolidated observation workflow.
enum ObservationDialogType {
  general,

  /// Health Issue logs an observation without changing organism status.
  ///
  /// Use this when recording a health-related observation (disease, pest,
  /// stress, etc.) that does NOT mutate the organism's canonical health
  /// status field.  To change health status, use `HealthStatusDialog` instead.
  healthIssue,
  biofouling,
  pest,
  disease,
  discoloration,
  maintenanceRequired,
  thermalStress,
  bleaching,
  imageUpload,
}

/// Extension providing human-readable display names for dialog types.
extension ObservationDialogTypeX on ObservationDialogType {
  /// Returns a human-readable display name for the dialog type.
  String get displayName => switch (this) {
        ObservationDialogType.general => 'General',
        ObservationDialogType.healthIssue => 'Health Issue',
        ObservationDialogType.biofouling => 'Biofouling',
        ObservationDialogType.pest => 'Pest',
        ObservationDialogType.disease => 'Disease',
        ObservationDialogType.discoloration => 'Discoloration',
        ObservationDialogType.maintenanceRequired => 'Maintenance',
        ObservationDialogType.thermalStress => 'Thermal Stress',
        ObservationDialogType.bleaching => 'Bleaching',
        ObservationDialogType.imageUpload => 'Image Upload',
      };
}

/// Fields that can appear in an observation dialog.
enum ObservationDialogField {
  target,
  comment,
  imageUrl,
  healthIssueTypeId,
  createTask,
  biofoulingTypeId,
  pestTypeId,
  diseaseTypeId,
  discolorationTypeId,
  maintenanceTypeId,
  severity,
  extent,
  affectedPercentage,
  trend,
  location,
  cleaningPerformed,
  mitigationPerformed,
  treatmentInitiated,
  priority,
  completed,
  completedAt,
}

/// Input widget styles used by the observation dialog.
enum ObservationFieldKind {
  targetPicker,
  dropdown,
  text,
  multilineText,
  numeric,
  toggle,
  date,
}

/// An option supplied to dropdown-style fields.
class ObservationFieldOption extends Equatable {
  const ObservationFieldOption({required this.value, required this.label});

  final String value;
  final String label;

  @override
  List<Object?> get props => [value, label];
}

/// Describes a single field within a dialog configuration.
class ObservationFieldConfig extends Equatable {
  const ObservationFieldConfig({
    required this.field,
    required this.kind,
    required this.label,
    this.hint,
    this.required = false,
    this.options = const <ObservationFieldOption>[],
    this.defaultValue,
    this.min,
    this.max,
  });

  final ObservationDialogField field;
  final ObservationFieldKind kind;
  final String label;
  final String? hint;
  final bool required;
  final List<ObservationFieldOption> options;
  final Object? defaultValue;
  final num? min;
  final num? max;

  @override
  List<Object?> get props => [
    field,
    kind,
    label,
    hint,
    required,
    options,
    defaultValue,
    min,
    max,
  ];
}

/// Gating metadata used when evaluating whether a definition can run within the
/// current GraphNode/site context.
enum ObservationSiteCapabilityFlag {
  allowPropagationActions,
  allowOutplantActions,
  allowMoveActions,
  allowEnvironmentalAdjustment,
  supportsMonitoringFab,
}

/// Context passed to registry builders so organism-specific logic can inspect
/// life stage or record type metadata when composing definitions.
class ObservationDialogDefinitionContext extends Equatable {
  const ObservationDialogDefinitionContext({
    required this.organismContext,
    this.recordTypeId,
    this.lifeStage,
  });

  final OrganismContext organismContext;
  final String? recordTypeId;
  final LifeStage? lifeStage;

  @override
  List<Object?> get props => [organismContext, recordTypeId, lifeStage];
}

/// Raw registry response describing how a dialog should be composed.
class ObservationDialogDefinition extends Equatable {
  ObservationDialogDefinition({
    required this.type,
    required this.title,
    required List<ObservationFieldConfig> fields,
    Set<ObservationDialogField>? requiredFields,
    this.supportsTaskCreation = false,
    this.permitRequired = false,
    Set<ObservationSiteCapabilityFlag>? requiredCapabilities,
  }) : fields = List.unmodifiable(fields),
       requiredFields = Set.unmodifiable(
         requiredFields ?? const <ObservationDialogField>{},
       ),
       requiredCapabilities = Set.unmodifiable(
         requiredCapabilities ?? const <ObservationSiteCapabilityFlag>{},
       );

  final ObservationDialogType type;
  final String title;
  final bool supportsTaskCreation;
  final List<ObservationFieldConfig> fields;
  final Set<ObservationDialogField> requiredFields;
  final bool permitRequired;
  final Set<ObservationSiteCapabilityFlag> requiredCapabilities;

  ObservationDialogDefinition copyWith({
    List<ObservationFieldConfig>? fields,
    Set<ObservationDialogField>? requiredFields,
    bool? supportsTaskCreation,
    bool? permitRequired,
    Set<ObservationSiteCapabilityFlag>? requiredCapabilities,
  }) {
    return ObservationDialogDefinition(
      type: type,
      title: title,
      supportsTaskCreation: supportsTaskCreation ?? this.supportsTaskCreation,
      fields: fields ?? this.fields,
      requiredFields: requiredFields ?? this.requiredFields,
      permitRequired: permitRequired ?? this.permitRequired,
      requiredCapabilities:
          requiredCapabilities ?? this.requiredCapabilities,
    );
  }

  @override
  List<Object?> get props => [
    type,
    title,
    supportsTaskCreation,
    fields,
    requiredFields,
    permitRequired,
    requiredCapabilities,
  ];
}
