// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/mission_allocation.dart';
import 'package:seafoundry_app/models/operations/vessel_requirements.dart';
import 'package:seafoundry_app/models/records/records.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

export 'package:seafoundry_app/models/operations/vessel_requirements.dart';
export 'package:seafoundry_app/models/mission_mutations.dart';

/// Status of a mission in its lifecycle
enum MissionStatus {
  draft('draft', 'Draft'),
  scheduled('scheduled', 'Scheduled'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  final String id;
  final String displayName;

  const MissionStatus(this.id, this.displayName);

  static MissionStatus fromId(String? id) {
    if (id == null) return draft;
    return values.firstWhere((status) => status.id == id, orElse: () => draft);
  }

  bool get isDraft => this == MissionStatus.draft;
  bool get isScheduled => this == MissionStatus.scheduled;
  bool get isInProgress => this == MissionStatus.inProgress;
  bool get isCompleted => this == MissionStatus.completed;
  bool get isCancelled => this == MissionStatus.cancelled;
  bool get isActive => isScheduled || isInProgress;

  Color get color {
    switch (this) {
      case MissionStatus.draft:
        return Colors.grey;
      case MissionStatus.scheduled:
        return Colors.blue;
      case MissionStatus.inProgress:
        return Colors.orange;
      case MissionStatus.completed:
        return Colors.green;
      case MissionStatus.cancelled:
        return Colors.red;
    }
  }
}

/// A planned field operation combining sites, tasks, crew, and vessel
class Mission extends InventoryRecord {
  static const Object _unset = Object();

  final String name;
  final String? description;
  final DateTime scheduledDate;
  final DateTime? endDate;
  final List<String> siteIds;
  final List<String> taskIds;
  final String? vesselId;
  final VesselRequirements? vesselRequirements;
  final List<String> crewUserIds;
  final MissionStatus status;
  final double? estimatedDurationHours;
  final String? notes;
  final Map<String, dynamic>? weatherSnapshot;
  final List<String> deliverableIds;
  final List<MissionAllocation> plannedAllocations;

  const Mission({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    required this.name,
    required this.scheduledDate,
    this.description,
    this.endDate,
    List<String>? siteIds,
    List<String>? taskIds,
    this.vesselId,
    this.vesselRequirements,
    List<String>? crewUserIds,
    MissionStatus? status,
    this.estimatedDurationHours,
    this.notes,
    this.weatherSnapshot,
    List<String>? deliverableIds,
    List<MissionAllocation>? plannedAllocations,
    super.metadata,
  }) : siteIds = siteIds ?? const [],
       taskIds = taskIds ?? const [],
       crewUserIds = crewUserIds ?? const [],
       status = status ?? MissionStatus.draft,
       deliverableIds = deliverableIds ?? const [],
       plannedAllocations = plannedAllocations ?? const [];

  Mission.fromJson(super.json)
    : name = json['name'] ?? 'Untitled Mission',
      description = json['description'],
      scheduledDate = DateTimeConverter.parseWithFallback(
        json['scheduledDate'],
        fallback: DateTime.now(),
        fieldName: 'scheduledDate',
        modelType: 'Mission',
        recordId: json['id'],
      ),
      endDate = json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : null,
      siteIds = json['siteIds'] != null
          ? List<String>.from(json['siteIds'])
          : const [],
      taskIds = json['taskIds'] != null
          ? List<String>.from(json['taskIds'])
          : const [],
      vesselId = json['vesselId'],
      vesselRequirements = VesselRequirements.fromJson(
        json['vesselRequirements'],
      ),
      crewUserIds = json['crewUserIds'] != null
          ? List<String>.from(json['crewUserIds'])
          : const [],
      status = MissionStatus.fromId(json['statusId']),
      estimatedDurationHours = safeDouble(json['estimatedDurationHours']),
      notes = json['notes'],
      weatherSnapshot = json['weatherSnapshot'] != null
          ? Map<String, dynamic>.from(json['weatherSnapshot'])
          : null,
      deliverableIds = json['deliverableIds'] != null
          ? List<String>.from(json['deliverableIds'])
          : const [],
      plannedAllocations = _parseAllocations(json['plannedAllocations']),
      super.fromJson();

