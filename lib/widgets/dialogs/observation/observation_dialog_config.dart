// @tier: community
import 'dart:collection';
import 'package:flutter/material.dart';

import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/observation/observation_dialog_schema.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/record_type.dart';
import 'package:seafoundry_app/services/observation_field_registry.dart';

export 'package:seafoundry_app/models/observation/observation_dialog_schema.dart';

/// Structured configuration describing how a specific observation dialog should behave.
class ObservationDialogConfig extends Equatable {
  static final ObservationFieldRegistry _registry =
      ObservationFieldRegistry.instance..addListener(_handleRegistryChanged);

  ObservationDialogConfig._({
    required this.type,
    required this.title,
    required List<ObservationFieldConfig> fields,
    Set<ObservationDialogField>? requiredFields,
    this.supportsTaskCreation = false,
    this.permitRequired = false,
    Set<ObservationSiteCapabilityFlag>? requiredCapabilities,
  }) : fields = List.unmodifiable(fields),
       requiredFields = (requiredFields ?? const <ObservationDialogField>{}),
       requiredCapabilities = Set.unmodifiable(
         requiredCapabilities ?? const <ObservationSiteCapabilityFlag>{},
       ),
       _fieldMap = UnmodifiableMapView({
         for (final field in fields) field.field: field,
       });

  final ObservationDialogType type;
  final String title;
  final bool supportsTaskCreation;
  final bool permitRequired;
  final Set<ObservationSiteCapabilityFlag> requiredCapabilities;
  final List<ObservationFieldConfig> fields;
  final Set<ObservationDialogField> requiredFields;
  final Map<ObservationDialogField, ObservationFieldConfig> _fieldMap;
  static final Map<String, ObservationDialogConfig> _configCache = {};

  IconData get icon => _getIconForType(type);
  Color get iconColor => _getIconColorForType(type);

  static IconData _getIconForType(ObservationDialogType type) {
    switch (type) {
      case ObservationDialogType.general:
        return Icons.visibility;
      case ObservationDialogType.healthIssue:
        return Icons.health_and_safety;
      case ObservationDialogType.biofouling:
        return Icons.grass;
      case ObservationDialogType.pest:
        return Icons.bug_report;
      case ObservationDialogType.disease:
        return Icons.coronavirus;
      case ObservationDialogType.discoloration:
        return Icons.palette;
      case ObservationDialogType.maintenanceRequired:
        return Icons.build;
      case ObservationDialogType.thermalStress:
        return Icons.thermostat;
      case ObservationDialogType.bleaching:
        return Icons.opacity;
      case ObservationDialogType.imageUpload:
        return Icons.camera_alt;
    }
  }

  static Color _getIconColorForType(ObservationDialogType type) {
    switch (type) {
      case ObservationDialogType.general:
        return Colors.blue;
      case ObservationDialogType.healthIssue:
        return Colors.red;
      case ObservationDialogType.biofouling:
        return Colors.green;
      case ObservationDialogType.pest:
        return Colors.orange;
      case ObservationDialogType.disease:
        return Colors.red;
      case ObservationDialogType.discoloration:
        return Colors.purple;
      case ObservationDialogType.maintenanceRequired:
        return Colors.amber;
      case ObservationDialogType.thermalStress:
        return Colors.deepOrange;
      case ObservationDialogType.bleaching:
        return Colors.grey;
      case ObservationDialogType.imageUpload:
        return Colors.blue;
    }
  }

  /// Returns `true` if the specified field is present in this configuration.
  bool isFieldEnabled(ObservationDialogField field) =>
      _fieldMap.containsKey(field);

  /// Returns `true` if the specified field must be provided by the user.
  bool isFieldRequired(ObservationDialogField field) =>
      requiredFields.contains(field);

  /// Returns configuration details for a field, or `null` if the field is not used.
  ObservationFieldConfig? fieldConfig(ObservationDialogField field) =>
      _fieldMap[field];

  /// All supported observation dialog configurations.
  static ObservationDialogConfig forType(
    ObservationDialogType type, {
    OrganismContext? context,
    RecordType? recordType,
    LifeStage? lifeStage,
  }) {
    final resolvedContext =
        context ?? OrganismContext.forKind(OrganismKind.coral);
    final cacheKey = [
      type.name,
      resolvedContext.kind.name,
      recordType?.id ?? 'any',
      lifeStage?.name ?? 'any',
    ].join('_');
    return _configCache.putIfAbsent(
      cacheKey,
      () => _buildConfig(
        type,
        resolvedContext,
        recordType: recordType,
        lifeStage: lifeStage,
      ),
    );
  }

  /// Clears the cached configurations. Used when the registry updates.
  static void invalidateCache() => _configCache.clear();

  static void _handleRegistryChanged() => invalidateCache();

  static ObservationDialogConfig _buildConfig(
    ObservationDialogType type,
    OrganismContext context, {
    RecordType? recordType,
    LifeStage? lifeStage,
  }) {
    if (type == ObservationDialogType.imageUpload) {
      throw UnsupportedError(
        'ImageUpload observation type should use ImageObservationDialog directly',
      );
    }

    final definition = _registry.definitionFor(
      type: type,
      context: context,
      recordType: recordType,
      lifeStage: lifeStage,
      lifeStageId: lifeStage?.id,
    );

    return ObservationDialogConfig._(
      type: definition.type,
      title: definition.title,
      supportsTaskCreation: definition.supportsTaskCreation,
      fields: definition.fields,
      requiredFields: definition.requiredFields,
      permitRequired: definition.permitRequired,
      requiredCapabilities: definition.requiredCapabilities,
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
