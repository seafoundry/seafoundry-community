import 'package:seafoundry_community/models/records/graph_node_record.dart';
import 'package:seafoundry_community/models/records/inventory_record.dart';

abstract class Named {
  String get name;
}

mixin GroupParent implements InventoryRecord, GraphNodeRecord {
  String get siteId;
}
