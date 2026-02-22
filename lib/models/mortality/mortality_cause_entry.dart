// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/interfaces/organism_kind_entry.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';

class MortalityCauseEntry extends Equatable implements OrganismKindEntry {
  MortalityCauseEntry({
    required this.id,
    required this.organismKind,
    required this.label,
    this.lifeStage,
    this.description,
    this.recommendedAction,
    this.severity,
    List<String>? tags,
  }) : tags = List.unmodifiable(tags ?? const <String>[]);

  factory MortalityCauseEntry.fromMap(
    OrganismKind organismKind,
    Map<String, dynamic> map,
  ) {
    final label =
        map['label']?.toString() ?? map['name']?.toString() ?? 'Mortality';
    final lifeStage = LifeStageX.tryParse(map['lifeStage']?.toString());
    final description = map['description']?.toString();
    final recommendedAction =
        map['recommendedAction']?.toString() ??
        map['recommended_action']?.toString();
    final severity = map['severity']?.toString();
    final tags = _stringList(map['tags']);

    return MortalityCauseEntry(
      id:
          map['id']?.toString() ??
          _fallbackId(
            organismKind: organismKind,
            label: label,
            lifeStage: lifeStage,
            severity: severity,
            tags: tags,
          ),
      organismKind: organismKind,
      label: label,
      lifeStage: lifeStage,
      description: description,
      recommendedAction: recommendedAction,
      severity: severity,
      tags: tags,
    );
  }

  @override
  final String id;
  @override
  final OrganismKind organismKind;
  final String label;
  final LifeStage? lifeStage;
  final String? description;
  final String? recommendedAction;
  final String? severity;
  final List<String> tags;

  @override
  String get displayName => label;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'organismKind': organismKind.name,
    'label': label,
    if (lifeStage != null) 'lifeStage': lifeStage!.id,
    if (description != null) 'description': description,
    if (recommendedAction != null) 'recommendedAction': recommendedAction,
    if (severity != null) 'severity': severity,
    if (tags.isNotEmpty) 'tags': tags,
  };

  @override
  List<Object?> get props => [
    id,
    organismKind,
    label,
    lifeStage,
    description,
    recommendedAction,
    severity,
    tags,
  ];

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((entry) => entry?.toString())
          .whereType<String>()
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return const <String>[];
  }

  static String _fallbackId({
    required OrganismKind organismKind,
    required String label,
    LifeStage? lifeStage,
    String? severity,
    List<String>? tags,
  }) {
    final normalizedTags = (tags ?? const <String>[])
        .map((t) => slug(t))
        .toList(growable: false)
      ..sort();
    final parts = <String>[
      organismKind.name,
      lifeStage?.id ?? 'any',
      slug(label),
      severity?.toLowerCase() ?? 'unspecified',
      if (normalizedTags.isNotEmpty) 'tags_${normalizedTags.join('-')}',
    ];
    return parts.join('_');
  }
}