  Mission.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.urlPath,
    super.internalPath,
    super.slug,
    super.metadata,
    String? name,
    String? description,
    DateTime? scheduledDate,
    DateTime? endDate,
    List<String>? siteIds,
    List<String>? taskIds,
    String? vesselId,
    VesselRequirements? vesselRequirements,
    List<String>? crewUserIds,
    MissionStatus? status,
    double? estimatedDurationHours,
    String? notes,
    Map<String, dynamic>? weatherSnapshot,
    List<String>? deliverableIds,
    List<MissionAllocation>? plannedAllocations,
  }) : name = name ?? json?['name'] ?? 'Untitled Mission',
       description = description ?? json?['description'],
       scheduledDate =
           scheduledDate ??
           DateTimeConverter.parseWithFallback(
             json?['scheduledDate'],
             fallback: DateTime.now(),
             fieldName: 'scheduledDate',
             modelType: 'Mission',
             recordId: json?['id'],
           ),
       endDate =
           endDate ??
           (json?['endDate'] != null ? DateTime.parse(json!['endDate']) : null),
       siteIds =
           siteIds ??
           (json?['siteIds'] != null
               ? List<String>.from(json!['siteIds'])
               : const []),
       taskIds =
           taskIds ??
           (json?['taskIds'] != null
               ? List<String>.from(json!['taskIds'])
               : const []),
       vesselId = vesselId ?? json?['vesselId'],
       vesselRequirements =
           vesselRequirements ??
           VesselRequirements.fromJson(json?['vesselRequirements']),
       crewUserIds =
           crewUserIds ??
           (json?['crewUserIds'] != null
               ? List<String>.from(json!['crewUserIds'])
               : const []),
       status = status ?? MissionStatus.fromId(json?['statusId']),
       estimatedDurationHours =
           estimatedDurationHours ??
           safeDouble(json?['estimatedDurationHours']),
       notes = notes ?? json?['notes'],
       weatherSnapshot =
           weatherSnapshot ??
           (json?['weatherSnapshot'] != null
               ? Map<String, dynamic>.from(json!['weatherSnapshot'])
               : null),
       deliverableIds =
           deliverableIds ??
           (json?['deliverableIds'] != null
               ? List<String>.from(json!['deliverableIds'])
               : const []),
       plannedAllocations =
           plannedAllocations ?? _parseAllocations(json?['plannedAllocations']),
       super.partial();

  @override
  ModelType get modelType => ModelType.mission;

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'scheduledDate': scheduledDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      'siteIds': siteIds,
      'taskIds': taskIds,
      if (vesselId != null) 'vesselId': vesselId,
      if (vesselRequirements != null)
        'vesselRequirements': vesselRequirements!.toJson(),
      'crewUserIds': crewUserIds,
      'statusId': status.id,
      if (estimatedDurationHours != null)
        'estimatedDurationHours': estimatedDurationHours,
      if (notes != null) 'notes': notes,
      if (weatherSnapshot != null) 'weatherSnapshot': weatherSnapshot,
      if (deliverableIds.isNotEmpty) 'deliverableIds': deliverableIds,
      if (plannedAllocations.isNotEmpty)
        'plannedAllocations': plannedAllocations.map((a) => a.toJson()).toList(),
      ...super.toJson(),
    };
  }

  @override
  Mission copyWith({
    Object? id = _unset,
    Object? createdById = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? organizationId = _unset,
    Object? urlPath = _unset,
    Object? internalPath = _unset,
    Object? slug = _unset,
    Object? name = _unset,
    Object? description = _unset,
    Object? scheduledDate = _unset,
    Object? endDate = _unset,
    Object? siteIds = _unset,
    Object? taskIds = _unset,
    Object? vesselId = _unset,
    Object? vesselRequirements = _unset,
    Object? crewUserIds = _unset,
    Object? status = _unset,
    Object? estimatedDurationHours = _unset,
    Object? notes = _unset,
    Object? weatherSnapshot = _unset,
    Object? deliverableIds = _unset,
    Object? plannedAllocations = _unset,
    Map<String, dynamic>? metadata,
  }) {
    return Mission(
      id: identical(id, _unset) ? this.id : id as String,
      createdById: identical(createdById, _unset)
          ? this.createdById
          : createdById as String,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as String,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as String,
      updatedById: identical(updatedById, _unset)
          ? this.updatedById
          : updatedById as String,
      organizationId: identical(organizationId, _unset)
          ? this.organizationId
          : organizationId as String,
      urlPath: identical(urlPath, _unset) ? this.urlPath : urlPath as String,
      internalPath: identical(internalPath, _unset)
          ? this.internalPath
          : internalPath as String,
      slug: identical(slug, _unset) ? this.slug : slug as String,
      name: identical(name, _unset) ? this.name : name as String,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      scheduledDate: identical(scheduledDate, _unset)
          ? this.scheduledDate
          : scheduledDate as DateTime,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      siteIds: identical(siteIds, _unset)
          ? this.siteIds
          : siteIds as List<String>,
      taskIds: identical(taskIds, _unset)
          ? this.taskIds
          : taskIds as List<String>,
      vesselId: identical(vesselId, _unset)
          ? this.vesselId
          : vesselId as String?,
      vesselRequirements: identical(vesselRequirements, _unset)
          ? this.vesselRequirements
          : vesselRequirements as VesselRequirements?,
      crewUserIds: identical(crewUserIds, _unset)
          ? this.crewUserIds
          : crewUserIds as List<String>,
      status: identical(status, _unset) ? this.status : status as MissionStatus,
      estimatedDurationHours: identical(estimatedDurationHours, _unset)
          ? this.estimatedDurationHours
          : estimatedDurationHours as double?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      weatherSnapshot: identical(weatherSnapshot, _unset)
          ? this.weatherSnapshot
          : weatherSnapshot as Map<String, dynamic>?,
      deliverableIds: identical(deliverableIds, _unset)
          ? this.deliverableIds
          : deliverableIds as List<String>,
      plannedAllocations: identical(plannedAllocations, _unset)
          ? this.plannedAllocations
          : plannedAllocations as List<MissionAllocation>,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    // Validate name is not empty and endDate is not before scheduledDate
    final dateValid = endDate == null || !endDate!.isBefore(scheduledDate);
    return super.validate() && name.isNotEmpty && dateValid;
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        name,
        description,
        scheduledDate,
        endDate,
        siteIds,
        taskIds,
        vesselId,
        vesselRequirements,
        crewUserIds,
        status,
        estimatedDurationHours,
        notes,
        weatherSnapshot,
        deliverableIds,
        plannedAllocations,
      ];

  // Computed properties
  bool get isMultiDay {
    if (endDate == null) return false;
    return endDate!.year != scheduledDate.year ||
        endDate!.month != scheduledDate.month ||
        endDate!.day != scheduledDate.day;
  }

  bool get isPast => scheduledDate.isBefore(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
  }

  bool get hasSites => siteIds.isNotEmpty;
  bool get hasTasks => taskIds.isNotEmpty;
  bool get hasCrew => crewUserIds.isNotEmpty;
  bool get hasVessel => vesselId != null;
  bool get hasVesselRequirements => vesselRequirements != null;
  bool get hasDeliverables => deliverableIds.isNotEmpty;
  bool get hasAllocations => plannedAllocations.isNotEmpty;

  /// Get total quantity across all allocations
  int get totalAllocatedQuantity =>
      plannedAllocations.fold(0, (sum, a) => sum + a.quantity);

  /// Helper method to parse allocations from JSON
  /// Uses tryFromJson to gracefully handle invalid allocations
  static List<MissionAllocation> _parseAllocations(dynamic json) {
    if (json == null) return const [];
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(MissionAllocation.tryFromJson)
        .whereType<MissionAllocation>()
        .toList();
  }
}
