// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/training/task_sop_requirement.dart';
import 'package:seafoundry_app/models/types/husbandry_action_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/task_priority.dart';
import 'package:seafoundry_app/models/types/task_status.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/models/types/task_recurrence.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// An event representing a husbandry task
/// Tasks can be assigned to roles, have deadlines, and track completion status
class TaskEvent extends Event with ImageEvent {
  static const Object _unset = Object();
  static const Object unset = _unset;
  @override
  final String? imageUrl;

  /// Title of the task
  final String title;

  /// Description of what needs to be done
  final String? description;

  /// Type of husbandry action required
  final String? husbandryActionTypeId;

  /// Priority level of the task
  final String? priorityId;

  /// Role assigned to complete the task
  final String? assignedRoleId;

  /// Person assigned to complete the task
  final String? assignedUserId;

  /// Minimum role required to perform this task
  final String? minimumRoleId;

  /// IDs of training modules required to perform this task
  final List<String>? requiredTrainingModuleIds;

  /// Deadline for task completion
  final DateTime? deadline;

  /// Date when the task was started (marked as in-progress).
  ///
  /// Set when transitioning to [TaskStatus.inProgress] via [markInProgress],
  /// cleared when transitioning to [TaskStatus.notStarted] via [markNotStarted].
  /// Preserved when transitioning to [TaskStatus.completed].
  final DateTime? startedAt;

  /// Date when the task was completed
  final DateTime? completedAt;

  /// ID of the user who completed the task
  final String? completedById;

  /// ID of the observation event that triggered this task
  final String? observationEventId;

  /// Workflow status identifier for the task
  final String? statusId;

  /// Reference to the task definition used (for traceability)
  final String? husbandryTaskDefinitionId;

  /// Snapshot of required SOPs at task creation time.
  ///
  /// This list is conceptually immutable once set - it captures the SOP
  /// requirements and user's completion status at the moment the task was
  /// created. The snapshot provides an audit trail and ensures consistent
  /// enforcement even if SOPs are updated later.
  ///
  /// IMPORTANT: Do not modify this list after task creation. While Dart
  /// doesn't enforce list immutability, any modifications would break the
  /// audit trail and could lead to inconsistent enforcement behavior.
  final List<TaskSOPRequirement>? snapshotSOPRequirements;

  /// Whether this task requires SOP completion before starting
  final bool? requireSOPCompletionBeforeStart;

  /// Reason provided when SOP enforcement was bypassed to start this task.
  ///
  /// This field stores the override reason for audit trail when a task was
  /// started via markInProgress with enforceSOP: false. This provides
  /// accountability and traceability for policy exceptions.
  final String? sopEnforcementOverrideReason;
  
  /// Recurrence frequency for the task (e.g. daily, weekly)
  final String? recurrenceId;

  TaskEvent({
    required super.id,
    required this.title,
    this.description,
    this.husbandryActionTypeId,
    this.priorityId,
    this.assignedRoleId,
    this.assignedUserId,
    this.minimumRoleId,
    this.requiredTrainingModuleIds,
    this.deadline,
    this.startedAt,
    this.completedAt,
    this.completedById,
    this.observationEventId,
    this.imageUrl,
    this.statusId,
    this.husbandryTaskDefinitionId,
    this.snapshotSOPRequirements,
    this.requireSOPCompletionBeforeStart,
    this.sopEnforcementOverrideReason,
    this.recurrenceId,
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
  }) : super(eventTypeId: EventType.task.id);

  TaskEvent.fromJson(super.json)
    : title = json['title'] ?? 'Untitled Task',
      description = json['description'],
      husbandryActionTypeId = json['husbandryActionTypeId'],
      priorityId = json['priorityId'],
      assignedRoleId = json['assignedRoleId'],
      assignedUserId = json['assignedUserId'],
      minimumRoleId = json['minimumRoleId'],
      requiredTrainingModuleIds = json['requiredTrainingModuleIds'] != null
          ? List<String>.from(json['requiredTrainingModuleIds'])
          : null,
      deadline = json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      startedAt = json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : null,
      completedAt = json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      completedById = json['completedById'],
      observationEventId = json['observationEventId'],
      imageUrl = json['imageUrl'],
      statusId = json['statusId'] ?? TaskStatus.notStarted.id,
      husbandryTaskDefinitionId = json['husbandryTaskDefinitionId'] as String?,
      snapshotSOPRequirements = _parseSOPRequirements(json['snapshotSOPRequirements']),
      requireSOPCompletionBeforeStart = json['requireSOPCompletionBeforeStart'] as bool?,
      sopEnforcementOverrideReason = json['sopEnforcementOverrideReason'] as String?,
      recurrenceId = json['recurrenceId'] as String?,
      super.fromJson();

