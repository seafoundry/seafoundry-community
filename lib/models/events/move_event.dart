import 'package:seafoundry_community/models/events/event.dart';
import 'package:seafoundry_community/models/types/model_type.dart';

/// Mixin providing common properties for move-related events
/// Note: Does not require InventoryEvent to keep these lightweight
mixin MoveEvent on Event {
  String get fromUrlPath;
  String get toUrlPath;
  String get fromParentId;
  String get toParentId;

  ModelType get fromModelType => ModelType.fromPath(fromUrlPath);
  ModelType get toModelType => ModelType.fromPath(toUrlPath);
}
