// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/monitoring/image_attachment.dart';
import 'package:seafoundry_app/models/monitoring/monitoring_entry.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/monitoring_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// MonitoringEventRecord represents a monitoring observation for organisms.
/// Used to track health status, measurements, and other monitoring data.
///
/// Contains point-in-time snapshots of names for historical audit purposes.
/// These preserve the record of what site/event was named at observation time.
class MonitoringEventRecord extends Event with ImageEvent, CommentEvent {
  @override
  final String? imageUrl;
  @override
  final String? comment;
  final String? oldHealthStatus;
  final String? newHealthStatus;
  final String? healthIssueTypeId;
  final double? percentCover;
  final double? percentBleaching;
  final double? percentDisease;
  final Map<String, dynamic>? measurements;
  final String? siteId;
  /// Point-in-time snapshot of site name when observation was recorded.
  /// Intentionally denormalized for historical audit purposes.
  final String? siteNameSnapshot;
  final String? outplantEventId;
  /// Point-in-time snapshot of outplant event name when observation was recorded.
  /// Intentionally denormalized for historical audit purposes.
  final String? outplantEventNameSnapshot;
  final String? monitoringTypeId;
  final DateTime? monitoringDate;
  final List<String>? coralIds;
  List<String>? get organismIds => coralIds;
  @Deprecated('Use siteNameSnapshot')
  String? get siteName => siteNameSnapshot;
  @Deprecated('Use outplantEventNameSnapshot')
  String? get outplantEventName => outplantEventNameSnapshot;
  final List<MonitoringEntry> entries;
  final bool createTask;
  final String? healthStatus;
  final String? notes;
  final int? totalCount;
  final OutplantGeometry? outplantGeometry;
  final List<ImageAttachment> imageAttachments;

  MonitoringEventRecord({
    required super.id,
    this.comment,
    this.imageUrl,
    this.oldHealthStatus,
    this.newHealthStatus,
    this.healthIssueTypeId,
    this.percentCover,
    this.percentBleaching,
    this.percentDisease,
    this.measurements,
    this.siteId,
    String? siteNameSnapshot,
    String? siteName,
    this.outplantEventId,
    String? outplantEventNameSnapshot,
    String? outplantEventName,
    this.monitoringTypeId,
    this.monitoringDate,
    List<String>? coralIds,
    List<String>? organismIds,
    this.entries = const [],
    this.createTask = false,
    this.healthStatus,
    this.notes,
    this.totalCount,
    this.outplantGeometry,
    this.imageAttachments = const [],
    required super.createdById,
    required super.createdAt,
    required super.recordId,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    super.base,
    required super.recordModelType,
  }) : siteNameSnapshot = siteNameSnapshot ?? siteName,
       outplantEventNameSnapshot =
           outplantEventNameSnapshot ?? outplantEventName,
       coralIds = organismIds ?? coralIds,
       super(eventTypeId: EventType.observation.id);

  MonitoringEventRecord.fromJson(super.json)
    : imageUrl = json['imageUrl'],
      comment = json['comment'],
      oldHealthStatus = json['oldHealthStatus'],
      newHealthStatus = json['newHealthStatus'],
      healthIssueTypeId = json['healthIssueTypeId'],
      percentCover = safeDouble(json['percentCover']),
      percentBleaching = safeDouble(json['percentBleaching']),
      percentDisease = safeDouble(json['percentDisease']),
      measurements = safeMapCast(json['measurements']),
      siteId = json['siteId'],
      // Support both old 'siteName' and new 'siteNameSnapshot' keys
      siteNameSnapshot = json['siteNameSnapshot'] ?? json['siteName'],
      outplantEventId = json['outplantEventId'],
      // Support both old 'outplantEventName' and new 'outplantEventNameSnapshot' keys
      outplantEventNameSnapshot = json['outplantEventNameSnapshot'] ?? json['outplantEventName'],
      monitoringTypeId = json['monitoringTypeId'],
      monitoringDate = _parseMonitoringDate(json['monitoringDate']),
      coralIds = _parseOrganismIds(json),
      entries = _parseEntries(json['entries']),
      createTask = json['createTask'] ?? false,
      healthStatus = json['healthStatus'],
      notes = json['notes'],
      totalCount = safeInt(json['totalCount']),
      outplantGeometry = OutplantGeometry.maybeFromJson(
        json['outplantGeometry'] ?? json['geometry'],
      ),
      imageAttachments = _parseImageAttachments(json['imageAttachments']),
      super.fromJson();

