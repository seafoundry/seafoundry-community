// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Represents a monitoring schedule for a restoration site
///
/// Tracks when sites need to be monitored to meet permit requirements.
/// Automatically calculates overdue status and days until/past due date.
class MonitoringSchedule extends Record {
  /// The site being monitored
  final String siteId;

  /// Monitoring interval in days (e.g., 30 for monthly, 90 for quarterly)
  final int intervalDays;

  /// When monitoring was last completed
  final DateTime? lastMonitoringDate;

  /// When the next monitoring is due
  final DateTime nextDueDate;

  /// Optional permit requirement description (e.g., "Annual NOAA Report")
  final String? permitRequirement;

  const MonitoringSchedule({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.siteId,
    required this.intervalDays,
    this.lastMonitoringDate,
    required this.nextDueDate,
    this.permitRequirement,
    super.metadata,
  });

  MonitoringSchedule.fromJson(super.json)
    : siteId = json['siteId'] ?? Missing.string,
      intervalDays = safeInt(json['intervalDays']) ?? 30,
      lastMonitoringDate = json['lastMonitoringDate'] != null
          ? DateTime.parse(json['lastMonitoringDate'])
          : null,
      nextDueDate = DateTimeConverter.parseWithFallback(
        json['nextDueDate'],
        fallback: DateTime.now(),
        fieldName: 'nextDueDate',
        modelType: 'MonitoringSchedule',
        recordId: json['id'],
      ),
      permitRequirement = json['permitRequirement'],
      super.fromJson();

  MonitoringSchedule.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    String? siteId,
    int? intervalDays,
    DateTime? lastMonitoringDate,
    DateTime? nextDueDate,
    String? permitRequirement,
    super.metadata,
  }) : siteId = siteId ?? json?['siteId'] ?? Missing.string,
       intervalDays =
           intervalDays ?? safeInt(json?['intervalDays']) ?? 30,
       lastMonitoringDate =
           lastMonitoringDate ??
           (json?['lastMonitoringDate'] != null
               ? DateTime.parse(json?['lastMonitoringDate'])
               : null),
       nextDueDate =
           nextDueDate ??
           DateTimeConverter.parseWithFallback(
             json?['nextDueDate'],
             fallback: DateTime.now(),
             fieldName: 'nextDueDate',
             modelType: 'MonitoringSchedule',
             recordId: json?['id'],
           ),
       permitRequirement = permitRequirement ?? json?['permitRequirement'],
       super.partial();

  @override
  ModelType get modelType => ModelType.monitoringSchedule;

  @override
  Map<String, dynamic> toJson() {
    return {
      'siteId': siteId,
      'intervalDays': intervalDays,
      if (lastMonitoringDate != null)
        'lastMonitoringDate': lastMonitoringDate!.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      if (permitRequirement != null) 'permitRequirement': permitRequirement,
      ...super.toJson(),
    };
  }

  @override
  MonitoringSchedule copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? siteId,
    int? intervalDays,
    DateTime? lastMonitoringDate,
    bool clearLastMonitoringDate = false,
    DateTime? nextDueDate,
    String? permitRequirement,
    bool clearPermitRequirement = false,
    Map<String, dynamic>? metadata,
  }) {
    return MonitoringSchedule(
      id: id ?? this.id,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      siteId: siteId ?? this.siteId,
      intervalDays: intervalDays ?? this.intervalDays,
      lastMonitoringDate: clearLastMonitoringDate
          ? null
          : (lastMonitoringDate ?? this.lastMonitoringDate),
      nextDueDate: nextDueDate ?? this.nextDueDate,
      permitRequirement: clearPermitRequirement
          ? null
          : (permitRequirement ?? this.permitRequirement),
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    return super.validate() &&
        siteId.isNotEmpty &&
        intervalDays > 0 &&
        !nextDueDate.isBefore(DateTime(2000)); // Sanity check for valid date
  }

  @override
  List<Object?> get props => [
    ...super.props,
    siteId,
    intervalDays,
    lastMonitoringDate,
    nextDueDate,
    permitRequirement,
  ];

  /// Check if this schedule is currently overdue
  bool get isOverdue => DateTime.now().isAfter(nextDueDate);

  /// Days until the next monitoring is due (negative if overdue)
  int get daysUntilDue => nextDueDate.difference(DateTime.now()).inDays;

  /// Days past due (0 if not overdue)
  int get daysOverdue =>
      isOverdue ? DateTime.now().difference(nextDueDate).inDays : 0;

  /// Human-readable status description
  String get statusDescription {
    if (isOverdue) {
      return 'Overdue by $daysOverdue days';
    } else if (daysUntilDue == 0) {
      return 'Due today';
    } else if (daysUntilDue == 1) {
      return 'Due tomorrow';
    } else if (daysUntilDue <= 7) {
      return 'Due in $daysUntilDue days';
    } else {
      return 'Due in $daysUntilDue days';
    }
  }

  /// Calculate the next due date after completing monitoring
  DateTime calculateNextDueDate(DateTime completedDate) {
    return completedDate.add(Duration(days: intervalDays));
  }

  /// Create a schedule with updated monitoring completion
  MonitoringSchedule withMonitoringCompleted({
    required DateTime completedDate,
    required String updatedById,
  }) {
    final newNextDueDate = calculateNextDueDate(completedDate);
    final now = DateTime.now().toIso8601String();

    return copyWith(
      lastMonitoringDate: completedDate,
      nextDueDate: newNextDueDate,
      updatedAt: now,
      updatedById: updatedById,
    );
  }
}
