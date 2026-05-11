import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/model_interfaces.dart';
import 'package:seafoundry_app/models/types/attachment_method.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

abstract class RecordType with EquatableMixin implements Named {
  String get id;
}

class BuiltinRecordType implements RecordType {
  const BuiltinRecordType({required this.id, required this.name});

  @override
  final String id;
  @override
  final String name;

  @override
  List<Object?> get props => [id, name];

  @override
  bool get stringify => true;

  static Map<String, BuiltinRecordType> builtins = {
    ...GroupType.builtins,
    ...EventType.builtins,
    ...SiteType.builtins,
    ...PopulationLossReason.builtins,
    ...AttachmentMethod.builtins,
  };
}
