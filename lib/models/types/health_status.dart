enum HealthStatus {
  healthy('healthy', 'Healthy'),
  stressed('stressed', 'Stressed'),
  diseased('diseased', 'Diseased'),
  recovering('recovering', 'Recovering'),
  deceased('deceased', 'Deceased'),
  lost('lost', 'Lost'),
  bleached('bleached', 'Bleached'),
  damaged('damaged', 'Damaged'),
  fragmented('fragmented', 'Fragmented'),
  transferred('transferred', 'Transferred'),
  outplanted('outplanted', 'Outplanted'),
  unknown('unknown', 'Unknown');

  const HealthStatus(this.id, this.name);

  final String id;
  final String name;

  bool get isInactiveInventory =>
      this == deceased ||
      this == lost ||
      this == transferred ||
      this == outplanted;

  bool get isActiveInventory => !isInactiveInventory;

  bool get isUnhealthy => this == diseased || this == stressed;

  bool get isHealthy => this == healthy || this == recovering;

  String get displayName => name;

  static List<HealthStatus> get selectableValues => const [
    HealthStatus.healthy,
    HealthStatus.stressed,
    HealthStatus.diseased,
    HealthStatus.bleached,
    HealthStatus.damaged,
    HealthStatus.recovering,
  ];

  static HealthStatus? maybeFromId(String? id) {
    if (id == null) return null;
    for (final status in HealthStatus.values) {
      if (status.id == id) return status;
    }
    return null;
  }

  static HealthStatus fromId(String? id) {
    return maybeFromId(id) ?? HealthStatus.healthy;
  }
}
