// @tier: community
import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Recurrence pattern for tasks.
///
/// Defines how often a task should repeat. The [level] property indicates
/// frequency, where higher values mean more frequent recurrence:
/// - oneTime (1): Single occurrence, no repetition
/// - monthly (2): Once per month
/// - biweekly (3): Every two weeks
/// - weekly (4): Once per week
/// - daily (5): Every day
class TaskRecurrence extends Equatable {
  static const String oneTimeId = 'one_time';
  static const String dailyId = 'daily';
  static const String weeklyId = 'weekly';
  static const String biweeklyId = 'biweekly';
  static const String monthlyId = 'monthly';

  final String id;
  final String label;

  /// Frequency level where higher values indicate more frequent recurrence.
  /// Useful for sorting or comparing recurrence patterns.
  final int level;

  /// Color associated with this recurrence for UI display.
  final Color color;

  const TaskRecurrence._({
    required this.id,
    required this.label,
    required this.level,
    required this.color,
  });

  /// One-time task with no repetition.
  static const TaskRecurrence oneTime = TaskRecurrence._(
    id: oneTimeId,
    label: 'One-time',
    level: 1,
    color: Colors.grey,
  );

  /// Task that repeats every day.
  static const TaskRecurrence daily = TaskRecurrence._(
    id: dailyId,
    label: 'Daily',
    level: 5,
    color: Colors.red,
  );

  /// Task that repeats every week.
  static const TaskRecurrence weekly = TaskRecurrence._(
    id: weeklyId,
    label: 'Weekly',
    level: 4,
    color: Colors.orange,
  );

  /// Task that repeats every two weeks.
  static const TaskRecurrence biweekly = TaskRecurrence._(
    id: biweeklyId,
    label: 'Bi-weekly',
    level: 3,
    color: Colors.amber,
  );

  /// Task that repeats every month.
  static const TaskRecurrence monthly = TaskRecurrence._(
    id: monthlyId,
    label: 'Monthly',
    level: 2,
    color: Colors.blue,
  );

  /// List of all recurrence patterns ordered by frequency level (ascending).
  ///
  /// Order: oneTime(1) → monthly(2) → biweekly(3) → weekly(4) → daily(5)
  /// This means least frequent first, most frequent last.
  static const List<TaskRecurrence> values = [
    oneTime, // level 1 - no repetition
    monthly, // level 2 - once per month
    biweekly, // level 3 - every two weeks
    weekly, // level 4 - once per week
    daily, // level 5 - every day
  ];

  /// Returns a [TaskRecurrence] from an ID string, or null if not found.
  ///
  /// Use this when null is a valid outcome (e.g., for optional fields).
  static TaskRecurrence? maybeFromId(String? id) {
    if (id == null) return null;
    for (final recurrence in values) {
      if (recurrence.id == id) {
        return recurrence;
      }
    }
    return null;
  }

  /// Creates a [TaskRecurrence] from an ID string.
  ///
  /// Returns [oneTime] as a fallback for null or invalid IDs.
  static TaskRecurrence fromId(String? id) {
    if (id == null) return oneTime;
    final result = maybeFromId(id);
    if (result != null) return result;

    // Log warning for invalid ID, then fallback to oneTime
    developer.log(
      'Invalid TaskRecurrence ID "$id", falling back to oneTime. '
      'Valid IDs: ${values.map((r) => r.id).join(', ')}',
      name: 'TaskRecurrence',
      level: 900, // Warning level
    );
    return oneTime;
  }

  /// Compare two recurrence patterns by frequency level.
  int compareTo(TaskRecurrence other) {
    return level.compareTo(other.level);
  }

  /// Returns true if this recurrence is more frequent than [other].
  bool isMoreFrequentThan(TaskRecurrence other) {
    return level > other.level;
  }

  /// Returns true if this is a repeating task (not one-time).
  bool get isRepeating => this != oneTime;

  @override
  List<Object?> get props => [id, label, level, color];
}
