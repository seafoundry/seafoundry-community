// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/interfaces/organism_kind_entry.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';

class HusbandryScheduleEntry extends Equatable implements OrganismKindEntry {
  const HusbandryScheduleEntry({
    required this.id,
    required this.title,
    required this.organismKind,
    this.lifeStage,
    this.frequencyDays,
    this.instructions,
  });

  factory HusbandryScheduleEntry.fromMap(
    OrganismKind organismKind,
    Map<String, dynamic> map,
  ) {
    final title = map['title']?.toString() ?? 'Untitled';
    final lifeStage = LifeStageX.tryParse(map['lifeStage']?.toString());
    final frequencyDays = safeInt(map['frequencyDays']);
    return HusbandryScheduleEntry(
      id:
          map['id']?.toString() ??
          _fallbackId(
            organismKind: organismKind,
            title: title,
            lifeStage: lifeStage,
            frequencyDays: frequencyDays,
          ),
      title: title,
      organismKind: organismKind,
      lifeStage: lifeStage,
      frequencyDays: frequencyDays,
      instructions: map['instructions']?.toString(),
    );
  }

  @override
  final String id;
  final String title;
  @override
  final OrganismKind organismKind;
  final LifeStage? lifeStage;
  final int? frequencyDays;
  final String? instructions;

  @override
  String get displayName => title;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'organismKind': organismKind.name,
    if (lifeStage != null) 'lifeStage': lifeStage!.id,
    if (frequencyDays != null) 'frequencyDays': frequencyDays,
    if (instructions != null) 'instructions': instructions,
  };

  @override
  List<Object?> get props => [
    id,
    title,
    organismKind,
    lifeStage,
    frequencyDays,
    instructions,
  ];
}

String _fallbackId({
  required OrganismKind organismKind,
  required String title,
  LifeStage? lifeStage,
  int? frequencyDays,
}) {
  final parts = <String>[
    organismKind.name,
    lifeStage?.id ?? 'any',
    slug(title, fallback: 'task'),
    'freq_${frequencyDays?.toString() ?? 'na'}',
  ];
  return parts.join('_');
}
