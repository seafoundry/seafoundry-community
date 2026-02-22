// @tier: community
import 'package:seafoundry_app/models/mission.dart';
import 'package:seafoundry_app/models/mission_allocation.dart';

/// Extension providing mutation methods for Mission.
///
/// These methods return a new Mission instance with the requested changes,
/// maintaining immutability.
extension MissionMutations on Mission {
  /// Mark mission as scheduled
  Mission markScheduled() {
    return copyWith(status: MissionStatus.scheduled);
  }

  /// Mark mission as in progress
  Mission markInProgress() {
    return copyWith(status: MissionStatus.inProgress);
  }

  /// Mark mission as completed
  Mission markCompleted() {
    return copyWith(status: MissionStatus.completed);
  }

  /// Mark mission as cancelled
  Mission markCancelled() {
    return copyWith(status: MissionStatus.cancelled);
  }

  /// Add a site to the mission
  Mission addSite(String siteId) {
    if (siteIds.contains(siteId)) return this;
    final updatedSiteIds = [...siteIds, siteId];
    return copyWith(siteIds: updatedSiteIds);
  }

  /// Remove a site from the mission
  Mission removeSite(String siteId) {
    final updatedSiteIds = siteIds.where((id) => id != siteId).toList();
    return copyWith(siteIds: updatedSiteIds);
  }

  /// Add a task to the mission
  Mission addTask(String taskId) {
    if (taskIds.contains(taskId)) return this;
    final updatedTaskIds = [...taskIds, taskId];
    return copyWith(taskIds: updatedTaskIds);
  }

  /// Remove a task from the mission
  Mission removeTask(String taskId) {
    final updatedTaskIds = taskIds.where((id) => id != taskId).toList();
    return copyWith(taskIds: updatedTaskIds);
  }

  /// Add a crew member to the mission
  Mission addCrewMember(String userId) {
    if (crewUserIds.contains(userId)) return this;
    final updatedCrewIds = [...crewUserIds, userId];
    return copyWith(crewUserIds: updatedCrewIds);
  }

  /// Remove a crew member from the mission
  Mission removeCrewMember(String userId) {
    final updatedCrewIds = crewUserIds.where((id) => id != userId).toList();
    return copyWith(crewUserIds: updatedCrewIds);
  }

  /// Update the scheduled date
  Mission updateScheduledDate(DateTime date) {
    return copyWith(scheduledDate: date);
  }

  /// Update the end date
  Mission updateEndDate(DateTime? date) {
    return copyWith(endDate: date);
  }

  /// Update estimated duration
  Mission updateEstimatedDuration(double? hours) {
    return copyWith(estimatedDurationHours: hours);
  }

  /// Capture weather snapshot
  Mission captureWeather(Map<String, dynamic> weather) {
    return copyWith(weatherSnapshot: weather);
  }

  /// Add a deliverable to the mission
  Mission addDeliverable(String deliverableId) {
    if (deliverableIds.contains(deliverableId)) return this;
    final updatedDeliverableIds = [...deliverableIds, deliverableId];
    return copyWith(deliverableIds: updatedDeliverableIds);
  }

  /// Remove a deliverable from the mission
  Mission removeDeliverable(String deliverableId) {
    final updatedDeliverableIds =
        deliverableIds.where((id) => id != deliverableId).toList();
    return copyWith(deliverableIds: updatedDeliverableIds);
  }

  /// Add an allocation to the mission
  Mission addAllocation(MissionAllocation allocation) {
    // Check if allocation for this organism already exists
    final existingIndex = plannedAllocations.indexWhere(
      (a) => a.organismId == allocation.organismId,
    );
    if (existingIndex >= 0) {
      // Replace existing allocation
      final updatedAllocations = [...plannedAllocations];
      updatedAllocations[existingIndex] = allocation;
      return copyWith(plannedAllocations: updatedAllocations);
    }
    final updatedAllocations = [...plannedAllocations, allocation];
    return copyWith(plannedAllocations: updatedAllocations);
  }

  /// Remove an allocation from the mission by organism ID
  Mission removeAllocation(String organismId) {
    final updatedAllocations =
        plannedAllocations.where((a) => a.organismId != organismId).toList();
    return copyWith(plannedAllocations: updatedAllocations);
  }
}
