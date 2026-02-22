// @tier: community
import 'package:seafoundry_app/models/observation/observation_dialog_schema.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

class ObservationFieldOverrideDocument {
  ObservationFieldOverrideDocument({required this.entries});

  factory ObservationFieldOverrideDocument.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawEntries = json['overrides'] ??
        json['entries'] ??
        json['definitions'] ??
        (json.containsKey('title') ? [json] : const []);
    if (rawEntries is! List) {
      throw ArgumentError.value(
        rawEntries,
        'overrides',
        'Overrides document must contain a list of entries under '
            '`overrides`, `entries`, or `definitions`.',
      );
    }
    final entries = rawEntries
        .map(
          (entry) => ObservationFieldOverrideEntry.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList(growable: false);
    return ObservationFieldOverrideDocument(entries: entries);
  }

  final List<ObservationFieldOverrideEntry> entries;

  Map<String, dynamic> toJson() {
    return {
      'overrides': entries.map((entry) => entry.toJson()).toList(),
    };
  }
}

/// Extension providing a unique key for entry identification and deduplication.
extension ObservationFieldOverrideEntryX on ObservationFieldOverrideEntry {
  /// Generates a unique key based on the entry's identifying properties.
  ///
  /// Used for deduplication, comparison, and lookup operations.
  String get uniqueKey => [
        organismKind.name,
        dialogType.name,
        title,
        recordTypeId ?? '',
        lifeStage?.name ?? '',
      ].join('|');
}

class ObservationFieldOverrideEntry {
  ObservationFieldOverrideEntry({
    required this.organismKind,
    required this.dialogType,
    required this.title,
    required this.fields,
    required this.requiredFields,
    this.recordTypeId,
    this.lifeStage,
    this.supportsTaskCreation = false,
    this.permitRequired = false,
    Set<ObservationSiteCapabilityFlag>? requiredCapabilities,
  }) : requiredCapabilities =
            requiredCapabilities ??
            const <ObservationSiteCapabilityFlag>{};

  factory ObservationFieldOverrideEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    final organismKind = _parseOrganismKind(json['organismKind']);
    final dialogType = _parseDialogType(json['dialogType']);
    final recordTypeId = (json['recordTypeId'] ?? json['recordType']) as String?;
    final lifeStage = _parseLifeStage(json['lifeStage']);
    final supportsTaskCreation = json['supportsTaskCreation'] == true;
    final permitRequired = json['permitRequired'] == true;
    final requiredCapabilities = _parseCapabilityFlags(
      json['requiredCapabilities'],
    );

    final fields = _parseFieldConfigs(json['fields']);
    final requiredFields = _parseRequiredFields(json['requiredFields']);
    final title = (json['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      throw ArgumentError.value(
        json['title'],
        'title',
        'Observation field override entries must include a title.',
      );
    }

