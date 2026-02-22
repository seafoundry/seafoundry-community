// @tier: community
import 'package:seafoundry_app/models/types/record_type.dart';

class DiseaseType extends BuiltinRecordType {
  const DiseaseType({required super.id, required super.name});

  static final Map<String, DiseaseType> builtins = {
    other.id: other,
    ciliates.id: ciliates,
    rtn.id: rtn,
    brownJelly.id: brownJelly,
    stonyCoralTl.id: stonyCoralTl,
  };

  static const DiseaseType unknown = DiseaseType(id: 'disease_type_unknown', name: 'Unknown Disease Type');

  static const DiseaseType other = DiseaseType(id: 'disease_type_other', name: 'Other');

  static const DiseaseType ciliates = DiseaseType(id: 'disease_type_ciliates', name: 'Ciliates');

  static const DiseaseType rtn = DiseaseType(id: 'disease_type_rtn', name: 'Rapid Tissue Necrosis');

  static const DiseaseType brownJelly = DiseaseType(id: 'disease_type_brown_jelly', name: 'Brown Jelly Disease');

  static const DiseaseType stonyCoralTl = DiseaseType(
    id: 'disease_type_stony_coral_tl',
    name: 'Stony Coral Tissue Loss',
  );
}
