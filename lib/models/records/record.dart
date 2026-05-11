import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Base class for all persistent records in the SeaFoundry data model.
///
/// ## Overview
/// [Record] is the foundational class for all entities persisted to Firestore.
/// It defines the common fields required for auditing and identity:
/// - [id]: Unique identifier (UUID or auto-generated)
/// - [createdAt]/[updatedAt]: ISO 8601 timestamps for auditing
/// - [createdById]/[updatedById]: User IDs for change tracking
/// - [organizationId]: Multi-tenant isolation key
/// - [metadata]: Flexible extension point for custom fields
///
/// ## Subclass Hierarchy
/// ```
/// Record
/// ├── GraphNodeRecord (navigable entities with urlPath/internalPath)
/// │   ├── Organization
/// │   ├── Site
/// │   ├── Group
/// │   └── OrganismRecord
/// ├── Event (audit log entries)
/// └── User (authentication records)
/// ```
///
/// ## JSON Serialization
/// Records support flexible JSON parsing that gracefully handles:
/// - Direct field access (`json['id']`)
/// - Nested `createdEvent` fallback for event-sourced records
/// - Path-based organizationId inference from `urlPath`/`internalPath`
///
/// See [fromJson] constructor and helper methods like [inferOrganizationId].
///
/// ## Equatable
/// Records use [Equatable] for value-based equality. Subclasses must override
/// [props] to include all fields that contribute to identity.
abstract class Record extends Equatable {
  const Record({
    required this.id,
    required this.createdAt,
    required this.createdById,
    required this.updatedAt,
    required this.updatedById,
    required this.organizationId,
    this.metadata,
  });
  final String id;
  final String createdAt;
  final String createdById;
  final String updatedAt;
  final String updatedById;
  final String organizationId;
  final Map<String, dynamic>? metadata;
  ModelType get modelType;
  DateTime get createdAtDateTime => DateTime.parse(createdAt);
  DateTime get updatedAtDateTime => DateTime.parse(updatedAt);

  static Map<String, dynamic>? createdEvent(Map<String, dynamic> json) {
    final createdEvent = json['createdEvent'];
    return createdEvent is Map<String, dynamic> ? createdEvent : null;
  }

  static String? stringFromJson(Map<String, dynamic> json, String key) {
    String? asString(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return value;
      if (value is Timestamp) return value.toDate().toIso8601String();
      if (value is DateTime) return value.toIso8601String();
      return null;
    }

    final value = asString(json[key]);
    if (value != null) {
      return value;
    }
    final createdEventValue = asString(createdEvent(json)?[key]);
    return createdEventValue;
  }

  static String? inferOrganizationId(Map<String, dynamic> json) {
    final direct = json['organizationId'];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }
    final createdEventOrg = createdEvent(json)?['organizationId'];
    if (createdEventOrg is String && createdEventOrg.isNotEmpty) {
      return createdEventOrg;
    }

    String? segmentFromPath(String? path) {
      if (path == null || path.isEmpty) {
        return null;
      }
      final firstSegment = path.split('/').first;
      return firstSegment.isNotEmpty ? firstSegment : null;
    }

    final internalPath = segmentFromPath(json['internalPath'] as String?);
    if (internalPath != null) {
      return internalPath;
    }

    final urlPath = segmentFromPath(json['urlPath'] as String?);
    if (urlPath != null) {
      return urlPath;
    }

    final createdEventInternalPath = segmentFromPath(
      createdEvent(json)?['internalPath'] as String?,
    );
    if (createdEventInternalPath != null) {
      return createdEventInternalPath;
    }

    return null;
  }

  static String? inferId(Map<String, dynamic> json) {
    final direct = json['id'];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }
    final createdEventId = createdEvent(json)?['recordId'];
    if (createdEventId is String && createdEventId.isNotEmpty) {
      return createdEventId;
    }
    return null;
  }

  Record.fromJson(Map<String, dynamic> json)
    : id = inferId(json) ?? Missing.string,
      createdAt = stringFromJson(json, 'createdAt') ?? Missing.dateTimeString,
      createdById = stringFromJson(json, 'createdById') ?? Missing.string,
      updatedAt =
          stringFromJson(json, 'updatedAt') ??
          stringFromJson(json, 'createdAt') ??
          Missing.dateTimeString,
      updatedById =
          stringFromJson(json, 'updatedById') ??
          stringFromJson(json, 'createdById') ??
          Missing.string,
      organizationId = inferOrganizationId(json) ?? Missing.string,
      metadata = _metadataFromJson(json['metadata']);

  Record.partial({
    Map<String, dynamic>? json,
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    Map<String, dynamic>? metadata,
  }) : id = id ?? (json != null ? inferId(json) : null) ?? Missing.string,
       createdAt =
           createdAt ??
           (json != null ? stringFromJson(json, 'createdAt') : null) ??
           Missing.dateTimeString,
       createdById =
           createdById ??
           (json != null ? stringFromJson(json, 'createdById') : null) ??
           Missing.string,
       updatedAt =
           updatedAt ??
           (json != null ? stringFromJson(json, 'updatedAt') : null) ??
           (json != null ? stringFromJson(json, 'createdAt') : null) ??
           Missing.dateTimeString,
       updatedById =
           updatedById ??
           (json != null ? stringFromJson(json, 'updatedById') : null) ??
           (json != null ? stringFromJson(json, 'createdById') : null) ??
           Missing.string,
       organizationId =
           organizationId ??
           (json != null ? inferOrganizationId(json) : null) ??
           Missing.string,
       metadata =
           metadata ??
           (json != null ? _metadataFromJson(json['metadata']) : null);

  @mustCallSuper
  Map<String, dynamic> toJson() {
    if (!validate()) {
      LoggingService.instance.error("Serializing invalid record: $this");
    }
    final payload = <String, dynamic>{
      'id': id,
      'modelType': modelType.name,
      'createdAt': createdAt,
      'createdById': createdById,
      'updatedAt': updatedAt,
      'updatedById': updatedById,
      'organizationId': organizationId,
    };
    if (metadata != null && metadata!.isNotEmpty) {
      payload['metadata'] = metadata;
    }
    return payload;
  }

  Record copyWith();

  @mustCallSuper
  bool validate() {
    return !props.any((prop) {
      if (prop == null) {
        // optional props can be null
        return false;
      }
      return prop.isMissing;
    });
  }

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [
    id,
    modelType,
    createdAt,
    createdById,
    updatedAt,
    updatedById,
    organizationId,
    _metadataFingerprint,
  ];

  static Map<String, dynamic>? _metadataFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map.unmodifiable(Map<String, dynamic>.from(value));
    }
    if (value is Map) {
      final normalized = <String, dynamic>{};
      value.forEach((key, dynamic entryValue) {
        if (key == null) {
          return;
        }
        normalized[key.toString()] = entryValue;
      });
      return Map.unmodifiable(normalized);
    }
    return null;
  }

  String? get _metadataFingerprint {
    if (metadata == null || metadata!.isEmpty) {
      return null;
    }
    final entries = metadata!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer
        ..write(entry.key)
        ..write('=')
        ..write(entry.value)
        ..write(';');
    }
    return buffer.toString();
  }
}

extension Missing on Object {
  static const String string = '__missing__';
  static const String dateTimeString = '1937-07-02T00:00:00.000';

  bool get isMissing =>
      this == '' ||
      this == string ||
      this == dateTimeString ||
      this == ModelType.unknown;
}
