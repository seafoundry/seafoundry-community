// @tier: community
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';

abstract class Named {
  String get name;
}

mixin GroupParent implements InventoryRecord, GraphNodeRecord {
  String get siteId;
}
