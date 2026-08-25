import 'package:seafoundry_community/models/factories/record_factory.dart';
import 'package:seafoundry_community/models/records/inventory_record.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/services/logging_service.dart';

mixin SnapshotEvent {
  InventoryRecord get snapshot;

  static InventoryRecord snapshotFromJson(Map<String, dynamic> json) {
    final snapshotData = json['snapshotData'];
    if (snapshotData is Map<String, dynamic> && snapshotData.isNotEmpty) {
      final normalized = Map<String, dynamic>.from(snapshotData);

      // Backfill required inventory fields when omitted from snapshotData
      normalized.putIfAbsent(
        'modelType',
        () => json['recordModelType'] ?? ModelType.unknown.name,
      );
      normalized.putIfAbsent('id', () => json['recordId']);
      normalized.putIfAbsent('organizationId', () => json['organizationId']);
      normalized.putIfAbsent('createdAt', () => json['createdAt']);
      normalized.putIfAbsent(
        'updatedAt',
        () => json['updatedAt'] ?? json['createdAt'],
      );
      normalized.putIfAbsent('createdById', () => json['createdById']);
      normalized.putIfAbsent('updatedById', () => json['updatedById']);

      return RecordFactory.recordFromJson(normalized);
    }

    final recordModelType = json['recordModelType'];
    if (recordModelType is String && recordModelType.isNotEmpty) {
      LoggingService.instance.warning(
        'SnapshotEvent: Missing snapshotData for ${json['id'] ?? json['recordId'] ?? 'unknown event'} '
        '($recordModelType). Using event metadata as fallback snapshot.',
      );

      final fallbackSnapshot = <String, dynamic>{
        'modelType': recordModelType,
        if (json['recordId'] is String) 'id': json['recordId'],
        if (json['createdAt'] is String) 'createdAt': json['createdAt'],
        if (json['createdById'] is String) 'createdById': json['createdById'],
        if (json['updatedAt'] is String)
          'updatedAt': json['updatedAt']
        else if (json['createdAt'] is String)
          'updatedAt': json['createdAt'],
        if (json['updatedById'] is String)
          'updatedById': json['updatedById']
        else if (json['createdById'] is String)
          'updatedById': json['createdById'],
        if (json['organizationId'] is String)
          'organizationId': json['organizationId'],
        if (json['urlPath'] is String) 'urlPath': json['urlPath'],
        if (json['internalPath'] is String)
          'internalPath': json['internalPath'],
        if (json['slug'] is String) 'slug': json['slug'],
      };

      // Preserve created event metadata when available to help downstream inference.
      final createdEvent = json['createdEvent'];
      if (createdEvent is Map<String, dynamic>) {
        fallbackSnapshot['createdEvent'] = createdEvent;
      }

      try {
        return RecordFactory.recordFromJson(fallbackSnapshot);
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'SnapshotEvent: Failed to build fallback snapshot record for '
          '${json['id'] ?? json['recordId'] ?? 'unknown event'}',
          error,
          stackTrace,
        );
        final fallbackModelType = _resolveModelType(recordModelType);
        return _FallbackInventoryRecord.fromEventJson(
          json,
          fallbackModelType: fallbackModelType,
        );
      }
    }

    LoggingService.instance.error(
      'SnapshotEvent: Unable to determine fallback snapshot for event. '
      'Missing snapshotData and recordModelType.\n$json',
    );
    return _FallbackInventoryRecord.fromEventJson(
      json,
      fallbackModelType: ModelType.unknown,
    );
  }

  static ModelType _resolveModelType(Object? value) {
    if (value is String && value.isNotEmpty) {
      try {
        return ModelType.values.byName(value);
      } catch (_) {
        LoggingService.instance.warning(
          'SnapshotEvent: Unknown recordModelType "$value".',
        );
      }
    }
    return ModelType.unknown;
  }
}

mixin ImageEvent {
  String? get imageUrl;

  static String? imageUrlFromJson(Map<String, dynamic> json) {
    return json['imageUrl'];
  }
}

mixin CommentEvent {
  String? get comment;

  static String? commentFromJson(Map<String, dynamic> json) {
    return json['comment'];
  }
}

class _FallbackInventoryRecord extends InventoryRecord {
  const _FallbackInventoryRecord({
    required this.fallbackModelType,
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
  });

  factory _FallbackInventoryRecord.fromEventJson(
    Map<String, dynamic> json, {
    required ModelType fallbackModelType,
  }) {
    return _FallbackInventoryRecord(
      fallbackModelType: fallbackModelType,
      id: json['recordId'] as String? ?? Missing.string,
      createdAt: json['createdAt'] as String? ?? Missing.dateTimeString,
      createdById: json['createdById'] as String? ?? Missing.string,
      updatedAt:
          json['updatedAt'] as String? ??
          json['createdAt'] as String? ??
          Missing.dateTimeString,
      updatedById:
          json['updatedById'] as String? ??
          json['createdById'] as String? ??
          Missing.string,
      organizationId: json['organizationId'] as String? ?? Missing.string,
      urlPath: json['urlPath'] as String? ?? Missing.string,
      internalPath: json['internalPath'] as String? ?? Missing.string,
      slug: json['slug'] as String? ?? Missing.string,
    );
  }

  final ModelType fallbackModelType;

  @override
  ModelType get modelType => fallbackModelType;

  @override
  InventoryRecord copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedById,
    String? updatedAt,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    Map<String, dynamic>? metadata,
  }) {
    return _FallbackInventoryRecord(
      fallbackModelType: fallbackModelType,
      id: id ?? this.id,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedById: updatedById ?? this.updatedById,
      updatedAt: updatedAt ?? this.updatedAt,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'isFallbackSnapshot': true, ...super.toJson()};
  }
}
