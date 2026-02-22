// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Priority levels for tasks
class TaskPriority extends Equatable {
  final String id;
  final String label;
  final int level;
  final Color color;

  const TaskPriority._({required this.id, required this.label, required this.level, required this.color});

  /// Get TaskPriority by ID, returns null if not found.
  ///
  /// Use this when the priority is optional or when you need to handle
  /// missing/invalid IDs gracefully.
  static TaskPriority? maybeFromId(String? id) {
    if (id == null) return null;
    for (final priority in values) {
      if (priority.id == id) return priority;
    }
    return null;
  }

  /// Get TaskPriority by ID, returns [medium] as default if not found.
  ///
  /// Use this when a fallback is acceptable. For nullable semantics,
  /// use [maybeFromId] instead.
  static TaskPriority fromId(String? id) {
    return maybeFromId(id) ?? medium;
  }

  /// Low priority - Not urgent, can be done when convenient
  static const TaskPriority low = TaskPriority._(id: 'low', label: 'Low', level: 1, color: Colors.green);

  /// Medium priority - Standard priority level
  static const TaskPriority medium = TaskPriority._(id: 'medium', label: 'Medium', level: 2, color: Colors.orange);

  /// High priority - Urgent, needs immediate attention
  static const TaskPriority high = TaskPriority._(id: 'high', label: 'High', level: 3, color: Colors.red);

  /// List of all task priority levels
  static const List<TaskPriority> values = [low, medium, high];

  /// Compare two priority levels
  int compareTo(TaskPriority other) {
    return level.compareTo(other.level);
  }

  @override
  List<Object?> get props => [id];
}
