// @tier: community
import 'dart:convert';

import 'package:seafoundry_app/models/events/biofouling_observation_event.dart';
import 'package:seafoundry_app/models/events/discoloration_observation_event.dart';
import 'package:seafoundry_app/models/events/maintenance_required_observation_event.dart';
import 'package:seafoundry_app/models/events/pest_observation_event.dart';
import 'package:seafoundry_app/models/observation/observation_dialog_schema.dart';
import 'package:seafoundry_app/models/types/observation_severity.dart';
import 'package:seafoundry_app/models/observation/observation_field_override.dart';
import 'package:seafoundry_app/models/types/disease_type.dart';
import 'package:seafoundry_app/models/types/health_issue_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/record_type.dart';
import 'package:yaml/yaml.dart';

typedef ObservationDialogDefinitionBuilder =
    ObservationDialogDefinition Function(
      ObservationDialogDefinitionContext context,
    );
typedef ObservationFieldRegistryListener = void Function();

/// Registry that maps (organism, dialog type) pairs to field definitions so the
/// UI and CSV adapters can render organism-aware observation workflows.
class ObservationFieldRegistry {
  ObservationFieldRegistry._() : _registry = {} {
    registerDefinitions(OrganismKind.coral, _buildCoralDefinitions());
  }

  static final ObservationFieldRegistry instance = ObservationFieldRegistry._();

  final Map<
    OrganismKind,
    Map<ObservationDialogType, List<_ObservationDefinitionEntry>>
  >
  _registry;

  final List<ObservationFieldRegistryListener> _listeners = [];

  ObservationDialogDefinition definitionFor({
    required ObservationDialogType type,
    required OrganismContext context,
    RecordType? recordType,
    String? recordTypeId,
    LifeStage? lifeStage,
    String? lifeStageId,
  }) {
    final normalizedRecordType = _normalizeRecordTypeId(
      recordType?.id ?? recordTypeId,
    );
    final resolvedLifeStage =
        lifeStage ?? LifeStageX.tryParse(lifeStageId?.trim());
    final entry =
        _resolveEntry(
          kind: context.kind,
          type: type,
          recordTypeId: normalizedRecordType,
          lifeStage: resolvedLifeStage,
        ) ??
        _resolveEntry(
          kind: OrganismKind.coral,
          type: type,
          recordTypeId: normalizedRecordType,
          lifeStage: resolvedLifeStage,
        );

    if (entry == null) {
      throw StateError(
        'No observation dialog definition registered for ${type.name}',
      );
    }

    final buildContext = ObservationDialogDefinitionContext(
      organismContext: context,
      recordTypeId: normalizedRecordType,
      lifeStage: resolvedLifeStage,
    );
    final definition = entry.builder(buildContext);

    if (!entry.permitRequired && entry.requiredCapabilities.isEmpty) {
      return definition;
    }

    final mergedCapabilities =
        definition.requiredCapabilities.isEmpty &&
            entry.requiredCapabilities.isEmpty
        ? definition.requiredCapabilities
        : {...definition.requiredCapabilities, ...entry.requiredCapabilities};

    return definition.copyWith(
      permitRequired: definition.permitRequired || entry.permitRequired,
      requiredCapabilities: mergedCapabilities,
    );
  }

  /// Registers or overrides a definition for the provided organism/type pair.
  void registerDefinition({
    required OrganismKind kind,
    required ObservationDialogType type,
    RecordType? recordType,
    String? recordTypeId,
    LifeStage? lifeStage,
    bool overrideExisting = false,
    bool permitRequired = false,
    Set<ObservationSiteCapabilityFlag> requiredCapabilities =
        const <ObservationSiteCapabilityFlag>{},
    required ObservationDialogDefinitionBuilder builder,
  }) {
    final changed = _upsertDefinition(
      kind: kind,
      type: type,
      recordTypeId: recordType?.id ?? recordTypeId,
      lifeStage: lifeStage,
      overrideExisting: overrideExisting,
      permitRequired: permitRequired,
      requiredCapabilities: requiredCapabilities,
      builder: builder,
    );
    if (changed) {
      _notifyListeners();
    }
  }

