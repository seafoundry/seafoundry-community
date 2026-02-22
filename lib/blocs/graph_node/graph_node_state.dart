// @tier: community
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/models/models.dart';

abstract class GraphNodeState<T extends GraphNodeRecord> extends Equatable {
  const GraphNodeState({required this.record});
  final T record;

  ModelType get modelType => record.modelType;

  @override
  List<Object?> get props => [record];
}

class GraphNodeInitial<T extends GraphNodeRecord> extends GraphNodeState<T> {
  const GraphNodeInitial({required super.record});
}

class GraphNodeLoading<T extends GraphNodeRecord> extends GraphNodeState<T> {
  const GraphNodeLoading({required super.record});
}

abstract class GraphLoadedState<T extends GraphNodeRecord> extends GraphNodeState<T> {
  const GraphLoadedState({required super.record, required this.children, required this.events, this.creator});

  final List<GraphNode> children;
  final List<Event> events;
  final User? creator;

  List<EventType> get eventTypes;
  List<StatusEvent> get statusEvents => events.whereType<StatusEvent>().toList();

  @mustBeOverridden
  GraphNodeState<T> copyWith({T? record, List<GraphNode>? children, List<Event>? events, User? creator});

  /// Override props to include all fields that should trigger UI rebuilds.
  /// The base class only includes [record], which caused BlocBuilder to not
  /// rebuild when events/children/creator changed (they were considered "equal").
  @override
  List<Object?> get props => [record, children, events, creator];
}

class GraphNodeError<T extends GraphNodeRecord> extends GraphNodeState<T> {
  const GraphNodeError({required super.record, required this.error});
  final Object error;
}
