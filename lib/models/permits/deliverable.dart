// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Type of deliverable required by a permit
enum DeliverableType {
  report('report', 'Report'),
  survey('survey', 'Survey'),
  documentation('documentation', 'Documentation'),
  permitRenewal('permit_renewal', 'Permit Renewal'),
  compliance('compliance', 'Compliance');

  final String id;
  final String displayName;

  const DeliverableType(this.id, this.displayName);

  static DeliverableType fromId(String? id) {
    if (id == null) return report;
    return values.firstWhere((type) => type.id == id, orElse: () => report);
  }
}

/// Current status of a deliverable
enum DeliverableStatus {
  notStarted('not_started', 'Not Started'),
  inProgress('in_progress', 'In Progress'),
  atRisk('at_risk', 'At Risk'),
  pendingReview('pending_review', 'Pending Review'),
  completed('completed', 'Completed'),
  overdue('overdue', 'Overdue');

  final String id;
  final String displayName;

  const DeliverableStatus(this.id, this.displayName);

  static DeliverableStatus fromId(String? id) {
    if (id == null) return notStarted;
    return values.firstWhere(
      (status) => status.id == id,
      orElse: () => notStarted,
    );
  }

  bool get isNotStarted => this == DeliverableStatus.notStarted;
  bool get isInProgress => this == DeliverableStatus.inProgress;
  bool get isAtRisk => this == DeliverableStatus.atRisk;
  bool get isPendingReview => this == DeliverableStatus.pendingReview;
  bool get isCompleted => this == DeliverableStatus.completed;
  bool get isOverdue => this == DeliverableStatus.overdue;
  bool get isActive => isInProgress || isAtRisk || isPendingReview;

  /// Returns the color associated with this status for UI display
  Color get color {
    switch (this) {
      case DeliverableStatus.completed:
        return Colors.green;
      case DeliverableStatus.inProgress:
        return Colors.blue;
      case DeliverableStatus.atRisk:
        return Colors.orange;
      case DeliverableStatus.pendingReview:
        return Colors.purple;
      case DeliverableStatus.overdue:
        return Colors.red;
      case DeliverableStatus.notStarted:
        return Colors.grey;
    }
  }
}

/// How frequently a deliverable must be submitted
enum DeliverableFrequency {
  oneTime('one_time', 'One Time'),
  monthly('monthly', 'Monthly'),
  quarterly('quarterly', 'Quarterly'),
  semiAnnual('semi_annual', 'Semi-Annual'),
  annual('annual', 'Annual');

  final String id;
  final String displayName;

  const DeliverableFrequency(this.id, this.displayName);

  static DeliverableFrequency fromId(String? id) {
    if (id == null) return oneTime;
    return values.firstWhere((freq) => freq.id == id, orElse: () => oneTime);
  }
}

/// A deliverable required by a permit (report, survey, documentation, etc.)
class Deliverable extends Record {
  static const Object _unset = Object();

  final String? permitId;
  final String name;
  final String? description;
  final DeliverableType type;
  final DateTime dueDate;
  final DeliverableStatus status;
  final DeliverableFrequency frequency;
  final List<String> requiredSiteIds;
  final bool isExclusive;

  // Quantity targets
  final int? totalOrganismTarget;
  final int? genetDiversityTarget;

  const Deliverable({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    this.permitId,
    required this.name,
    required this.dueDate,
    this.description,
    DeliverableType? type,
    DeliverableStatus? status,
    DeliverableFrequency? frequency,
    List<String>? requiredSiteIds,
    this.isExclusive = false,
    this.totalOrganismTarget,
    this.genetDiversityTarget,
    super.metadata,
  }) : type = type ?? DeliverableType.report,
       status = status ?? DeliverableStatus.notStarted,
       frequency = frequency ?? DeliverableFrequency.oneTime,
       requiredSiteIds = requiredSiteIds ?? const [];

  Deliverable.fromJson(super.json)
    : permitId = (json['permitId'] as String?)?.isNotEmpty == true
          ? json['permitId'] as String
          : null,
      name = json['name'] ?? 'Untitled Deliverable',
      description = json['description'],
      type = DeliverableType.fromId(json['typeId']),
      dueDate = DateTimeConverter.parseWithFallback(
          json['dueDate'],
          fallback: DateTime.now().add(const Duration(days: 30)),
          fieldName: 'dueDate',
          modelType: 'Deliverable',
          recordId: json['id'],
        ),
      status = DeliverableStatus.fromId(json['statusId']),
      frequency = DeliverableFrequency.fromId(json['frequencyId']),
      requiredSiteIds = json['requiredSiteIds'] != null
          ? List<String>.from(json['requiredSiteIds'])
          : const [],
      isExclusive = json['isExclusive'] ?? false,
      totalOrganismTarget = json['totalOrganismTarget'] != null
          ? (json['totalOrganismTarget'] as num).toInt()
          : null,
      genetDiversityTarget = json['genetDiversityTarget'] != null
          ? (json['genetDiversityTarget'] as num).toInt()
          : null,
      super.fromJson();

