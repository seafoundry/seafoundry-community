// @tier: community
// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/health_status_type.dart';

class StatusEventType extends EventType {
  const StatusEventType({required super.id, required super.name});

  static final Map<String, StatusEventType> builtins = {
    propagationReady.id: propagationReady,
    recentPropagation.id: recentPropagation,
    maintenanceNeeded.id: maintenanceNeeded,
    ...HealthStatusType.builtins,
  };

  static const StatusEventType propagationReady = StatusEventType(id: 'event_status_propagation_ready', name: 'Ready for Propagation');

  static const StatusEventType recentPropagation = StatusEventType(id: 'event_status_recent_propagation', name: 'Recent Propagation');

  static const StatusEventType maintenanceNeeded = StatusEventType(
    id: 'event_status_maintenance_needed',
    name: 'Maintenance Needed',
  );
}
