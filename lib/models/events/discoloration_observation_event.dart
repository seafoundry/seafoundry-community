// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Types of discoloration that can be observed
class DiscolorationType {
  final String id;
  final String label;

  const DiscolorationType._({required this.id, required this.label});

  static DiscolorationType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => DiscolorationType._(id: id, label: 'Unknown'),
    );
  }

  static const DiscolorationType bleaching = DiscolorationType._(
    id: 'bleaching',
    label: 'Bleaching (White)',
  );

  static const DiscolorationType paleing = DiscolorationType._(
    id: 'paleing',
    label: 'Paleing (Light)',
  );

  static const DiscolorationType browning = DiscolorationType._(
    id: 'browning',
    label: 'Browning',
  );

  static const DiscolorationType yellowing = DiscolorationType._(
    id: 'yellowing',
    label: 'Yellowing',
  );

  static const DiscolorationType darkening = DiscolorationType._(
    id: 'darkening',
    label: 'Darkening',
  );

  static const DiscolorationType pinkening = DiscolorationType._(
    id: 'pinkening',
    label: 'Pinkening',
  );

  static const DiscolorationType purpling = DiscolorationType._(
    id: 'purpling',
    label: 'Purpling',
  );

  static const DiscolorationType other = DiscolorationType._(
    id: 'other',
    label: 'Other',
  );

  static const List<DiscolorationType> values = [
    bleaching,
    paleing,
    browning,
    yellowing,
    darkening,
    pinkening,
    purpling,
    other,
  ];
}

/// Extent of discoloration
enum DiscolorationExtent {
  minimal, // < 10%
  partial, // 10-50%
  significant, // 50-90%
  complete; // > 90%

  String get label {
    switch (this) {
      case DiscolorationExtent.minimal:
        return 'Minimal (< 10%)';
      case DiscolorationExtent.partial:
        return 'Partial (10-50%)';
      case DiscolorationExtent.significant:
        return 'Significant (50-90%)';
      case DiscolorationExtent.complete:
        return 'Complete (> 90%)';
    }
  }
}

/// An observation event specifically for discoloration
class DiscolorationObservationEvent extends ObservationEvent {
  /// Type of discoloration observed
  final String discolorationTypeId;

  /// Extent of discoloration
  final String extent;

  /// Percentage of coral affected (0-100)
  final double? affectedPercentage;

  /// Whether this is improving, stable, or worsening
  final String? trend; // 'improving', 'stable', 'worsening'

  DiscolorationObservationEvent({
    required super.id,
    required this.discolorationTypeId,
    required this.extent,
    this.affectedPercentage,
    this.trend,
    super.imageUrl,
    super.comment,
    super.createTask,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.recordModelType,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
  }) : super(eventTypeId: 'event_discoloration_observation');

  DiscolorationObservationEvent.fromJson(super.json)
    : discolorationTypeId = json['discolorationTypeId'] ?? 'other',
      extent = json['extent'] ?? 'partial',
      affectedPercentage = safeDouble(json['affectedPercentage']),
      trend = json['trend'],
      super.fromJson();

  DiscolorationObservationEvent.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.recordId,
    super.recordModelType,
    super.urlPath,
    super.internalPath,
    super.slug,

    super.metadata,

    super.base,
    super.eventTypeId,
    super.imageUrl,
    super.comment,
    String? discolorationTypeId,
    String? extent,
    double? affectedPercentage,
    String? trend,
  }) : discolorationTypeId =
           discolorationTypeId ?? json?['discolorationTypeId'] ?? 'other',
       extent = extent ?? json?['extent'] ?? 'partial',
       affectedPercentage =
           affectedPercentage ??
           safeDouble(json?['affectedPercentage']),
       trend = trend ?? json?['trend'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'discolorationTypeId': discolorationTypeId,
      'extent': extent,
      if (affectedPercentage != null) 'affectedPercentage': affectedPercentage,
      if (trend != null) 'trend': trend,
    };
  }

  @override
  bool validate() {
    return super.validate() && discolorationTypeId.isNotEmpty;
  }

  @override
  DiscolorationObservationEvent copyWith({
    String? id,
    String? discolorationTypeId,
    String? extent,
    double? affectedPercentage,
    String? trend,
    String? imageUrl,
    String? comment,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    bool? createTask,
    String? eventTypeId,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    ModelType? recordModelType,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return DiscolorationObservationEvent(
      id: id ?? this.id,
      discolorationTypeId: discolorationTypeId ?? this.discolorationTypeId,
      extent: extent ?? this.extent,
      affectedPercentage: affectedPercentage ?? this.affectedPercentage,
      trend: trend ?? this.trend,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
      createTask: createTask ?? this.createTask,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    discolorationTypeId,
    extent,
    affectedPercentage,
    trend,
  ];

  /// Get the discoloration type
  DiscolorationType get discolorationType =>
      DiscolorationType.fromId(discolorationTypeId) ?? DiscolorationType.other;

  /// Get the extent enum
  DiscolorationExtent get extentLevel {
    try {
      return DiscolorationExtent.values.firstWhere(
        (e) => e.name == extent,
        orElse: () => DiscolorationExtent.partial,
      );
    } catch (_) {
      return DiscolorationExtent.partial;
    }
  }
}