  Deliverable.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.metadata,
    String? permitId,
    String? name,
    String? description,
    DeliverableType? type,
    DateTime? dueDate,
    DeliverableStatus? status,
    DeliverableFrequency? frequency,
    List<String>? requiredSiteIds,
    bool? isExclusive,
    int? totalOrganismTarget,
    int? genetDiversityTarget,
  }) : permitId = permitId ??
           ((json?['permitId'] as String?)?.isNotEmpty == true
               ? json!['permitId'] as String
               : null),
       name = name ?? json?['name'] ?? 'Untitled Deliverable',
       description = description ?? json?['description'],
       type = type ?? DeliverableType.fromId(json?['typeId']),
       dueDate =
           dueDate ??
           DateTimeConverter.parseWithFallback(
             json?['dueDate'],
             fallback: DateTime.now().add(const Duration(days: 30)),
             fieldName: 'dueDate',
             modelType: 'Deliverable',
             recordId: json?['id'],
           ),
       status = status ?? DeliverableStatus.fromId(json?['statusId']),
       frequency =
           frequency ?? DeliverableFrequency.fromId(json?['frequencyId']),
       requiredSiteIds =
           requiredSiteIds ??
           (json?['requiredSiteIds'] != null
               ? List<String>.from(json!['requiredSiteIds'])
               : const []),
       isExclusive = isExclusive ?? json?['isExclusive'] ?? false,
       totalOrganismTarget = totalOrganismTarget ??
           (json?['totalOrganismTarget'] != null
               ? (json!['totalOrganismTarget'] as num).toInt()
               : null),
       genetDiversityTarget = genetDiversityTarget ??
           (json?['genetDiversityTarget'] != null
               ? (json!['genetDiversityTarget'] as num).toInt()
               : null),
       super.partial();

  @override
  ModelType get modelType => ModelType.deliverable;

  @override
  Map<String, dynamic> toJson() {
    return {
      if (permitId != null) 'permitId': permitId,
      'name': name,
      if (description != null) 'description': description,
      'typeId': type.id,
      'dueDate': dueDate.toIso8601String(),
      'statusId': status.id,
      'frequencyId': frequency.id,
      'requiredSiteIds': requiredSiteIds,
      'isExclusive': isExclusive,
      if (totalOrganismTarget != null) 'totalOrganismTarget': totalOrganismTarget,
      if (genetDiversityTarget != null)
        'genetDiversityTarget': genetDiversityTarget,
      ...super.toJson(),
    };
  }

  @override
  Deliverable copyWith({
    Object? id = _unset,
    Object? createdById = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? organizationId = _unset,
    Object? permitId = _unset,
    Object? name = _unset,
    Object? description = _unset,
    Object? type = _unset,
    Object? dueDate = _unset,
    Object? status = _unset,
    Object? frequency = _unset,
    Object? requiredSiteIds = _unset,
    Object? isExclusive = _unset,
    Object? totalOrganismTarget = _unset,
    Object? genetDiversityTarget = _unset,
    Map<String, dynamic>? metadata,
  }) {
    return Deliverable(
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
      permitId: identical(permitId, _unset)
          ? this.permitId
          : permitId as String?,
      name: identical(name, _unset) ? this.name : name as String,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      type: identical(type, _unset) ? this.type : type as DeliverableType,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime,
      status: identical(status, _unset)
          ? this.status
          : status as DeliverableStatus,
      frequency: identical(frequency, _unset)
          ? this.frequency
          : frequency as DeliverableFrequency,
      requiredSiteIds: identical(requiredSiteIds, _unset)
          ? this.requiredSiteIds
          : requiredSiteIds as List<String>,
      isExclusive: identical(isExclusive, _unset)
          ? this.isExclusive
          : isExclusive as bool,
      totalOrganismTarget: identical(totalOrganismTarget, _unset)
          ? this.totalOrganismTarget
          : totalOrganismTarget as int?,
      genetDiversityTarget: identical(genetDiversityTarget, _unset)
          ? this.genetDiversityTarget
          : genetDiversityTarget as int?,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    // permitId is optional - deliverables can exist without permits (e.g., outplant targets)
    return super.validate() && name.isNotEmpty;
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        permitId,
        name,
        description,
        type,
        dueDate,
        status,
        frequency,
        requiredSiteIds,
        isExclusive,
        totalOrganismTarget,
        genetDiversityTarget,
      ];

  // Computed properties
  bool get isOverdue {
    if (status.isCompleted) return false;
    return DateTime.now().isAfter(dueDate);
  }

  bool get isDueSoon {
    if (status.isCompleted || isOverdue) return false;
    final now = DateTime.now();
    final daysUntilDue = dueDate.difference(now).inDays;
    return daysUntilDue <= 14; // 2 weeks warning
  }

  int get daysUntilDue {
    final now = DateTime.now();
    if (isOverdue) return 0;
    return dueDate.difference(now).inDays;
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    final now = DateTime.now();
    return now.difference(dueDate).inDays;
  }

  bool get hasRequiredSites => requiredSiteIds.isNotEmpty;

  bool get isComplete => status.isCompleted;
}
