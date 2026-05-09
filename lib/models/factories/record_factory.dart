import 'package:seafoundry_app/models/factories/event_factory.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class RecordFactoryError extends Error {
  final String message;
  final Map<String, dynamic> json;
  RecordFactoryError({required this.message, required this.json});

  @override
  String toString() {
    final keys = json.keys.take(10).toList();
    final truncatedKeys = keys.length < json.keys.length
        ? '${keys.join(', ')}... (${json.keys.length} total keys)'
        : keys.join(', ');
    return 'RecordFactoryError: $message\n'
        '  Available keys: [$truncatedKeys]\n'
        '  modelType: ${json['modelType']}\n'
        '  id: ${json['id']}';
  }
}

class RecordFactory {
  /// Parse a JSON map into a Record of type T.
  ///
  /// **Required Fields:**
  /// - `modelType`: String matching a [ModelType] enum value (e.g., 'event', 'site', 'group')
  /// - `id`: String identifier for the record
  ///
  /// **For events (`modelType: 'event'`):**
  /// - `eventTypeId`: String identifying the event type
  /// - For snapshot events: `snapshotData` map containing the record snapshot
  ///
  /// Throws [RecordFactoryError] with descriptive message if required fields are missing.
  static T recordFromJson<T extends Record>(Map<String, dynamic> json) {
    // Normalize all nested maps upfront to handle web Firestore's Map<dynamic, dynamic>
    // This prevents TypeError in model fromJson methods for nested map access
    final normalizedJson = deepNormalizeMap(json);

    // Validate required fields upfront with descriptive errors
    final modelTypeStr = normalizedJson['modelType']?.toString();
    if (modelTypeStr == null || modelTypeStr.isEmpty) {
      throw RecordFactoryError(
        message:
            'Missing required field "modelType". '
            'This field must be a string matching a ModelType enum value '
            '(e.g., "event", "site", "group", "organismRecord", "genet").',
        json: json,
      );
    }

    // Validate modelType is a known enum value
    ModelType modelType;
    try {
      modelType = ModelType.values.byName(modelTypeStr);
    } on ArgumentError {
      final validTypes = ModelType.values.map((t) => t.name).join(', ');
      throw RecordFactoryError(
        message:
            'Invalid modelType "$modelTypeStr". '
            'Must be one of: $validTypes',
        json: json,
      );
    }

    try {
      switch (modelType) {
        case (ModelType.user):
          return User.fromJson(normalizedJson) as T;
        case (ModelType.organization):
          return Organization.fromJson(normalizedJson) as T;
        case (ModelType.group):
          return Group.fromJson(normalizedJson) as T;
        case (ModelType.cohort):
          return Cohort.fromJson(normalizedJson) as T;
        case (ModelType.holding):
          return HoldingRecord.fromJson(normalizedJson) as T;
        case (ModelType.genet):
          return Genet.fromJson(normalizedJson) as T;
        case (ModelType.recordType):
          return CustomRecordType.fromJson(normalizedJson) as T;
        case (ModelType.site):
          return Site.fromJson(normalizedJson) as T;
        case (ModelType.zone):
          return Zone.fromJson(normalizedJson) as T;
        case (ModelType.subplot):
          return Subplot.fromJson(normalizedJson) as T;
        case (ModelType.event):
          return EventFactory.eventFromJson(normalizedJson) as T;
        case (ModelType.invitation):
          return Invitation.fromJson(normalizedJson) as T;
        case (ModelType.organismRecord):
          if (normalizedJson.containsKey('organismRecord')) {
            final entry = OrganismRecordEntry.fromJson(normalizedJson);
            if (T == OrganismRecord) {
              return entry.organismRecord as T;
            }
            return entry as T;
          }
          return OrganismRecord.fromJson(normalizedJson) as T;
        case (ModelType.brandProfile):
          return BrandProfile.fromJson(normalizedJson) as T;
        case (ModelType.permit):
          return Permit.fromJson(normalizedJson) as T;
        case (ModelType.deliverable):
          return Deliverable.fromJson(normalizedJson) as T;
        case (ModelType.unknown):
          throw RecordFactoryError(
            message: 'Empty model type',
            json: normalizedJson,
          );
      }
    } on RecordFactoryError {
      rethrow;
    } on FormatException catch (e, stackTrace) {
      LoggingService.instance.error(
        'Format error parsing JSON for type $T: ${e.message}',
        e,
        stackTrace,
      );
      return _incompleteRecordFromJson<T>(normalizedJson);
    } on TypeError catch (e, stackTrace) {
      LoggingService.instance.error(
        'Type error parsing JSON for type $T '
        '(modelType: ${_modelHint(normalizedJson)}): $e',
        e,
        stackTrace,
      );
      _logOrganismRecordHints(normalizedJson);
      return _incompleteRecordFromJson<T>(normalizedJson);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Unexpected error parsing JSON for type $T: $e',
        e,
        stackTrace,
      );
      return _incompleteRecordFromJson<T>(normalizedJson);
    }
  }

  static void _logOrganismRecordHints(Map<String, dynamic> json) {
    final modelType = json['modelType']?.toString();
    if (modelType != ModelType.organismRecord.name) {
      return;
    }
    String describe(dynamic value) {
      if (value == null) return 'null';
      if (value is List) return 'List(${value.length})';
      return value.runtimeType.toString();
    }

    final hints = <String, String>{
      'measurement': describe(json['measurement']),
      'size': describe(json['size']),
      'lifeStage': describe(json['lifeStage']),
      'lifeStageHistory': describe(json['lifeStageHistory']),
      'measurementHistory': describe(json['measurementHistory']),
      'provenanceAttributes': describe(json['provenanceAttributes']),
      'physicalForm': describe(json['physicalForm']),
      'aliases': describe(json['aliases']),
      'foreignKeys': describe(json['foreignKeys']),
      'metadata': describe(json['metadata']),
    };

    LoggingService.instance.error(
      'OrganismRecord field types on parse failure: $hints',
    );
  }

  static T _incompleteRecordFromJson<T extends Record>(
    Map<String, dynamic> json,
  ) {
    // JSON should already be normalized from recordFromJson, but normalize
    // again in case this is called directly
    final normalizedJson = deepNormalizeMap(json);
    try {
      final modelType = ModelType.values.byName(normalizedJson['modelType']);
      switch (modelType) {
        case ModelType.user:
          return User.partial(json: normalizedJson) as T;
        case ModelType.organization:
          return Organization.partial(json: normalizedJson) as T;
        case ModelType.group:
          return Group.partial(json: normalizedJson) as T;
        case ModelType.cohort:
          return Cohort.fromJson(normalizedJson) as T;
        case ModelType.holding:
          return HoldingRecord.fromJson(normalizedJson) as T;
        case ModelType.genet:
          return Genet.partial(json: normalizedJson) as T;
        case ModelType.recordType:
          return CustomRecordType.partial(json: normalizedJson) as T;
        case ModelType.site:
          return Site.partial(json: normalizedJson) as T;
        case ModelType.zone:
          return Zone.partial(json: normalizedJson) as T;
        case ModelType.subplot:
          return Subplot.partial(json: normalizedJson) as T;
        case ModelType.event:
          return EventFactory.incompleteEventFromJson(normalizedJson) as T;
        case ModelType.invitation:
          return Invitation.partial(json: normalizedJson) as T;
        case ModelType.organismRecord:
          if (normalizedJson.containsKey('organismRecord')) {
            final entry = OrganismRecordEntry.fromJson(normalizedJson);
            if (T == OrganismRecord) {
              return entry.organismRecord as T;
            }
            return entry as T;
          }
          return OrganismRecord.fromJson(normalizedJson) as T;
        case ModelType.brandProfile:
          return BrandProfile.partial(json: normalizedJson) as T;
        case ModelType.permit:
          return Permit.partial(json: normalizedJson) as T;
        case ModelType.deliverable:
          return Deliverable.partial(json: normalizedJson) as T;
        case ModelType.unknown:
          throw RecordFactoryError(
            message: 'Empty model type',
            json: normalizedJson,
          );
      }
    } on RecordFactoryError catch (e) {
      LoggingService.instance.error(e.message);
      rethrow;
    } on FormatException catch (e, stackTrace) {
      LoggingService.instance.error(
        'Format error parsing incomplete JSON for type $T: ${e.message}',
        e,
        stackTrace,
      );
      throw RecordFactoryError(
        message: 'Format error parsing JSON for type $T: ${e.message}',
        json: normalizedJson,
      );
    } on TypeError catch (e, stackTrace) {
      LoggingService.instance.error(
        'Type error parsing incomplete JSON for type $T '
        '(modelType: ${_modelHint(normalizedJson)}): $e',
        e,
        stackTrace,
      );
      throw RecordFactoryError(
        message: 'Type error parsing JSON for type $T '
            '(modelType: ${_modelHint(normalizedJson)}): $e',
        json: normalizedJson,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Unexpected error parsing incomplete JSON for type $T: $e',
        e,
        stackTrace,
      );
      throw RecordFactoryError(
        message: 'Unexpected error parsing JSON for type $T: $e',
        json: normalizedJson,
      );
    }
  }

  static String _modelHint(Map<String, dynamic> json) {
    return json['modelType']?.toString() ??
        json['recordModelType']?.toString() ??
        json['recordType']?.toString() ??
        json['type']?.toString() ??
        'unknown';
  }

  static Event eventFromJson(Map<String, dynamic> json) {
    // Normalize before passing to EventFactory
    return EventFactory.eventFromJson(deepNormalizeMap(json));
  }
}