  /// Registers multiple definitions for the same organism in one operation.
  void registerDefinitions(
    OrganismKind kind,
    Map<ObservationDialogType, ObservationDialogDefinitionBuilder>
    definitions, {
    bool overrideExisting = false,
  }) {
    var changed = false;
    for (final entry in definitions.entries) {
      changed =
          _upsertDefinition(
            kind: kind,
            type: entry.key,
            overrideExisting: overrideExisting,
            builder: entry.value,
          ) ||
          changed;
    }

    if (changed) {
      _notifyListeners();
    }
  }

  /// Removes a definition for the provided organism/type pair, if present.
  void unregisterDefinition(
    OrganismKind kind,
    ObservationDialogType type, {
    RecordType? recordType,
    String? recordTypeId,
    LifeStage? lifeStage,
  }) {
    final definitions = _registry[kind];
    if (definitions == null) {
      return;
    }

    final entries = definitions[type];
    if (entries == null) {
      return;
    }

    final normalizedRecordType = _normalizeRecordTypeId(
      recordType?.id ?? recordTypeId,
    );
    if (normalizedRecordType == null && lifeStage == null) {
      final removed = definitions.remove(type);
      if (removed != null) {
        _notifyListeners();
      }
      return;
    }

    final removedIndex = entries.indexWhere(
      (entry) =>
          entry.recordTypeId == normalizedRecordType &&
          entry.lifeStage == lifeStage,
    );
    if (removedIndex == -1) {
      return;
    }
    entries.removeAt(removedIndex);
    if (entries.isEmpty) {
      definitions.remove(type);
    }
    _notifyListeners();
  }

  /// Clears every definition registered for the specified organism kind.
  void clearDefinitions(OrganismKind kind) {
    if (_registry.remove(kind) != null) {
      _notifyListeners();
    }
  }

  void addListener(ObservationFieldRegistryListener listener) {
    if (_listeners.contains(listener)) {
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(ObservationFieldRegistryListener listener) {
    _listeners.remove(listener);
  }

  /// Loads override definitions from a decoded map (JSON/YAML).
  void loadOverridesFromMap(
    Map<String, dynamic> overrides, {
    bool overrideExisting = true,
  }) {
    if (overrides.isEmpty) {
      return;
    }
    final document = ObservationFieldOverrideDocument.fromJson(overrides);
    _applyOverrideEntries(document.entries, overrideExisting: overrideExisting);
  }

  /// Loads override definitions from a JSON string retrieved remotely.
  void loadOverridesFromJson(String json, {bool overrideExisting = true}) {
    if (json.trim().isEmpty) {
      return;
    }
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError.value(
        decoded,
        'json',
        'Overrides JSON must decode to an object.',
      );
    }
    loadOverridesFromMap(decoded, overrideExisting: overrideExisting);
  }

  /// Loads override definitions from a YAML string.
  void loadOverridesFromYaml(String yaml, {bool overrideExisting = true}) {
    if (yaml.trim().isEmpty) {
      return;
    }
    final yamlNode = loadYaml(yaml);
    if (yamlNode is! YamlMap) {
      throw ArgumentError.value(
        yaml,
        'yaml',
        'Overrides YAML must define a map at the root.',
      );
    }
    final mapped = jsonDecode(jsonEncode(yamlNode)) as Map<String, dynamic>;
    loadOverridesFromMap(mapped, overrideExisting: overrideExisting);
  }

  bool _upsertDefinition({
    required OrganismKind kind,
    required ObservationDialogType type,
    String? recordTypeId,
    LifeStage? lifeStage,
    bool overrideExisting = false,
    bool permitRequired = false,
    Set<ObservationSiteCapabilityFlag> requiredCapabilities =
        const <ObservationSiteCapabilityFlag>{},
    required ObservationDialogDefinitionBuilder builder,
  }) {
    final normalizedRecordType = _normalizeRecordTypeId(recordTypeId);
    final definitions = _registry.putIfAbsent(
      kind,
      () => <ObservationDialogType, List<_ObservationDefinitionEntry>>{},
    );
    final scopedEntries = definitions.putIfAbsent(
      type,
      () => <_ObservationDefinitionEntry>[],
    );

    final existingIndex = scopedEntries.indexWhere(
      (entry) =>
          entry.recordTypeId == normalizedRecordType &&
          entry.lifeStage == lifeStage,
    );

    if (existingIndex != -1 && !overrideExisting) {
      final scopeLabel = _scopeDescription(normalizedRecordType, lifeStage);
      throw StateError(
        'Definition already exists for ${kind.name}/${type.name}$scopeLabel. '
        'Pass overrideExisting: true to replace it.',
      );
    }

    if (existingIndex != -1) {
      scopedEntries.removeAt(existingIndex);
    }

    scopedEntries.add(
      _ObservationDefinitionEntry(
        builder: builder,
        recordTypeId: normalizedRecordType,
        lifeStage: lifeStage,
        permitRequired: permitRequired,
        requiredCapabilities: requiredCapabilities,
      ),
    );
    return true;
  }

  _ObservationDefinitionEntry? _resolveEntry({
    required OrganismKind kind,
    required ObservationDialogType type,
    String? recordTypeId,
    LifeStage? lifeStage,
  }) {
    final entries = _registry[kind]?[type];
    if (entries == null || entries.isEmpty) {
      return null;
    }

    _ObservationDefinitionEntry? best;
    var bestScore = -1;
    for (final entry in entries) {
      final score = _matchScore(entry, recordTypeId, lifeStage);
      if (score > bestScore) {
        best = entry;
        bestScore = score;
      }
    }
    return best;
  }

  int _matchScore(
    _ObservationDefinitionEntry entry,
    String? recordTypeId,
    LifeStage? lifeStage,
  ) {
    if (entry.recordTypeId != null && entry.recordTypeId != recordTypeId) {
      return -1;
    }
    if (entry.lifeStage != null && entry.lifeStage != lifeStage) {
      return -1;
    }

    var score = 0;
    if (entry.recordTypeId != null) {
      score += 2;
    }
    if (entry.lifeStage != null) {
      score += 1;
    }
    return score;
  }

  String? _normalizeRecordTypeId(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lower = trimmed.toLowerCase();
    for (final entry in BuiltinRecordType.builtins.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value.id;
      }
    }
    return lower;
  }

