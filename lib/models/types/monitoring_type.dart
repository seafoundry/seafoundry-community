// @tier: community

/// Type of monitoring event, distinguishing pre-outplant health checks
/// from post-outplant survival tracking.
///
/// Ecological surveys are handled by a separate [EcologicalSurvey] model
/// since they capture different environmental metrics.
enum MonitoringType {
  /// Health assessment before outplanting (typically 3-7 days prior)
  preOutplant('pre_outplant', 'Pre-Outplant'),

  /// Survival and health tracking after outplanting
  /// (typically 1 week, 1 month, 1 year intervals)
  postOutplant('post_outplant', 'Post-Outplant'),

  /// General nursery monitoring not tied to an outplant event
  nursery('nursery', 'Nursery'),

  /// Ad-hoc or unscheduled monitoring
  adhoc('adhoc', 'Ad-hoc');

  const MonitoringType(this.id, this.name);

  final String id;
  final String name;

  String get displayName => name;

  /// Whether this monitoring type is tied to an outplant event
  bool get isOutplantRelated => this == preOutplant || this == postOutplant;

  /// Whether this is pre-outplant monitoring
  bool get isPreOutplant => this == preOutplant;

  /// Whether this is post-outplant monitoring
  bool get isPostOutplant => this == postOutplant;

  /// Selectable values for UI dropdowns
  static List<MonitoringType> get selectableValues => const [
    MonitoringType.preOutplant,
    MonitoringType.postOutplant,
    MonitoringType.nursery,
    MonitoringType.adhoc,
  ];

  /// Parse from string ID, returns null if not found
  static MonitoringType? maybeFromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final type in MonitoringType.values) {
      if (type.id == id) return type;
    }
    return null;
  }

  /// Parse from string ID with fallback to adhoc
  static MonitoringType fromId(String? id) {
    return maybeFromId(id) ?? MonitoringType.adhoc;
  }

  /// Infer monitoring type based on timing relative to outplant event.
  ///
  /// [monitoringDate] - When the monitoring occurred
  /// [outplantDate] - When the outplant event occurred (null if not tied to outplant)
  ///
  /// Returns:
  /// - [preOutplant] if monitoring is before outplant date
  /// - [postOutplant] if monitoring is on or after outplant date
  /// - [nursery] if no outplant event is associated
  static MonitoringType inferFromTiming({
    required DateTime monitoringDate,
    DateTime? outplantDate,
  }) {
    if (outplantDate == null) {
      return MonitoringType.nursery;
    }
    if (monitoringDate.isBefore(outplantDate)) {
      return MonitoringType.preOutplant;
    }
    return MonitoringType.postOutplant;
  }
}
