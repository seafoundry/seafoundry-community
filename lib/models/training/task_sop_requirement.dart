// @tier: community
import 'package:equatable/equatable.dart';

/// Represents a training requirement linking a task to an SOP
/// Used for enforcing completion gates and tracking training compliance
///
/// This is the canonical model for SOP requirements embedded in tasks.
/// It captures both the requirement definition and the completion status.
class TaskSOPRequirement extends Equatable {
  const TaskSOPRequirement({
    required this.sopId,
    required this.sopVersion,
    required this.isRequired,
    this.sopTitle,
    this.completedAt,
    this.completedBy,
  });

  factory TaskSOPRequirement.fromJson(Map<String, dynamic> json) {
    return TaskSOPRequirement(
      sopId: json['sopId'] as String,
      sopVersion: json['sopVersion'] as String? ?? '1.0',
      isRequired: json['isRequired'] as bool? ?? true,
      sopTitle: json['sopTitle'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      completedBy: json['completedBy'] as String?,
    );
  }

  /// ID of the SOP that is required
  final String sopId;

  /// Version of the SOP at time of task creation (for audit trail)
  final String sopVersion;

  /// Title of the SOP for display purposes
  final String? sopTitle;

  /// Whether this SOP must be completed (vs recommended)
  final bool isRequired;

  /// When the SOP was completed by the user
  final DateTime? completedAt;

  /// User ID who completed the SOP
  final String? completedBy;

  /// Whether the user has completed this SOP
  bool get isCompleted => completedAt != null;

  /// Display name - uses title if available, otherwise SOP ID
  String get displayName {
    final title = sopTitle?.trim();
    return (title != null && title.isNotEmpty) ? title : sopId;
  }

  Map<String, dynamic> toJson() => {
        'sopId': sopId,
        'sopVersion': sopVersion,
        'isRequired': isRequired,
        if (sopTitle != null) 'sopTitle': sopTitle,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (completedBy != null) 'completedBy': completedBy,
      };

  TaskSOPRequirement copyWith({
    String? sopId,
    String? sopVersion,
    String? sopTitle,
    bool? isRequired,
    DateTime? completedAt,
    String? completedBy,
  }) {
    return TaskSOPRequirement(
      sopId: sopId ?? this.sopId,
      sopVersion: sopVersion ?? this.sopVersion,
      sopTitle: sopTitle ?? this.sopTitle,
      isRequired: isRequired ?? this.isRequired,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
    );
  }

  /// Mark this requirement as completed
  TaskSOPRequirement markCompleted({
    required String userId,
    DateTime? at,
  }) {
    return copyWith(
      completedAt: at ?? DateTime.now(),
      completedBy: userId,
    );
  }

  @override
  List<Object?> get props => [
        sopId,
        sopVersion,
        sopTitle,
        isRequired,
        completedAt,
        completedBy,
      ];
}