  MonitoringEventRecord.partial({
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
    String? imageUrl,
    String? comment,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
    String? siteId,
    String? siteNameSnapshot,
    String? siteName,
    String? outplantEventId,
    String? outplantEventNameSnapshot,
    String? outplantEventName,
    String? monitoringTypeId,
    DateTime? monitoringDate,
    List<String>? coralIds,
    List<String>? organismIds,
    List<MonitoringEntry>? entries,
    bool? createTask,
    String? healthStatus,
    String? notes,
    int? totalCount,
    OutplantGeometry? outplantGeometry,
    List<ImageAttachment>? imageAttachments,
  }) : imageUrl = imageUrl ?? json?['imageUrl'],
       comment = comment ?? json?['comment'],
       oldHealthStatus = oldHealthStatus ?? json?['oldHealthStatus'],
       newHealthStatus = newHealthStatus ?? json?['newHealthStatus'],
       healthIssueTypeId = healthIssueTypeId ?? json?['healthIssueTypeId'],
       percentCover =
           percentCover ?? safeDouble(json?['percentCover']),
       percentBleaching =
           percentBleaching ?? safeDouble(json?['percentBleaching']),
       percentDisease =
           percentDisease ?? safeDouble(json?['percentDisease']),
       measurements =
           measurements ?? safeMapCast(json?['measurements']),
       siteId = siteId ?? json?['siteId'],
       siteNameSnapshot =
           siteNameSnapshot ??
           siteName ??
           json?['siteNameSnapshot'] ??
           json?['siteName'],
       outplantEventId = outplantEventId ?? json?['outplantEventId'],
       outplantEventNameSnapshot =
           outplantEventNameSnapshot ??
           outplantEventName ??
           json?['outplantEventNameSnapshot'] ??
           json?['outplantEventName'],
       monitoringTypeId = monitoringTypeId ?? json?['monitoringTypeId'],
       monitoringDate =
           monitoringDate ?? _parseMonitoringDate(json?['monitoringDate']),
       coralIds = organismIds ?? coralIds ?? _parseOrganismIds(json),
       entries = entries ?? _parseEntries(json?['entries']),
       createTask = createTask ?? json?['createTask'] ?? false,
       healthStatus = healthStatus ?? json?['healthStatus'],
       notes = notes ?? json?['notes'],
       totalCount = totalCount ?? safeInt(json?['totalCount']),
       outplantGeometry =
           outplantGeometry ??
           OutplantGeometry.maybeFromJson(
             json?['outplantGeometry'] ?? json?['geometry'],
           ),
       imageAttachments =
           imageAttachments ?? _parseImageAttachments(json?['imageAttachments']),
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'comment': comment,
      'imageUrl': imageUrl,
      'oldHealthStatus': oldHealthStatus,
      'newHealthStatus': newHealthStatus,
      'healthIssueTypeId': healthIssueTypeId,
      'percentCover': percentCover,
      'percentBleaching': percentBleaching,
      'percentDisease': percentDisease,
      'measurements': measurements,
      'siteId': siteId,
      'siteNameSnapshot': siteNameSnapshot,
      'outplantEventId': outplantEventId,
      'outplantEventNameSnapshot': outplantEventNameSnapshot,
      'monitoringTypeId': monitoringTypeId,
      'monitoringDate': monitoringDate?.toIso8601String(),
      if (coralIds != null) 'organismIds': coralIds,
      'entries': entries.map((e) => e.toJson()).toList(),
      'createTask': createTask,
      'healthStatus': healthStatus,
      'notes': notes,
      'totalCount': totalCount,
      if (outplantGeometry != null)
        'outplantGeometry': outplantGeometry!.toJson(),
      if (imageAttachments.isNotEmpty)
        'imageAttachments': imageAttachments.map((a) => a.toJson()).toList(),
    };
  }

  /// Returns true if this observation includes a health status change
  bool get isHealthStatusChange =>
      oldHealthStatus != null &&
      newHealthStatus != null &&
      oldHealthStatus != newHealthStatus;

  /// Get the old health status as enum
  HealthStatus? get oldHealthStatusEnum =>
      HealthStatus.maybeFromId(oldHealthStatus);

  /// Get the new health status as enum
  HealthStatus? get newHealthStatusEnum =>
      HealthStatus.maybeFromId(newHealthStatus);

  /// Get the monitoring type as enum
  MonitoringType? get monitoringType => MonitoringType.maybeFromId(monitoringTypeId);

  /// Get the effective monitoring type, inferring from timing if not explicitly set
  MonitoringType get effectiveMonitoringType {
    if (monitoringTypeId != null) {
      return MonitoringType.fromId(monitoringTypeId);
    }
    // Infer from timing if outplant event is linked
    if (outplantEventId != null && monitoringDate != null) {
      // Default to post-outplant since most monitoring occurs after outplanting
      // Pre-outplant should be explicitly set
      return MonitoringType.postOutplant;
    }
    return MonitoringType.nursery;
  }

  @override
  MonitoringEventRecord copyWith({
    String? id,
    String? comment,
    String? imageUrl,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
    String? siteId,
    String? siteNameSnapshot,
    String? siteName,
    String? outplantEventId,
    String? outplantEventNameSnapshot,
    String? outplantEventName,
    String? monitoringTypeId,
    DateTime? monitoringDate,
    List<String>? coralIds,
    List<String>? organismIds,
    List<MonitoringEntry>? entries,
    bool? createTask,
    String? healthStatus,
    String? notes,
    int? totalCount,
    OutplantGeometry? outplantGeometry,
    List<ImageAttachment>? imageAttachments,
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
    bool clearGeometry = false,
  }) {
    return MonitoringEventRecord(
      id: id ?? this.id,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
      oldHealthStatus: oldHealthStatus ?? this.oldHealthStatus,
      newHealthStatus: newHealthStatus ?? this.newHealthStatus,
      healthIssueTypeId: healthIssueTypeId ?? this.healthIssueTypeId,
      percentCover: percentCover ?? this.percentCover,
      percentBleaching: percentBleaching ?? this.percentBleaching,
      percentDisease: percentDisease ?? this.percentDisease,
      measurements: measurements ?? this.measurements,
      siteId: siteId ?? this.siteId,
      siteNameSnapshot:
          siteNameSnapshot ?? siteName ?? this.siteNameSnapshot,
      outplantEventId: outplantEventId ?? this.outplantEventId,
      outplantEventNameSnapshot: outplantEventNameSnapshot ??
          outplantEventName ??
          this.outplantEventNameSnapshot,
      monitoringTypeId: monitoringTypeId ?? this.monitoringTypeId,
      monitoringDate: monitoringDate ?? this.monitoringDate,
      coralIds: organismIds ?? coralIds ?? this.coralIds,
      entries: entries ?? this.entries,
      createTask: createTask ?? this.createTask,
      healthStatus: healthStatus ?? this.healthStatus,
      notes: notes ?? this.notes,
      totalCount: totalCount ?? this.totalCount,
      outplantGeometry: outplantGeometry ?? this.outplantGeometry,
      imageAttachments: imageAttachments ?? this.imageAttachments,
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
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: clearGeometry ? null : geometry,
      ).copyWith(clearGeometry: clearGeometry ? true : null),
    );
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        comment,
        imageUrl,
        oldHealthStatus,
        newHealthStatus,
        healthIssueTypeId,
        percentCover,
        percentBleaching,
        percentDisease,
        measurements,
        siteId,
        siteNameSnapshot,
        outplantEventId,
        outplantEventNameSnapshot,
        monitoringTypeId,
        monitoringDate,
        coralIds,
        entries,
        createTask,
        healthStatus,
        notes,
        totalCount,
        outplantGeometry,
        imageAttachments,
      ];
}

DateTime? _parseMonitoringDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<String>? _parseOrganismIds(Map<String, dynamic>? json) {
  if (json == null) return null;
  final raw = json['organismIds'] ?? json['coralIds'];
  if (raw is Iterable) {
    return List<String>.from(raw);
  }
  return null;
}

List<MonitoringEntry> _parseEntries(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) {
    final map = safeMapCast(e);
    return map != null ? MonitoringEntry.fromJson(map) : null;
  }).whereType<MonitoringEntry>().toList();
}

List<ImageAttachment> _parseImageAttachments(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) {
    final map = safeMapCast(e);
    return map != null ? ImageAttachment.fromJson(map) : null;
  }).whereType<ImageAttachment>().toList();
}
