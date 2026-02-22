// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/models.dart';

sealed class EventState extends Equatable {
  const EventState();

  @override
  List<Object?> get props => [];
}

class EventInitial extends EventState {
  const EventInitial();
}

class EventLoading extends EventState {
  const EventLoading({required this.event});

  final Event event;

  @override
  List<Object?> get props => [event];
}

class EventLoaded extends EventState {
  const EventLoaded({
    required this.event,
    required this.eventType,
    this.createdByUser,
    this.referencedRecord,
    this.fromParentRecord,
    this.toParentRecord,
    this.groupRecord,
    this.siteRecord,
    this.organismRecordSnapshot,
    this.relatedOrganismRecords = const {},
  });

  final Event event;
  final EventType eventType;
  final User? createdByUser;
  final InventoryRecord? referencedRecord;
  final GraphNodeRecord? fromParentRecord;
  final GraphNodeRecord? toParentRecord;
  final GraphNodeRecord? groupRecord;
  final GraphNodeRecord? siteRecord;
  final OrganismRecord? organismRecordSnapshot;
  final Map<String, OrganismRecord?> relatedOrganismRecords;

  bool get isMoveEvent => event is MoveInEvent || event is MoveOutEvent;

  @override
  List<Object?> get props => [
    event,
    eventType,
    createdByUser,
    referencedRecord,
    fromParentRecord,
    toParentRecord,
    groupRecord,
    siteRecord,
    organismRecordSnapshot,
    relatedOrganismRecords,
  ];
}

class EventError extends EventState {
  const EventError({required this.message, this.error});

  final String message;
  final Object? error;

  @override
  List<Object?> get props => [message, error];
}
