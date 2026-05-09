import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/user.dart';

abstract class GraphNodeEvent {
  const GraphNodeEvent();
}

class GraphNodeLoadRequested extends GraphNodeEvent {
  const GraphNodeLoadRequested();
}

class GraphNodeReloadRequested extends GraphNodeEvent {
  const GraphNodeReloadRequested();
}

class GraphNodeRecordUpdated<T extends GraphNodeRecord> extends GraphNodeEvent {
  const GraphNodeRecordUpdated(this.record);
  final T record;
}

class GraphNodeChildrenUpdated extends GraphNodeEvent {
  const GraphNodeChildrenUpdated(this.children);
  final List<GraphNode> children;
}

class GraphNodeEventsUpdated extends GraphNodeEvent {
  const GraphNodeEventsUpdated(this.events);
  final List<Event> events;
}

class GraphNodeCreatorUpdated extends GraphNodeEvent {
  const GraphNodeCreatorUpdated(this.creator);
  final User creator;
}
