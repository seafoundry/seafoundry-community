// @tier: community
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/models/models.dart';

class GraphNodeStreamBundle<T extends GraphNodeRecord> {
  const GraphNodeStreamBundle({
    required this.recordStream,
    required this.childrenStream,
    required this.eventsStream,
    required this.shallowEventsStream,
    required this.creatorStream,
  });

  final Stream<T?> recordStream;
  final Stream<List<GraphNode>> childrenStream;
  final Stream<List<Event>> eventsStream;
  final Stream<List<Event>> shallowEventsStream;
  final Stream<User?> creatorStream;

  List<Stream<dynamic>> get subStreams => <Stream<dynamic>>[
    recordStream,
    childrenStream,
    eventsStream,
    creatorStream,
  ];
}

abstract class GraphNodeStreamAdapter {
  const GraphNodeStreamAdapter();

  GraphNodeStreamBundle<T> configureBundle<T extends GraphNodeRecord>({
    required GraphNode<T> node,
    required GraphNodeStreamBundle<T> defaultBundle,
  });

  Stream<List<dynamic>> combine(List<Stream<dynamic>> subStreams) {
    return CombineLatestStream.list(subStreams);
  }
}

class DefaultGraphNodeStreamAdapter extends GraphNodeStreamAdapter {
  const DefaultGraphNodeStreamAdapter();

  @override
  GraphNodeStreamBundle<T> configureBundle<T extends GraphNodeRecord>({
    required GraphNode<T> node,
    required GraphNodeStreamBundle<T> defaultBundle,
  }) {
    return defaultBundle;
  }
}
