// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_community/models/types/event_type.dart';

class StatusEventType extends EventType {
  const StatusEventType({required super.id, required super.name});

  static final Map<String, StatusEventType> builtins = {
    propagationReady.id: propagationReady,
    recentPropagation.id: recentPropagation,
  };

  static const StatusEventType propagationReady = StatusEventType(id: 'event_status_propagation_ready', name: 'Ready for Propagation');

  static const StatusEventType recentPropagation = StatusEventType(id: 'event_status_recent_propagation', name: 'Recent Propagation');
}