  String _scopeDescription(String? recordTypeId, LifeStage? lifeStage) {
    final parts = <String>[];
    if (recordTypeId != null) {
      parts.add('recordType=$recordTypeId');
    }
    if (lifeStage != null) {
      parts.add('lifeStage=${lifeStage.name}');
    }
    if (parts.isEmpty) {
      return '';
    }
    return ' (${parts.join(', ')})';
  }

  void _notifyListeners() {
    if (_listeners.isEmpty) {
      return;
    }

    final snapshot = List<ObservationFieldRegistryListener>.from(_listeners);
    for (final listener in snapshot) {
      listener();
    }
  }

  void _applyOverrideEntries(
    List<ObservationFieldOverrideEntry> entries, {
    required bool overrideExisting,
  }) {
    if (entries.isEmpty) {
      return;
    }
    for (final entry in entries) {
      registerDefinition(
        kind: entry.organismKind,
        type: entry.dialogType,
        recordTypeId: entry.recordTypeId,
        lifeStage: entry.lifeStage,
        overrideExisting: overrideExisting,
        permitRequired: entry.permitRequired,
        requiredCapabilities: entry.requiredCapabilities,
        builder: (_) => entry.buildDefinition(),
      );
    }
  }

  static Map<ObservationDialogType, ObservationDialogDefinitionBuilder>
  _buildCoralDefinitions() {
    return {
      ObservationDialogType.general: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.general,
        title: 'Record Observation',
        fields: [_targetField(), _commentField(), _imageField()],
        requiredFields: {ObservationDialogField.target},
      ),
      ObservationDialogType.healthIssue: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.healthIssue,
        title: 'Record Observation',
        supportsTaskCreation: true,
        fields: [
          _targetField(),
          ObservationFieldConfig(
            field: ObservationDialogField.healthIssueTypeId,
            kind: ObservationFieldKind.dropdown,
            label: 'Observation Type',
            required: true,
            options: _healthIssueOptions(),
            defaultValue: HealthIssueType.values.first.id,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.createTask,
            kind: ObservationFieldKind.toggle,
            label: 'Create follow-up task',
            defaultValue: true,
          ),
          _commentField(),
          _imageField(),
        ],
        requiredFields: {
          ObservationDialogField.target,
          ObservationDialogField.healthIssueTypeId,
        },
      ),
      ObservationDialogType.biofouling: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.biofouling,
        title: 'Record Biofouling',
        supportsTaskCreation: true,
        fields: [
          _targetField(),
          ObservationFieldConfig(
            field: ObservationDialogField.biofoulingTypeId,
            kind: ObservationFieldKind.dropdown,
            label: 'Biofouling Type',
            required: true,
            options: _biofoulingTypeOptions(),
            defaultValue: BiofoulingType.algae.id,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.severity,
            kind: ObservationFieldKind.dropdown,
            label: 'Severity',
            required: true,
            options: _enumOptions<ObservationSeverity>(
              ObservationSeverity.environmentalScale,
              (s) => s.displayName,
            ),
            defaultValue: ObservationSeverity.moderate.name,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.location,
            kind: ObservationFieldKind.text,
            label: 'Location',
            hint: 'Describe where the biofouling is observed',
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.cleaningPerformed,
            kind: ObservationFieldKind.toggle,
            label: 'Cleaning performed',
            defaultValue: false,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.createTask,
            kind: ObservationFieldKind.toggle,
            label: 'Create follow-up task',
            defaultValue: false,
          ),
          _commentField(),
          _imageField(),
        ],
        requiredFields: {
          ObservationDialogField.target,
          ObservationDialogField.biofoulingTypeId,
          ObservationDialogField.severity,
        },
      ),
      ObservationDialogType.pest: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.pest,
        title: 'Record Pest Observation',
        supportsTaskCreation: true,
        fields: [
          _targetField(),
          ObservationFieldConfig(
            field: ObservationDialogField.pestTypeId,
            kind: ObservationFieldKind.dropdown,
            label: 'Pest Type',
            required: true,
            options: _pestTypeOptions(),
            defaultValue: 'other',
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.severity,
            kind: ObservationFieldKind.dropdown,
            label: 'Severity',
            required: true,
            options: _enumOptions<ObservationSeverity>(
              ObservationSeverity.environmentalScale,
              (s) => s.displayName,
            ),
            defaultValue: ObservationSeverity.moderate.name,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.location,
            kind: ObservationFieldKind.text,
            label: 'Location',
            hint: 'Describe where the pest was found',
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.mitigationPerformed,
            kind: ObservationFieldKind.toggle,
            label: 'Mitigation performed',
            defaultValue: false,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.createTask,
            kind: ObservationFieldKind.toggle,
            label: 'Create follow-up task',
            defaultValue: false,
          ),
          _commentField(),
          _imageField(),
        ],
        requiredFields: {
          ObservationDialogField.target,
          ObservationDialogField.pestTypeId,
          ObservationDialogField.severity,
        },
      ),
      ObservationDialogType.disease: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.disease,
        title: 'Record Disease Observation',
        supportsTaskCreation: true,
        fields: [
          _targetField(),
          ObservationFieldConfig(
            field: ObservationDialogField.diseaseTypeId,
            kind: ObservationFieldKind.dropdown,
            label: 'Disease Type',
            required: true,
            options: _diseaseTypeOptions(),
            defaultValue: DiseaseType.other.id,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.severity,
            kind: ObservationFieldKind.dropdown,
            label: 'Severity',
            required: true,
            options: _enumOptions<ObservationSeverity>(
              ObservationSeverity.clinicalScale,
              (s) => s.displayName,
            ),
            defaultValue: ObservationSeverity.moderate.name,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.affectedPercentage,
            kind: ObservationFieldKind.numeric,
            label: 'Affected Percentage',
            hint: '0 - 100',
            min: 0,
            max: 100,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.createTask,
            kind: ObservationFieldKind.toggle,
            label: 'Create follow-up task',
            defaultValue: true,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.treatmentInitiated,
            kind: ObservationFieldKind.toggle,
            label: 'Treatment initiated',
            defaultValue: false,
          ),
          _commentField(),
          _imageField(),
        ],
        requiredFields: {
          ObservationDialogField.target,
          ObservationDialogField.diseaseTypeId,
          ObservationDialogField.severity,
        },
      ),
      ObservationDialogType.discoloration: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.discoloration,
        title: 'Record Discoloration',
        supportsTaskCreation: true,
        fields: [
          _targetField(),
          ObservationFieldConfig(
            field: ObservationDialogField.discolorationTypeId,
            kind: ObservationFieldKind.dropdown,
            label: 'Discoloration Type',
            required: true,
            options: _discolorationTypeOptions(),
            defaultValue: 'other',
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.extent,
            kind: ObservationFieldKind.dropdown,
            label: 'Extent',
            required: true,
            options: _enumOptions<DiscolorationExtent>(
              DiscolorationExtent.values,
              (s) => s.label,
            ),
            defaultValue: DiscolorationExtent.partial.name,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.affectedPercentage,
            kind: ObservationFieldKind.numeric,
            label: 'Affected Percentage',
            hint: '0 - 100',
            min: 0,
            max: 100,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.trend,
            kind: ObservationFieldKind.dropdown,
            label: 'Trend',
            options: const [
              ObservationFieldOption(value: 'improving', label: 'Improving'),
              ObservationFieldOption(value: 'stable', label: 'Stable'),
              ObservationFieldOption(value: 'worsening', label: 'Worsening'),
            ],
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.createTask,
            kind: ObservationFieldKind.toggle,
            label: 'Create follow-up task',
            defaultValue: false,
          ),
          _commentField(),
          _imageField(),
        ],
        requiredFields: {
          ObservationDialogField.target,
          ObservationDialogField.discolorationTypeId,
          ObservationDialogField.extent,
        },
      ),
      ObservationDialogType.maintenanceRequired: (_) =>
          ObservationDialogDefinition(
            type: ObservationDialogType.maintenanceRequired,
            title: 'Record Maintenance Need',
            supportsTaskCreation: true,
            fields: [
              _targetField(),
              ObservationFieldConfig(
                field: ObservationDialogField.maintenanceTypeId,
                kind: ObservationFieldKind.dropdown,
                label: 'Maintenance Type',
                required: true,
                options: _maintenanceTypeOptions(),
                defaultValue: 'other',
              ),
              ObservationFieldConfig(
                field: ObservationDialogField.priority,
                kind: ObservationFieldKind.dropdown,
                label: 'Priority',
                required: true,
                options: _enumOptions<MaintenancePriority>(
                  MaintenancePriority.values,
                  (s) => s.label,
                ),
                defaultValue: MaintenancePriority.medium.name,
              ),
              ObservationFieldConfig(
                field: ObservationDialogField.completed,
                kind: ObservationFieldKind.toggle,
                label: 'Completed',
                defaultValue: false,
              ),
              ObservationFieldConfig(
                field: ObservationDialogField.completedAt,
                kind: ObservationFieldKind.date,
                label: 'Completed on',
                hint: 'Select completion date',
              ),
              ObservationFieldConfig(
                field: ObservationDialogField.createTask,
                kind: ObservationFieldKind.toggle,
                label: 'Create follow-up task',
                defaultValue: false,
              ),
              _commentField(),
              _imageField(),
            ],
            requiredFields: {
              ObservationDialogField.target,
              ObservationDialogField.maintenanceTypeId,
              ObservationDialogField.priority,
            },
          ),
      ObservationDialogType.thermalStress: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.thermalStress,
        title: 'Record Thermal Stress',
        supportsTaskCreation: true,
        fields: [
          _targetField(),
          ObservationFieldConfig(
            field: ObservationDialogField.severity,
            kind: ObservationFieldKind.dropdown,
            label: 'Severity',
            required: true,
            options: const [
              ObservationFieldOption(value: 'mild', label: 'Mild'),
              ObservationFieldOption(value: 'moderate', label: 'Moderate'),
              ObservationFieldOption(value: 'severe', label: 'Severe'),
            ],
            defaultValue: 'moderate',
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.affectedPercentage,
            kind: ObservationFieldKind.numeric,
            label: 'Affected Percentage',
            hint: '0 - 100',
            min: 0,
            max: 100,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.createTask,
            kind: ObservationFieldKind.toggle,
            label: 'Create follow-up task',
            defaultValue: false,
          ),
          _commentField(),
          _imageField(),
        ],
        requiredFields: {
          ObservationDialogField.target,
          ObservationDialogField.severity,
        },
      ),
      ObservationDialogType.bleaching: (_) => ObservationDialogDefinition(
        type: ObservationDialogType.bleaching,
        title: 'Record Bleaching',
        supportsTaskCreation: true,
        fields: [
          _targetField(),
          ObservationFieldConfig(
            field: ObservationDialogField.discolorationTypeId,
            kind: ObservationFieldKind.dropdown,
            label: 'Bleaching Type',
            required: true,
            options: _discolorationTypeOptions(),
            defaultValue: 'other',
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.extent,
            kind: ObservationFieldKind.dropdown,
            label: 'Extent',
            required: true,
            options: _enumOptions<DiscolorationExtent>(
              DiscolorationExtent.values,
              (s) => s.label,
            ),
            defaultValue: DiscolorationExtent.partial.name,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.affectedPercentage,
            kind: ObservationFieldKind.numeric,
            label: 'Affected Percentage',
            hint: '0 - 100',
            min: 0,
            max: 100,
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.trend,
            kind: ObservationFieldKind.dropdown,
            label: 'Trend',
            options: const [
              ObservationFieldOption(value: 'improving', label: 'Improving'),
              ObservationFieldOption(value: 'stable', label: 'Stable'),
              ObservationFieldOption(value: 'worsening', label: 'Worsening'),
            ],
          ),
          ObservationFieldConfig(
            field: ObservationDialogField.createTask,
            kind: ObservationFieldKind.toggle,
            label: 'Create follow-up task',
            defaultValue: false,
          ),
          _commentField(),
          _imageField(),
        ],
        requiredFields: {
          ObservationDialogField.target,
          ObservationDialogField.discolorationTypeId,
          ObservationDialogField.extent,
        },
      ),
    };
  }

  static ObservationFieldConfig _targetField() => const ObservationFieldConfig(
    field: ObservationDialogField.target,
    kind: ObservationFieldKind.targetPicker,
    label: 'Target',
    required: true,
  );

  static ObservationFieldConfig _commentField() => const ObservationFieldConfig(
    field: ObservationDialogField.comment,
    kind: ObservationFieldKind.multilineText,
    label: 'Comment',
  );

  static ObservationFieldConfig _imageField() => const ObservationFieldConfig(
    field: ObservationDialogField.imageUrl,
    kind: ObservationFieldKind.text,
    label: 'Image URL',
    hint: 'Populated by image capture workflow',
  );

  static List<ObservationFieldOption> _healthIssueOptions() {
    return HealthIssueType.values
        .map(
          (issue) =>
              ObservationFieldOption(value: issue.id, label: issue.label),
        )
        .toList(growable: false);
  }

  static List<ObservationFieldOption> _biofoulingTypeOptions() {
    return BiofoulingType.allValues
        .map(
          (type) => ObservationFieldOption(value: type.id, label: type.label),
        )
        .toList(growable: false);
  }

  static List<ObservationFieldOption> _pestTypeOptions() {
    return PestType.values
        .map(
          (type) => ObservationFieldOption(value: type.id, label: type.label),
        )
        .toList(growable: false);
  }

  static List<ObservationFieldOption> _diseaseTypeOptions() {
    return DiseaseType.builtins.values
        .map((type) => ObservationFieldOption(value: type.id, label: type.name))
        .toList(growable: false);
  }

  static List<ObservationFieldOption> _discolorationTypeOptions() {
    return DiscolorationType.values
        .map(
          (type) => ObservationFieldOption(value: type.id, label: type.label),
        )
        .toList(growable: false);
  }

  static List<ObservationFieldOption> _maintenanceTypeOptions() {
    return MaintenanceRequiredType.values
        .map(
          (type) => ObservationFieldOption(value: type.id, label: type.label),
        )
        .toList(growable: false);
  }

  static List<ObservationFieldOption> _enumOptions<T>(
    List<T> values,
    String Function(T value) toLabel,
  ) {
    return values
        .map(
          (value) => ObservationFieldOption(
            value: value.toString().split('.').last,
            label: toLabel(value),
          ),
        )
        .toList(growable: false);
  }
}

class _ObservationDefinitionEntry {
  _ObservationDefinitionEntry({
    required this.builder,
    this.recordTypeId,
    this.lifeStage,
    this.permitRequired = false,
    Set<ObservationSiteCapabilityFlag>? requiredCapabilities,
  }) : requiredCapabilities = Set<ObservationSiteCapabilityFlag>.unmodifiable(
         requiredCapabilities ?? const <ObservationSiteCapabilityFlag>{},
       );

  final ObservationDialogDefinitionBuilder builder;
  final String? recordTypeId;
  final LifeStage? lifeStage;
  final bool permitRequired;
  final Set<ObservationSiteCapabilityFlag> requiredCapabilities;
}