    return ObservationFieldOverrideEntry(
      organismKind: organismKind,
      dialogType: dialogType,
      recordTypeId: recordTypeId,
      lifeStage: lifeStage,
      title: title,
      fields: fields,
      requiredFields: requiredFields,
      supportsTaskCreation: supportsTaskCreation,
      permitRequired: permitRequired,
      requiredCapabilities: requiredCapabilities,
    );
  }

  final OrganismKind organismKind;
  final ObservationDialogType dialogType;
  final String title;
  final String? recordTypeId;
  final LifeStage? lifeStage;
  final bool supportsTaskCreation;
  final bool permitRequired;
  final List<ObservationFieldConfig> fields;
  final Set<ObservationDialogField> requiredFields;
  final Set<ObservationSiteCapabilityFlag> requiredCapabilities;

  ObservationDialogDefinition buildDefinition() {
    return ObservationDialogDefinition(
      type: dialogType,
      title: title,
      supportsTaskCreation: supportsTaskCreation,
      fields: fields,
      requiredFields: requiredFields,
      permitRequired: permitRequired,
      requiredCapabilities: requiredCapabilities,
    );
  }

  static OrganismKind _parseOrganismKind(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return OrganismKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => throw ArgumentError.value(
          value,
          'organismKind',
          'Unknown organism kind',
        ),
      );
    }
    throw ArgumentError.value(value, 'organismKind', 'Value required');
  }

  static ObservationDialogType _parseDialogType(dynamic value) {
    if (value is String && value.isNotEmpty) {
      // Legacy fallback: "health" was renamed to "healthIssue" in 2C.1.
      final normalized = value == 'health' ? 'healthIssue' : value;
      return ObservationDialogType.values.firstWhere(
        (type) => type.name == normalized,
        orElse: () => throw ArgumentError.value(
          value,
          'dialogType',
          'Unknown observation dialog type',
        ),
      );
    }
    throw ArgumentError.value(value, 'dialogType', 'Value required');
  }

  static LifeStage? _parseLifeStage(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return LifeStageX.tryParse(value);
    }
    return null;
  }

  static Set<ObservationSiteCapabilityFlag> _parseCapabilityFlags(
    dynamic raw,
  ) {
    if (raw is! List) {
      return const <ObservationSiteCapabilityFlag>{};
    }
    return raw
        .whereType<String>()
        .map(
          (flag) => ObservationSiteCapabilityFlag.values.firstWhere(
            (value) => value.name == flag,
            orElse: () => throw ArgumentError.value(
              flag,
              'requiredCapabilities',
              'Unknown capability flag',
            ),
          ),
        )
        .toSet();
  }

  static List<ObservationFieldConfig> _parseFieldConfigs(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      throw ArgumentError.value(
        raw,
        'fields',
        'Each override entry must include at least one field definition.',
      );
    }
    return raw.map((field) {
      final map = Map<String, dynamic>.from(field as Map);
      final dialogField = _parseDialogField(map['field']);
      final kind = _parseFieldKind(map['kind']);
      final label = (map['label'] as String?)?.trim() ?? dialogField.name;
      final hint = (map['hint'] as String?)?.trim();
      final required = map['required'] == true;
      final defaultValue = map['defaultValue'];
      final min = map['min'];
      final max = map['max'];
      final options = _parseOptions(map['options']);

      return ObservationFieldConfig(
        field: dialogField,
        kind: kind,
        label: label,
        hint: hint,
        required: required,
        options: options,
        defaultValue: defaultValue,
        min: min is num ? min : null,
        max: max is num ? max : null,
      );
    }).toList(growable: false);
  }

  static ObservationDialogField _parseDialogField(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return ObservationDialogField.values.firstWhere(
        (field) => field.name == value,
        orElse: () => throw ArgumentError.value(
          value,
          'field',
          'Unknown observation field id',
        ),
      );
    }
    throw ArgumentError.value(value, 'field', 'Value required');
  }

  static ObservationFieldKind _parseFieldKind(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return ObservationFieldKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => throw ArgumentError.value(
          value,
          'kind',
          'Unknown field kind',
        ),
      );
    }
    throw ArgumentError.value(value, 'kind', 'Value required');
  }

  static List<ObservationFieldOption> _parseOptions(dynamic raw) {
    if (raw is! List) {
      return const <ObservationFieldOption>[];
    }
    return raw.map((option) {
      final map = Map<String, dynamic>.from(option as Map);
      final value = map['value']?.toString();
      final label = map['label']?.toString();
      if (value == null || label == null) {
        throw ArgumentError.value(
          option,
          'options',
          'Options must include value and label',
        );
      }
      return ObservationFieldOption(value: value, label: label);
    }).toList(growable: false);
  }

  static Set<ObservationDialogField> _parseRequiredFields(dynamic raw) {
    if (raw is! List) {
      return const <ObservationDialogField>{};
    }
    return raw
        .whereType<String>()
        .map(_parseDialogField)
        .toSet();
  }

  Map<String, dynamic> toJson() {
    return {
      'organismKind': organismKind.name,
      'dialogType': dialogType.name,
      if (recordTypeId != null) 'recordTypeId': recordTypeId,
      if (lifeStage != null) 'lifeStage': lifeStage!.name,
      'title': title,
      'supportsTaskCreation': supportsTaskCreation,
      'permitRequired': permitRequired,
      'requiredCapabilities':
          requiredCapabilities.map((flag) => flag.name).toList(),
      'requiredFields':
          requiredFields.map((field) => field.name).toList(growable: false),
      'fields': fields.map(_fieldToJson).toList(growable: false),
    };
  }

  Map<String, dynamic> _fieldToJson(ObservationFieldConfig field) {
    return {
      'field': field.field.name,
      'kind': field.kind.name,
      'label': field.label,
      if (field.hint != null) 'hint': field.hint,
      'required': field.required,
      if (field.defaultValue != null) 'defaultValue': field.defaultValue,
      if (field.min != null) 'min': field.min,
      if (field.max != null) 'max': field.max,
      if (field.options.isNotEmpty)
        'options': field.options
            .map((option) => {
                  'value': option.value,
                  'label': option.label,
                })
            .toList(growable: false),
    };
  }
}
