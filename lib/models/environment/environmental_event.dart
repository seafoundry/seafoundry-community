// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

enum EnvironmentalEventType {
  bleaching,
  disease,
  runoff,
  storm,
  algaeBloom,
  other,
}

enum EnvironmentalEventSeverity {
  low,
  medium,
  high,
  critical,
}

class EnvironmentalEvent extends Record {
  const EnvironmentalEvent({
    required super.id,
    required super.organizationId,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    super.metadata,
    required this.eventType,
    required this.severity,
    required this.startDate,
    this.endDate,
    this.affectedSiteIds = const [],
    this.description,
    this.source = 'user_report',
  });

  EnvironmentalEvent.fromJson(super.json)
      : eventType = _parseEventType(json['eventType']),
        severity = _parseSeverity(json['severity']),
        startDate = json['startDate'] as String,
        endDate = json['endDate'] as String?,
        affectedSiteIds = (json['affectedSiteIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        description = json['description'] as String?,
        source = json['source'] as String? ?? 'user_report',
        super.fromJson();

  final EnvironmentalEventType eventType;
  final EnvironmentalEventSeverity severity;
  final String startDate; // ISO8601
  final String? endDate; // ISO8601
  final List<String> affectedSiteIds;
  final String? description;
  final String source; // 'user_report', 'satellite', 'news'

  @override
  ModelType get modelType => ModelType.environmentalEvent;

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'eventType': eventType.name,
        'severity': severity.name,
        'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'affectedSiteIds': affectedSiteIds,
        if (description != null) 'description': description,
        'source': source,
      };

  @override
  EnvironmentalEvent copyWith({
    String? id,
    String? organizationId,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    Map<String, dynamic>? metadata,
    EnvironmentalEventType? eventType,
    EnvironmentalEventSeverity? severity,
    String? startDate,
    String? endDate,
    List<String>? affectedSiteIds,
    String? description,
    String? source,
  }) {
    return EnvironmentalEvent(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      metadata: metadata ?? this.metadata,
      eventType: eventType ?? this.eventType,
      severity: severity ?? this.severity,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      affectedSiteIds: affectedSiteIds ?? this.affectedSiteIds,
      description: description ?? this.description,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        eventType,
        severity,
        startDate,
        endDate,
        affectedSiteIds,
        description,
        source,
      ];

  static EnvironmentalEventType _parseEventType(dynamic value) {
    return EnvironmentalEventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EnvironmentalEventType.other,
    );
  }

  static EnvironmentalEventSeverity _parseSeverity(dynamic value) {
    return EnvironmentalEventSeverity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EnvironmentalEventSeverity.low,
    );
  }
}
