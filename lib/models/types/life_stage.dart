// @tier: community
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

/// Canonical organism life stages used across repositories, dialogs, and CSV
/// adapters. These replace coral-only enums so batch holdings and observation
/// configs can reason about any organism with the same abstraction.
enum LifeStage { unknown, gamete, embryo, larva, juvenile, adult, broodstock }

extension LifeStageX on LifeStage {
  static const Map<LifeStage, _LifeStageMetadata> _metadata =
      <LifeStage, _LifeStageMetadata>{
        LifeStage.unknown: _LifeStageMetadata(
          id: 'life_stage_unknown',
          displayName: 'Unknown',
          aliases: ['unspecified', 'not specified', 'n/a'],
        ),
        LifeStage.gamete: _LifeStageMetadata(
          id: 'life_stage_gamete',
          displayName: 'Gamete',
          aliases: ['gametes'],
        ),
        LifeStage.embryo: _LifeStageMetadata(
          id: 'life_stage_embryo',
          displayName: 'Embryo',
          aliases: ['embryos'],
        ),
        LifeStage.larva: _LifeStageMetadata(
          id: 'life_stage_larva',
          displayName: 'Larva',
          aliases: ['larvae'],
        ),
        LifeStage.juvenile: _LifeStageMetadata(
          id: 'life_stage_juvenile',
          displayName: 'Juvenile',
          aliases: ['juveniles'],
        ),
        LifeStage.adult: _LifeStageMetadata(
          id: 'life_stage_adult',
          displayName: 'Adult',
          aliases: ['adults'],
        ),
        LifeStage.broodstock: _LifeStageMetadata(
          id: 'life_stage_broodstock',
          displayName: 'Broodstock',
          aliases: ['brood stock', 'spawning', 'spawning adult', 'spawning adults'],
        ),
      };

  /// Stable identifier used in Firestore/CSV payloads.
  String get id => _metadata[this]!.id;

  /// Human-friendly label for UI controls.
  String get displayName => _metadata[this]!.displayName;

  /// Optional alias strings (plural/synonyms) accepted when parsing life stages.
  List<String> get aliases => _metadata[this]!.aliases;

  static LifeStage fromName(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Unknown life stage. Expected one of: '
            '${LifeStage.values.map((stage) => stage.name).join(', ')}',
      );
    }
    return parsed;
  }

  static LifeStage? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    return LifeStage.values.firstWhereOrNull((stage) {
      if (stage.name.toLowerCase() == normalized) return true;
      if (stage.id.toLowerCase() == normalized) return true;
      return stage.aliases.any(
        (alias) => alias.trim().toLowerCase() == normalized,
      );
    });
  }
}

class _LifeStageMetadata {
  const _LifeStageMetadata({
    required this.id,
    required this.displayName,
    this.aliases = const <String>[],
  });

  final String id;
  final String displayName;
  final List<String> aliases;
}

/// Wraps a neutral life stage with an optional subtype. This lets dialogs
/// and CSV adapters capture organism-specific nuance without creating
/// additional enums.
class LifeStageSpec extends Equatable {
  const LifeStageSpec({required this.stage, this.subtype});

  final LifeStage stage;
  final String? subtype;

  String get displayName {
    final trimmed = subtype?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : stage.displayName;
  }

  LifeStageSpec copyWith({LifeStage? stage, String? subtype}) {
    return LifeStageSpec(
      stage: stage ?? this.stage,
      subtype: subtype ?? this.subtype,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': stage.id,
    if (subtype?.trim().isNotEmpty ?? false) 'subtype': subtype!.trim(),
  };

  factory LifeStageSpec.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      throw ArgumentError.notNull('json');
    }
    final stageId = json['id']?.toString();
    final stage = LifeStageX.tryParse(stageId) ?? LifeStage.unknown;
    return LifeStageSpec(stage: stage, subtype: json['subtype']?.toString());
  }

  @override
  List<Object?> get props => [stage, subtype];
}
