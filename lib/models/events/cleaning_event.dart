// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/events/structure_maintenance_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Types of cleaning activities
class CleaningType {
  final String id;
  final String label;

  /// Which site environments this cleaning type is applicable to.
  /// If empty, the type is applicable to all environments.
  final Set<SiteEnvironment> applicableEnvironments;

  const CleaningType._({
    required this.id,
    required this.label,
    this.applicableEnvironments = const {},
  });

  /// Whether this cleaning type is applicable to all site environments
  bool get isUniversal => applicableEnvironments.isEmpty;

  /// Whether this cleaning type is applicable to the given environment
  bool isApplicableTo(SiteEnvironment environment) {
    return isUniversal || applicableEnvironments.contains(environment);
  }

  static CleaningType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => CleaningType._(id: id, label: 'Unknown'),
    );
  }

  /// Get cleaning types applicable to a specific site environment
  static List<CleaningType> valuesFor(SiteEnvironment environment) {
    return values.where((type) => type.isApplicableTo(environment)).toList();
  }

  // === Universal cleaning types ===

  static const CleaningType algaeScraping = CleaningType._(
    id: 'algae_scraping',
    label: 'Algae Scraping',
  );

  static const CleaningType equipmentCleaning = CleaningType._(
    id: 'equipment_cleaning',
    label: 'Equipment Cleaning',
  );

  static const CleaningType other = CleaningType._(id: 'other', label: 'Other');

  // === Ex-situ only cleaning types (land-based facilities) ===

  static const CleaningType glassWiping = CleaningType._(
    id: 'glass_wiping',
    label: 'Glass Wiping',
    applicableEnvironments: {SiteEnvironment.exSitu},
  );

  static const CleaningType substrateVacuuming = CleaningType._(
    id: 'substrate_vacuuming',
    label: 'Substrate Vacuuming',
    applicableEnvironments: {SiteEnvironment.exSitu},
  );

  static const CleaningType filterCleaning = CleaningType._(
    id: 'filter_cleaning',
    label: 'Filter Cleaning',
    applicableEnvironments: {SiteEnvironment.exSitu},
  );

  static const CleaningType pumpCleaning = CleaningType._(
    id: 'pump_cleaning',
    label: 'Pump Cleaning',
    applicableEnvironments: {SiteEnvironment.exSitu},
  );

  // === In-situ only cleaning types (ocean-based) ===

  static const CleaningType structureScrubbing = CleaningType._(
    id: 'structure_scrubbing',
    label: 'Structure Scrubbing',
    applicableEnvironments: {SiteEnvironment.inSitu},
  );

  static const CleaningType lineDefouling = CleaningType._(
    id: 'line_defouling',
    label: 'Line Defouling',
    applicableEnvironments: {SiteEnvironment.inSitu},
  );

  static const List<CleaningType> values = [
    // Universal
    algaeScraping,
    equipmentCleaning,
    other,
    // Ex-situ only
    glassWiping,
    substrateVacuuming,
    filterCleaning,
    pumpCleaning,
    // In-situ only
    structureScrubbing,
    lineDefouling,
  ];
}

/// An event representing a cleaning activity
class CleaningEvent extends HusbandryEvent {
  /// Type of cleaning performed
  final String cleaningTypeId;

  /// Duration of cleaning in minutes
  final int? durationMinutes;

  /// Area or equipment cleaned
  final String? area;

  CleaningEvent({
    required super.id,
    required this.cleaningTypeId,
    this.durationMinutes,
    this.area,
    super.imageUrl,
    super.comment,
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
  }) : super(eventTypeId: HusbandryEventType.cleaningId);

  CleaningEvent.fromJson(super.json)
    : cleaningTypeId = json['cleaningTypeId'] ?? 'other',
      durationMinutes = json['durationMinutes'],
      area = json['area'],
      super.fromJson();

  CleaningEvent.partial({
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
    super.comment,
    super.imageUrl,
    String? cleaningTypeId,
    int? durationMinutes,
    String? area,
  }) : cleaningTypeId = cleaningTypeId ?? json?['cleaningTypeId'] ?? 'other',
       durationMinutes = durationMinutes ?? json?['durationMinutes'],
       area = area ?? json?['area'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'cleaningTypeId': cleaningTypeId,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (area != null) 'area': area,
    };
  }

  @override
  bool validate() {
    return super.validate() && cleaningTypeId.isNotEmpty;
  }

  @override
  CleaningEvent copyWith({
    String? id,
    String? cleaningTypeId,
    int? durationMinutes,
    String? area,
    String? imageUrl,
    String? comment,
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
    return CleaningEvent(
      id: id ?? this.id,
      cleaningTypeId: cleaningTypeId ?? this.cleaningTypeId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      area: area ?? this.area,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
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
    cleaningTypeId,
    durationMinutes,
    area,
  ];

  /// Get the cleaning type
  CleaningType get cleaningType =>
      CleaningType.fromId(cleaningTypeId) ?? CleaningType.other;
}
