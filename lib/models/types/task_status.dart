// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Workflow statuses for tasks created from event dialogs or spreadsheets.
class TaskStatus extends Equatable {
  const TaskStatus._({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String id;
  final String label;
  final Color color;
  final IconData icon;

  static const TaskStatus notStarted = TaskStatus._(
    id: 'not_started',
    label: 'Not started',
    color: Colors.grey,
    icon: Icons.radio_button_unchecked,
  );

  static const TaskStatus inProgress = TaskStatus._(
    id: 'in_progress',
    label: 'In progress',
    color: Colors.amber,
    icon: Icons.timelapse,
  );

  static const TaskStatus completed = TaskStatus._(
    id: 'completed',
    label: 'Completed',
    color: Colors.green,
    icon: Icons.check_circle,
  );

  static const List<TaskStatus> values = [notStarted, inProgress, completed];

  static TaskStatus fromId(String? id) {
    if (id == null || id.isEmpty) {
      return TaskStatus.notStarted;
    }
    return values.firstWhere(
      (status) => status.id == id,
      orElse: () => TaskStatus.notStarted,
    );
  }

  @override
  List<Object?> get props => [id];
}
