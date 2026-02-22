// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/monitoring_type.dart';

/// Type of monitoring requirement for deliverables
enum MonitoringRequirementType {
  preOutplant('pre_outplant', 'Pre-Outplant Monitoring'),
  postOutplant('post_outplant', 'Post-Outplant Monitoring'),
  ecologicalSurvey('ecological_survey', 'Ecological Survey');

  final String id;
  final String displayName;

  const MonitoringRequirementType(this.id, this.displayName);

  static MonitoringRequirementType fromId(String? id) {
    if (id == null) return preOutplant;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => preOutplant,
    );
  }

  /// Convert to MonitoringType for event records
  MonitoringType? toMonitoringType() {
    switch (this) {
      case MonitoringRequirementType.preOutplant:
        return MonitoringType.preOutplant;
      case MonitoringRequirementType.postOutplant:
        return MonitoringType.postOutplant;
      case MonitoringRequirementType.ecologicalSurvey:
        return null; // Ecological surveys are separate model
    }
  }
}

/// Interval for monitoring requirements.
///
/// For pre-outplant intervals, the duration represents days BEFORE the outplant.
/// For post-outplant and ecological intervals, duration is days AFTER the reference.
enum MonitoringInterval {
  // Pre-outplant intervals (days before outplant)
  threeDays('3_days', '3 Days Before', Duration(days: 3)),
  sevenDays('7_days', '7 Days Before', Duration(days: 7)),

  // Post-outplant intervals (days after outplant)
  oneWeek('1_week', '1 Week After', Duration(days: 7)),
  oneMonth('1_month', '1 Month After', Duration(days: 30)),
  threeMonths('3_months', '3 Months After', Duration(days: 90)),
  sixMonths('6_months', '6 Months After', Duration(days: 180)),
  oneYear('1_year', '1 Year After', Duration(days: 365)),

  // Ecological survey intervals (recurring frequency)
  quarterly('quarterly', 'Quarterly', Duration(days: 90)),
  semiAnnual('semi_annual', 'Semi-Annual', Duration(days: 180)),
  annual('annual', 'Annual', Duration(days: 365));

  final String id;
  final String displayName;
  final Duration duration;

  const MonitoringInterval(this.id, this.displayName, this.duration);

  static MonitoringInterval fromId(String? id) {
    if (id == null) return oneMonth;
    return values.firstWhere(
      (interval) => interval.id == id,
      orElse: () => oneMonth,
    );
  }

  /// Intervals applicable for pre-outplant monitoring
  static List<MonitoringInterval> get preOutplantIntervals => [
    threeDays,
    sevenDays,
  ];

  /// Intervals applicable for post-outplant monitoring
  static List<MonitoringInterval> get postOutplantIntervals => [
    oneWeek,
    oneMonth,
    threeMonths,
    sixMonths,
    oneYear,
  ];

  /// Intervals applicable for ecological surveys
  static List<MonitoringInterval> get ecologicalSurveyIntervals => [
    quarterly,
    semiAnnual,
    annual,
  ];

  /// Get applicable intervals for a monitoring requirement type
  static List<MonitoringInterval> forType(MonitoringRequirementType type) {
    switch (type) {
      case MonitoringRequirementType.preOutplant:
        return preOutplantIntervals;
      case MonitoringRequirementType.postOutplant:
        return postOutplantIntervals;
      case MonitoringRequirementType.ecologicalSurvey:
        return ecologicalSurveyIntervals;
    }
  }

  /// Whether this interval is valid for the given requirement type
  bool isValidFor(MonitoringRequirementType type) {
    return forType(type).contains(this);
  }
}

/// A monitoring requirement within a deliverable
class MonitoringRequirement extends Equatable {
  final MonitoringRequirementType type;
  final MonitoringInterval interval;
  final bool isRequired;
  final String? notes;

  const MonitoringRequirement({
    required this.type,
    required this.interval,
    this.isRequired = true,
    this.notes,
  });

  MonitoringRequirement.fromJson(Map<String, dynamic> json)
    : type = MonitoringRequirementType.fromId(json['typeId']),
      interval = MonitoringInterval.fromId(json['intervalId']),
      isRequired = json['isRequired'] ?? true,
      notes = json['notes'];

  Map<String, dynamic> toJson() => {
    'typeId': type.id,
    'intervalId': interval.id,
    'isRequired': isRequired,
    if (notes != null) 'notes': notes,
  };

  MonitoringRequirement copyWith({
    MonitoringRequirementType? type,
    MonitoringInterval? interval,
    bool? isRequired,
    String? notes,
  }) {
    return MonitoringRequirement(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      isRequired: isRequired ?? this.isRequired,
      notes: notes ?? this.notes,
    );
  }

  /// Whether this requirement has a valid type/interval combination
  bool get isValidCombination => interval.isValidFor(type);

  @override
  List<Object?> get props => [type, interval, isRequired, notes];
}