  TaskEvent.partial({
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
    String? title,
    String? description,
    String? husbandryActionTypeId,
    String? priorityId,
    String? assignedRoleId,
    String? assignedUserId,
    String? minimumRoleId,
    List<String>? requiredTrainingModuleIds,
    DateTime? deadline,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completedById,
    String? observationEventId,
    String? imageUrl,
    String? statusId,
    String? husbandryTaskDefinitionId,
    List<TaskSOPRequirement>? snapshotSOPRequirements,
    bool? requireSOPCompletionBeforeStart,
    String? sopEnforcementOverrideReason,
    String? recurrenceId,
  }) : title = title ?? json?['title'] ?? 'Untitled Task',
       description = description ?? json?['description'],
       husbandryActionTypeId =
           husbandryActionTypeId ?? json?['husbandryActionTypeId'],
       priorityId = priorityId ?? json?['priorityId'],
       assignedRoleId = assignedRoleId ?? json?['assignedRoleId'],
       assignedUserId = assignedUserId ?? json?['assignedUserId'],
       minimumRoleId = minimumRoleId ?? json?['minimumRoleId'],
       requiredTrainingModuleIds =
           requiredTrainingModuleIds ??
           (json?['requiredTrainingModuleIds'] != null
               ? List<String>.from(json?['requiredTrainingModuleIds'])
               : null),
       deadline =
           deadline ??
           (json?['deadline'] != null
               ? DateTime.parse(json?['deadline'])
               : null),
       startedAt =
           startedAt ??
           (json?['startedAt'] != null
               ? DateTime.parse(json?['startedAt'])
               : null),
       completedAt =
           completedAt ??
           (json?['completedAt'] != null
               ? DateTime.parse(json?['completedAt'])
               : null),
       completedById = completedById ?? json?['completedById'],
       observationEventId = observationEventId ?? json?['observationEventId'],
       imageUrl = imageUrl ?? json?['imageUrl'],
       statusId =
           statusId ??
           json?['statusId'] ??
           (json?['completedAt'] != null
               ? TaskStatus.completed.id
               : TaskStatus.notStarted.id),
       husbandryTaskDefinitionId =
           husbandryTaskDefinitionId ?? json?['husbandryTaskDefinitionId'] as String?,
       snapshotSOPRequirements =
           snapshotSOPRequirements ?? _parseSOPRequirements(json?['snapshotSOPRequirements']),
       requireSOPCompletionBeforeStart =
           requireSOPCompletionBeforeStart ?? json?['requireSOPCompletionBeforeStart'] as bool?,
       sopEnforcementOverrideReason =
           sopEnforcementOverrideReason ?? json?['sopEnforcementOverrideReason'] as String?,
       recurrenceId = recurrenceId ?? json?['recurrenceId'] as String?,
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'title': title,
      'description': description,
      'husbandryActionTypeId': husbandryActionTypeId,
      'priorityId': priorityId,
      'assignedRoleId': assignedRoleId,
      'assignedUserId': assignedUserId,
      'minimumRoleId': minimumRoleId,
      'requiredTrainingModuleIds': requiredTrainingModuleIds,
      'deadline': deadline?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'completedById': completedById,
      'isCompleted': isCompleted,
      'observationEventId': observationEventId,
      'imageUrl': imageUrl,
      'statusId': statusId ?? TaskStatus.notStarted.id,
      'husbandryTaskDefinitionId': husbandryTaskDefinitionId,
      'snapshotSOPRequirements': snapshotSOPRequirements?.map((e) => e.toJson()).toList(),
      'requireSOPCompletionBeforeStart': requireSOPCompletionBeforeStart,
      'sopEnforcementOverrideReason': sopEnforcementOverrideReason,
      'recurrenceId': recurrenceId,
    };
  }

  @override
  bool validate() {
    return super.validate() && title.isNotEmpty;
  }

  @override
  TaskEvent copyWith({
    Object? id = _unset,
    Object? title = _unset,
    Object? description = _unset,
    Object? husbandryActionTypeId = _unset,
    Object? priorityId = _unset,
    Object? assignedRoleId = _unset,
    Object? assignedUserId = _unset,
    Object? minimumRoleId = _unset,
    Object? requiredTrainingModuleIds = _unset,
    Object? deadline = _unset,
    Object? startedAt = _unset,
    Object? completedAt = _unset,
    Object? completedById = _unset,
    Object? observationEventId = _unset,
    Object? imageUrl = _unset,
    Object? statusId = _unset,
    Object? husbandryTaskDefinitionId = _unset,
    Object? snapshotSOPRequirements = _unset,
    Object? requireSOPCompletionBeforeStart = _unset,
    Object? sopEnforcementOverrideReason = _unset,
    Object? recurrenceId = _unset,
    Object? eventTypeId = _unset,
    Object? createdById = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? organizationId = _unset,
    Object? recordId = _unset,
    Object? recordModelType = _unset,
    Object? missionId = _unset,
    bool clearMissionId = false,
    Object? urlPath = _unset,
    Object? internalPath = _unset,
    Object? slug = _unset,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return TaskEvent(
      id: identical(id, _unset) ? this.id : id as String,
      title: identical(title, _unset) ? this.title : title as String,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      husbandryActionTypeId: identical(husbandryActionTypeId, _unset)
          ? this.husbandryActionTypeId
          : husbandryActionTypeId as String?,
      priorityId: identical(priorityId, _unset)
          ? this.priorityId
          : priorityId as String?,
      assignedRoleId: identical(assignedRoleId, _unset)
          ? this.assignedRoleId
          : assignedRoleId as String?,
      assignedUserId: identical(assignedUserId, _unset)
          ? this.assignedUserId
          : assignedUserId as String?,
      minimumRoleId: identical(minimumRoleId, _unset)
          ? this.minimumRoleId
          : minimumRoleId as String?,
      requiredTrainingModuleIds: identical(requiredTrainingModuleIds, _unset)
          ? this.requiredTrainingModuleIds
          : (requiredTrainingModuleIds as List<String>?),
      deadline: identical(deadline, _unset)
          ? this.deadline
          : deadline as DateTime?,
      startedAt: identical(startedAt, _unset)
          ? this.startedAt
          : startedAt as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      completedById: identical(completedById, _unset)
          ? this.completedById
          : completedById as String?,
      observationEventId: identical(observationEventId, _unset)
          ? this.observationEventId
          : observationEventId as String?,
      imageUrl: identical(imageUrl, _unset)
          ? this.imageUrl
          : imageUrl as String?,
      statusId: identical(statusId, _unset)
          ? this.statusId
          : statusId as String?,
      husbandryTaskDefinitionId: identical(husbandryTaskDefinitionId, _unset)
          ? this.husbandryTaskDefinitionId
          : husbandryTaskDefinitionId as String?,
      snapshotSOPRequirements: identical(snapshotSOPRequirements, _unset)
          ? this.snapshotSOPRequirements
          : (snapshotSOPRequirements as List<TaskSOPRequirement>?)?.toList(),
      requireSOPCompletionBeforeStart: identical(requireSOPCompletionBeforeStart, _unset)
          ? this.requireSOPCompletionBeforeStart
          : requireSOPCompletionBeforeStart as bool?,
      sopEnforcementOverrideReason: identical(sopEnforcementOverrideReason, _unset)
          ? this.sopEnforcementOverrideReason
          : sopEnforcementOverrideReason as String?,
      recurrenceId: identical(recurrenceId, _unset)
          ? this.recurrenceId
          : recurrenceId as String?,
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
      recordId: identical(recordId, _unset)
          ? this.recordId
          : recordId as String,
      recordModelType: identical(recordModelType, _unset)
          ? this.recordModelType
          : recordModelType as ModelType,
      urlPath: identical(urlPath, _unset) ? this.urlPath : urlPath as String,
      internalPath: identical(internalPath, _unset)
          ? this.internalPath
          : internalPath as String,
      slug: identical(slug, _unset) ? this.slug : slug as String,
      missionId: clearMissionId
          ? null
          : (identical(missionId, _unset) ? this.missionId : missionId as String?),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
    );
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        title,
        description,
        husbandryActionTypeId,
        priorityId,
        assignedRoleId,
        assignedUserId,
        minimumRoleId,
        requiredTrainingModuleIds,
        deadline,
        startedAt,
        completedAt,
        completedById,
        observationEventId,
        imageUrl,
        statusId,
        husbandryTaskDefinitionId,
        snapshotSOPRequirements,
        requireSOPCompletionBeforeStart,
        sopEnforcementOverrideReason,
        recurrenceId,
      ];
      
  /// Gets the recurrence pattern for this task.
  ///
  /// Defaults to [TaskRecurrence.oneTime] if [recurrenceId] is null or invalid.
  /// This ensures tasks always have a valid recurrence pattern for display
  /// and logic purposes, even for legacy tasks created before recurrence
  /// support was added.
  TaskRecurrence get recurrence => TaskRecurrence.fromId(recurrenceId);

  /// Get the husbandry action type for this task
  HusbandryActionType get husbandryActionType =>
      HusbandryActionType.fromId(husbandryActionTypeId);

  /// Get the priority level for this task
  TaskPriority get priority => TaskPriority.fromId(priorityId);

  /// Current workflow status for the task
  TaskStatus get status => TaskStatus.fromId(statusId);

  /// Returns true if this task has been completed.
  ///
  /// Uses [status] as the canonical source of truth. The [completedAt] and
  /// [completedById] fields are set by [markCompleted] when status transitions
  /// to completed, but status is the authoritative indicator.
  bool get isCompleted => status == TaskStatus.completed;

  /// Returns true if this task is currently in progress.
  bool get isInProgress => status == TaskStatus.inProgress;

  /// Returns the elapsed duration since the task was started.
  ///
  /// Returns null if the task is not in progress or [startedAt] is not set.
  ///
  /// **Note:** This getter uses [DateTime.now()] internally, so it returns
  /// different values on each call. For display purposes only.
  Duration? get elapsedDuration {
    if (!isInProgress || startedAt == null) return null;
    return DateTime.now().difference(startedAt!);
  }

  /// Check if the task is overdue
  bool get isOverdue =>
      !isCompleted && deadline != null && deadline!.isBefore(DateTime.now());

  /// Mark the task as completed
  TaskEvent markCompleted(String userId) {
    return copyWith(
      completedAt: DateTime.now(),
      completedById: userId,
      statusId: TaskStatus.completed.id,
    );
  }

  /// Check if this task can be started (considering SOP requirements)
  /// Returns true if:
  /// - No SOP requirements exist, OR
  /// - requireSOPCompletionBeforeStart is false, OR
  /// - All required SOPs are completed
  bool canBeStarted() {
    // If no enforcement required, can always start
    if (requireSOPCompletionBeforeStart != true) {
      return true;
    }

    // If no snapshot requirements, can start.
    // Note: Empty list with enforcement enabled is valid - it means enforcement
    // is on but there are no SOPs to check. This can happen if the task
    // definition's SOPs were auto-disabled due to user not having completed them.
    // TaskCreationService handles this scenario by disabling enforcement when needed.
    if (snapshotSOPRequirements == null || snapshotSOPRequirements!.isEmpty) {
      return true;
    }

    // Check if all required SOPs are completed
    return snapshotSOPRequirements!
        .where((req) => req.isRequired)
        .every((req) => req.isCompleted);
  }

  /// Get list of incomplete required SOPs blocking task start
  List<TaskSOPRequirement> get incompleteRequiredSOPs {
    // If enforcement is disabled, return empty list
    if (requireSOPCompletionBeforeStart != true) return [];

    if (snapshotSOPRequirements == null) return [];
    return snapshotSOPRequirements!
        .where((req) => req.isRequired && !req.isCompleted)
        .toList();
  }

  /// Mark task as actively being worked on
  ///
  /// By default, throws if requireSOPCompletionBeforeStart is true and
  /// required SOPs are incomplete. Use [enforceSOP: false] with a required
  /// [overrideReason] for admin overrides (audit logged and persisted).
  ///
  /// Throws [StateError] if enforcement is enabled and SOPs are incomplete.
  /// Throws [ArgumentError] if enforceSOP is false but overrideReason is null.
  TaskEvent markInProgress({
    bool enforceSOP = true,
    String? overrideReason,
  }) {
    // Validate current status - prevent invalid transitions
    if (status == TaskStatus.completed) {
      throw StateError(
        'Cannot mark a completed task as in-progress. '
        'Completed tasks cannot be restarted.',
      );
    }

    // Skip if already in progress (noop optimization)
    if (status == TaskStatus.inProgress) {
      return this;
    }

    final canStart = canBeStarted();

    if (!canStart) {
      if (enforceSOP) {
        throw StateError(
          'Cannot start task: ${incompleteRequiredSOPs.length} required SOPs not completed. '
          'Missing SOPs: ${incompleteRequiredSOPs.map((r) => r.displayName).join(", ")}',
        );
      }

      // Security: Require override reason when bypassing enforcement
      if (overrideReason == null || overrideReason.trim().isEmpty) {
        throw ArgumentError(
          'overrideReason is required when bypassing SOP enforcement (enforceSOP: false). '
          'An override reason must be provided for audit trail and accountability.',
        );
      }
    }

    return copyWith(
      statusId: TaskStatus.inProgress.id,
      startedAt: DateTime.now(),
      completedAt: null,
      completedById: null,
      sopEnforcementOverrideReason: overrideReason,
    );
  }

  /// Reset task back to not started
  TaskEvent markNotStarted() {
    return copyWith(
      statusId: TaskStatus.notStarted.id,
      startedAt: null,
      completedAt: null,
      completedById: null,
    );
  }

  /// Reassign the task to a different role
  TaskEvent reassignToRole(String roleId) {
    return copyWith(
      assignedRoleId: roleId,
      assignedUserId: null, // Clear user assignment when reassigning to role
    );
  }

  /// Reassign the task to a specific user
  TaskEvent reassignToUser(String userId) {
    return copyWith(assignedUserId: userId);
  }

  /// Update the priority of the task
  TaskEvent updatePriority(String priorityId) {
    return copyWith(priorityId: priorityId);
  }

  /// Update the deadline of the task
  TaskEvent updateDeadline(DateTime deadline) {
    return copyWith(deadline: deadline);
  }

  /// Get the minimum role required for this task
  UserRole? get minimumRole => UserRole.fromId(minimumRoleId);

  /// Get the assigned role for this task
  UserRole? get assignedRole => UserRole.fromId(assignedRoleId);

  /// Check if the task is unassigned (no user or role)
  bool get isUnassigned => assignedUserId == null && assignedRoleId == null;

  /// Check if the task is assigned to someone (user or role)
  bool get isAssigned => !isUnassigned;

  /// Check if the task is assigned to a specific user
  bool get isAssignedToUser => assignedUserId != null;

  /// Check if the task is assigned to a role (but not a specific user)
  bool get isAssignedToRole => assignedRoleId != null && assignedUserId == null;

  /// Unassign the task from both user and role
  TaskEvent unassign() {
    return copyWith(
      assignedUserId: null,
      assignedRoleId: null,
    );
  }

  /// Claim the task for a user
  TaskEvent claim(String userId) {
    return copyWith(assignedUserId: userId);
  }

  /// Check if a user can see this task based on assignment
  ///
  /// A user can see a task if:
  /// 1. The task is unassigned (visible to everyone)
  /// 2. The task is assigned directly to them
  /// 3. The task is assigned to a role and user's role is at least that level
  bool canBeSeenByUser({
    required String userId,
    required String userRoleId,
  }) {
    // Unassigned tasks are visible to everyone
    if (isUnassigned) {
      return true;
    }

    // If assigned to this specific user, they can see it
    if (assignedUserId == userId) {
      return true;
    }

    // If assigned to another user, only they can see it
    if (assignedUserId != null && assignedUserId != userId) {
      return false;
    }

    // If assigned to a role, check if user's role is sufficient
    if (assignedRoleId != null) {
      final userRole = UserRole.fromId(userRoleId);
      final taskRole = assignedRole;

      if (userRole == null || taskRole == null) {
        return false;
      }

      return userRole.isAtLeast(taskRole);
    }

    // Security: fail-closed by default. If we reach here, the task is in an
    // unexpected state and we should deny visibility.
    return false;
  }

  /// Check if a user with the given role can perform this task
  bool canBePerformedByRole(String roleId) {
    if (minimumRoleId == null) {
      // If no minimum role specified, allow all roles (view-only and above)
      return true;
    }

    final userRole = UserRole.fromId(roleId);
    final requiredRole = minimumRole;

    if (userRole == null || requiredRole == null) {
      return false;
    }

    return userRole.isAtLeast(requiredRole);
  }

  /// Check if a user has completed all required training for this task
  bool hasCompletedRequiredTraining(List<String> completedModuleIds) {
    if (requiredTrainingModuleIds == null ||
        requiredTrainingModuleIds!.isEmpty) {
      return true;
    }

    return requiredTrainingModuleIds!.every(
      (moduleId) => completedModuleIds.contains(moduleId),
    );
  }

  /// Add a required training module
  TaskEvent withRequiredTraining(String trainingModuleId) {
    final currentModules = requiredTrainingModuleIds ?? [];
    if (currentModules.contains(trainingModuleId)) {
      return this;
    }

    final updatedModules = List<String>.from(currentModules)
      ..add(trainingModuleId);
    return copyWith(requiredTrainingModuleIds: updatedModules);
  }

  /// Set the minimum role required for this task
  TaskEvent withMinimumRole(String roleId) {
    return copyWith(minimumRoleId: roleId);
  }

  /// Check if a user can claim this task based on role and training requirements
  ///
  /// A user can claim a task if:
  /// 1. The task is not already completed
  /// 2. They are not already assigned to someone else
  /// 3. They have the required minimum role level
  /// 4. If the task is assigned to a role, they have that role level
  /// 5. They have completed all required training modules
  bool canBeClaimedBy({
    required String userId,
    required String userRoleId,
    required List<String> completedTrainingModuleIds,
  }) {
    // Cannot claim a completed task
    if (isCompleted) return false;

    // If task is already assigned to another user, can't claim
    if (assignedUserId != null && assignedUserId != userId) {
      return false;
    }

    // Check minimum role requirement
    if (!canBePerformedByRole(userRoleId)) {
      return false;
    }

    // Check assigned role requirement
    if (assignedRoleId != null) {
      final userRole = UserRole.fromId(userRoleId);
      final taskRole = assignedRole;

      if (userRole == null || taskRole == null) {
        return false;
      }

      if (!userRole.isAtLeast(taskRole)) {
        return false;
      }
    }

    // Check training requirements
    if (!hasCompletedRequiredTraining(completedTrainingModuleIds)) {
      return false;
    }

    return true;
  }

  /// Check if a user can both claim AND start this task.
  ///
  /// This combines [canBeClaimedBy] (role + training checks) with
  /// [canBeStarted] (SOP completion checks) for a complete eligibility check.
  ///
  /// Returns true only if the user meets ALL requirements to claim the task
  /// and begin work immediately. Task must be in notStarted status.
  bool canBeClaimedAndStartedBy({
    required String userId,
    required String userRoleId,
    required List<String> completedTrainingModuleIds,
  }) {
    // Task must be in notStarted status to be claimed and started
    if (status != TaskStatus.notStarted) return false;

    return canBeClaimedBy(
      userId: userId,
      userRoleId: userRoleId,
      completedTrainingModuleIds: completedTrainingModuleIds,
    ) && canBeStarted();
  }

  static List<TaskSOPRequirement>? _parseSOPRequirements(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    return raw.map((e) {
      final map = safeMapCast(e);
      return map != null ? TaskSOPRequirement.fromJson(map) : null;
    }).whereType<TaskSOPRequirement>().toList();
  }
}
