// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/permits/monitoring_requirement.dart';
import 'package:seafoundry_app/models/permits/site_allocation.dart';
import 'package:seafoundry_app/models/permits/species_target.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
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
  final double progressPercent;
  final DateTime? completedAt;
  final DateTime? lastReportGeneratedAt;
  final List<String> assigneeUserIds;

  // Funder information
  final String? funderName; // Deprecated: Use funderIds
  final String? funderContactName;
  final String? funderContactEmail;
  final List<String> funderIds;
  final String? grantNumber;
  final bool isExclusive;

  // Quantity targets
  final int? totalOrganismTarget;
  final int? genetDiversityTarget;
  final List<SpeciesTarget> speciesTargets;

  // Site allocation
  final List<SiteAllocation> siteAllocations;

  // Monitoring requirements
  final List<MonitoringRequirement> monitoringRequirements;

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
    double? progressPercent,
    this.completedAt,
    this.lastReportGeneratedAt,
    List<String>? assigneeUserIds,
    this.funderName,
    this.funderContactName,
    this.funderContactEmail,
    List<String>? funderIds,
    this.grantNumber,
    this.isExclusive = false,
    this.totalOrganismTarget,
    this.genetDiversityTarget,
    List<SpeciesTarget>? speciesTargets,
    List<SiteAllocation>? siteAllocations,
    List<MonitoringRequirement>? monitoringRequirements,
    super.metadata,
  }) : type = type ?? DeliverableType.report,
       status = status ?? DeliverableStatus.notStarted,
       frequency = frequency ?? DeliverableFrequency.oneTime,
       requiredSiteIds = requiredSiteIds ?? const [],
       progressPercent = progressPercent ?? 0.0,
      assigneeUserIds = assigneeUserIds ?? const [],
      speciesTargets = speciesTargets ?? const [],
      siteAllocations = siteAllocations ?? const [],
      monitoringRequirements = monitoringRequirements ?? const [],
      funderIds = funderIds ?? const [];

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
      progressPercent = safeDouble(json['progressPercent']) ?? 0.0,
      completedAt = json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      lastReportGeneratedAt = json['lastReportGeneratedAt'] != null
          ? DateTime.parse(json['lastReportGeneratedAt'])
          : null,
      assigneeUserIds = json['assigneeUserIds'] != null
          ? List<String>.from(json['assigneeUserIds'])
          : const [],
      funderName = json['funderName'],
      funderContactName = json['funderContactName'],
      funderContactEmail = json['funderContactEmail'],
      funderIds = json['funderIds'] != null
          ? List<String>.from(json['funderIds'])
          : const [],
      grantNumber = json['grantNumber'],
      isExclusive = json['isExclusive'] ?? false,
      totalOrganismTarget = safeInt(json['totalOrganismTarget']),
      genetDiversityTarget = safeInt(json['genetDiversityTarget']),
      speciesTargets = json['speciesTargets'] != null
          ? (json['speciesTargets'] as List)
              .map((e) => SpeciesTarget.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      siteAllocations = json['siteAllocations'] != null
          ? (json['siteAllocations'] as List)
              .map((e) => SiteAllocation.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      monitoringRequirements = json['monitoringRequirements'] != null
          ? (json['monitoringRequirements'] as List)
              .map((e) =>
                  MonitoringRequirement.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
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
    double? progressPercent,
    DateTime? completedAt,
    DateTime? lastReportGeneratedAt,
    List<String>? assigneeUserIds,
    String? funderName,
    String? funderContactName,
    String? funderContactEmail,
    List<String>? funderIds,
    String? grantNumber,
    bool? isExclusive,
    int? totalOrganismTarget,
    int? genetDiversityTarget,
    List<SpeciesTarget>? speciesTargets,
    List<SiteAllocation>? siteAllocations,
    List<MonitoringRequirement>? monitoringRequirements,
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
       progressPercent =
           progressPercent ??
           safeDouble(json?['progressPercent']) ??
           0.0,
       completedAt =
           completedAt ??
           (json?['completedAt'] != null
               ? DateTime.parse(json!['completedAt'])
               : null),
      lastReportGeneratedAt =
          lastReportGeneratedAt ??
          (json?['lastReportGeneratedAt'] != null
              ? DateTime.parse(json!['lastReportGeneratedAt'])
              : null),
      assigneeUserIds =
          assigneeUserIds ??
          (json?['assigneeUserIds'] != null
              ? List<String>.from(json!['assigneeUserIds'])
              : const []),
      funderName = funderName ?? json?['funderName'],
      funderContactName = funderContactName ?? json?['funderContactName'],
      funderContactEmail = funderContactEmail ?? json?['funderContactEmail'],
      funderIds = funderIds ??
           (json?['funderIds'] != null
               ? List<String>.from(json!['funderIds'])
               : const []),
       grantNumber = grantNumber ?? json?['grantNumber'],
       isExclusive = isExclusive ?? json?['isExclusive'] ?? false,
       totalOrganismTarget =
           totalOrganismTarget ?? safeInt(json?['totalOrganismTarget']),
       genetDiversityTarget =
           genetDiversityTarget ?? safeInt(json?['genetDiversityTarget']),
       speciesTargets =
           speciesTargets ??
           (json?['speciesTargets'] != null
               ? (json!['speciesTargets'] as List)
                   .map((e) => SpeciesTarget.fromJson(e as Map<String, dynamic>))
                   .toList()
               : const []),
       siteAllocations =
           siteAllocations ??
           (json?['siteAllocations'] != null
               ? (json!['siteAllocations'] as List)
                   .map((e) => SiteAllocation.fromJson(e as Map<String, dynamic>))
                   .toList()
               : const []),
       monitoringRequirements =
           monitoringRequirements ??
           (json?['monitoringRequirements'] != null
               ? (json!['monitoringRequirements'] as List)
                   .map((e) =>
                       MonitoringRequirement.fromJson(e as Map<String, dynamic>))
                   .toList()
               : const []),
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
      'progressPercent': progressPercent,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (lastReportGeneratedAt != null)
        'lastReportGeneratedAt': lastReportGeneratedAt!.toIso8601String(),
      if (assigneeUserIds.isNotEmpty) 'assigneeUserIds': assigneeUserIds,
      if (funderName != null) 'funderName': funderName,
      if (funderContactName != null) 'funderContactName': funderContactName,
      if (funderContactEmail != null) 'funderContactEmail': funderContactEmail,
      if (funderIds.isNotEmpty) 'funderIds': funderIds,
      if (grantNumber != null) 'grantNumber': grantNumber,
      'isExclusive': isExclusive,
      if (totalOrganismTarget != null) 'totalOrganismTarget': totalOrganismTarget,
      if (genetDiversityTarget != null)
        'genetDiversityTarget': genetDiversityTarget,
      if (speciesTargets.isNotEmpty)
        'speciesTargets': speciesTargets.map((e) => e.toJson()).toList(),
      if (siteAllocations.isNotEmpty)
        'siteAllocations': siteAllocations.map((e) => e.toJson()).toList(),
      if (monitoringRequirements.isNotEmpty)
        'monitoringRequirements':
            monitoringRequirements.map((e) => e.toJson()).toList(),
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
    Object? progressPercent = _unset,
    Object? completedAt = _unset,
    Object? lastReportGeneratedAt = _unset,
    Object? assigneeUserIds = _unset,
    Object? funderName = _unset,
    Object? funderContactName = _unset,
    Object? funderContactEmail = _unset,
    Object? funderIds = _unset,
    Object? grantNumber = _unset,
    Object? isExclusive = _unset,
    Object? totalOrganismTarget = _unset,
    Object? genetDiversityTarget = _unset,
    Object? speciesTargets = _unset,
    Object? siteAllocations = _unset,
    Object? monitoringRequirements = _unset,
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
      progressPercent: identical(progressPercent, _unset)
          ? this.progressPercent
          : progressPercent as double,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      lastReportGeneratedAt: identical(lastReportGeneratedAt, _unset)
          ? this.lastReportGeneratedAt
          : lastReportGeneratedAt as DateTime?,
      assigneeUserIds: identical(assigneeUserIds, _unset)
          ? this.assigneeUserIds
          : assigneeUserIds as List<String>,
      funderName: identical(funderName, _unset)
          ? this.funderName
          : funderName as String?,
      funderContactName: identical(funderContactName, _unset)
          ? this.funderContactName
          : funderContactName as String?,
      funderContactEmail: identical(funderContactEmail, _unset)
          ? this.funderContactEmail
          : funderContactEmail as String?,
      funderIds: identical(funderIds, _unset)
          ? this.funderIds
          : funderIds as List<String>,
      grantNumber: identical(grantNumber, _unset)
          ? this.grantNumber
          : grantNumber as String?,
      isExclusive: identical(isExclusive, _unset)
          ? this.isExclusive
          : isExclusive as bool,
      totalOrganismTarget: identical(totalOrganismTarget, _unset)
          ? this.totalOrganismTarget
          : totalOrganismTarget as int?,
      genetDiversityTarget: identical(genetDiversityTarget, _unset)
          ? this.genetDiversityTarget
          : genetDiversityTarget as int?,
      speciesTargets: identical(speciesTargets, _unset)
          ? this.speciesTargets
          : speciesTargets as List<SpeciesTarget>,
      siteAllocations: identical(siteAllocations, _unset)
          ? this.siteAllocations
          : siteAllocations as List<SiteAllocation>,
      monitoringRequirements: identical(monitoringRequirements, _unset)
          ? this.monitoringRequirements
          : monitoringRequirements as List<MonitoringRequirement>,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    // permitId is optional - deliverables can exist without permits (e.g., outplant targets)
    return super.validate() &&
        name.isNotEmpty &&
        progressPercent >= 0.0 &&
        progressPercent <= 100.0;
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
        progressPercent,
        completedAt,
        lastReportGeneratedAt,
        assigneeUserIds,
        funderName,
        funderContactName,
        funderContactEmail,
        funderIds,
        grantNumber,
        isExclusive,
        totalOrganismTarget,
        genetDiversityTarget,
        speciesTargets,
        siteAllocations,
        monitoringRequirements,
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

  bool get hasFunder =>
      (funderName != null && funderName!.isNotEmpty) || funderIds.isNotEmpty;

  bool get hasTargets =>
      totalOrganismTarget != null || genetDiversityTarget != null;

  bool get hasSpeciesTargets => speciesTargets.isNotEmpty;

  bool get hasSiteAllocations => siteAllocations.isNotEmpty;

  /// Total count across all species targets
  int get totalSpeciesTargetCount =>
      speciesTargets.fold(0, (sum, target) => sum + target.targetCount);

  /// Total count across all site allocations
  int get totalSiteAllocationCount =>
      siteAllocations.fold(0, (sum, alloc) => sum + alloc.targetCount);

  /// Mark deliverable as completed
  Deliverable markCompleted() {
    return copyWith(
      status: DeliverableStatus.completed,
      progressPercent: 100.0,
      completedAt: DateTime.now(),
    );
  }

  /// Mark deliverable as in progress
  Deliverable markInProgress() {
    return copyWith(status: DeliverableStatus.inProgress);
  }

  /// Mark deliverable as at risk
  Deliverable markAtRisk() {
    return copyWith(status: DeliverableStatus.atRisk);
  }

  /// Mark deliverable as pending review
  Deliverable markPendingReview() {
    return copyWith(status: DeliverableStatus.pendingReview);
  }

  /// Update progress percentage
  Deliverable updateProgress(double percent) {
    if (percent < 0.0 || percent > 100.0) {
      throw ArgumentError('Progress must be between 0 and 100');
    }
    return copyWith(progressPercent: percent);
  }

  /// Add a required site
  Deliverable addRequiredSite(String siteId) {
    if (requiredSiteIds.contains(siteId)) return this;
    return copyWith(requiredSiteIds: [...requiredSiteIds, siteId]);
  }

  /// Remove a required site
  Deliverable removeRequiredSite(String siteId) {
    final updatedSiteIds = requiredSiteIds.where((id) => id != siteId).toList();
    return copyWith(requiredSiteIds: updatedSiteIds);
  }

  /// Extend the due date
  Deliverable extendDueDate(DateTime newDueDate) {
    return copyWith(dueDate: newDueDate);
  }

  bool get hasMonitoringRequirements => monitoringRequirements.isNotEmpty;

  /// Get pre-outplant monitoring requirements
  List<MonitoringRequirement> get preOutplantRequirements =>
      monitoringRequirements
          .where((r) => r.type == MonitoringRequirementType.preOutplant)
          .toList();

  /// Get post-outplant monitoring requirements
  List<MonitoringRequirement> get postOutplantRequirements =>
      monitoringRequirements
          .where((r) => r.type == MonitoringRequirementType.postOutplant)
          .toList();

  /// Get ecological survey requirements
  List<MonitoringRequirement> get ecologicalSurveyRequirements =>
      monitoringRequirements
          .where((r) => r.type == MonitoringRequirementType.ecologicalSurvey)
          .toList();

  /// Add a monitoring requirement
  Deliverable addMonitoringRequirement(MonitoringRequirement requirement) {
    if (monitoringRequirements.contains(requirement)) return this;
    return copyWith(
      monitoringRequirements: [...monitoringRequirements, requirement],
    );
  }

  /// Remove a monitoring requirement
  Deliverable removeMonitoringRequirement(MonitoringRequirement requirement) {
    final updated =
        monitoringRequirements.where((r) => r != requirement).toList();
    return copyWith(monitoringRequirements: updated);
  }

  // Report generation tracking
  /// Whether a report has ever been generated for this deliverable
  bool get hasReportGenerated => lastReportGeneratedAt != null;

  /// Days since the last report was generated, or -1 if never generated
  ///
  /// Returns 0 if the report was generated today or in the future (clock skew).
  int get daysSinceLastReport {
    if (lastReportGeneratedAt == null) return -1;
    final days = DateTime.now().difference(lastReportGeneratedAt!).inDays;
    return days < 0 ? 0 : days;
  }

  /// Mark that a report was generated now
  Deliverable markReportGenerated() {
    return copyWith(lastReportGeneratedAt: DateTime.now());
  }
}
