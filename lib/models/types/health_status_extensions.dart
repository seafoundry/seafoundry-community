// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

/// Extension providing UI-related utilities for HealthStatus.
extension HealthStatusColors on HealthStatus {
  /// Returns the display color for this health status.
  Color get displayColor {
    return switch (this) {
      HealthStatus.healthy => Colors.green,
      HealthStatus.recovering => Colors.lightGreen,
      HealthStatus.stressed => Colors.orange,
      HealthStatus.bleached => Colors.amber,
      HealthStatus.damaged => Colors.deepOrange,
      HealthStatus.diseased => Colors.red,
      HealthStatus.fragmented => Colors.purple,
      HealthStatus.deceased => Colors.grey,
      HealthStatus.lost => Colors.grey.shade400,
      HealthStatus.transferred => Colors.blue,
      HealthStatus.outplanted => Colors.teal,
      HealthStatus.unknown => Colors.grey.shade300,
    };
  }
}
