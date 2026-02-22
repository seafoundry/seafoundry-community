// @tier: community
import 'package:collection/collection.dart';

/// Enumerates the neutral reproductive event kinds supported by the taxonomy
/// layer. These capture the high-level method used to produce new material
/// (spawning, gamete collection, settlement, etc.) so organism-specific
/// workflows can share the same bookkeeping model.
enum ReproductiveEventKind {
  sexualSpawn,
  gameteCollection,
  cross,
  larvalSettlement,
  asexualPropagation,
}

extension ReproductiveEventKindX on ReproductiveEventKind {
  static const Map<ReproductiveEventKind, _ReproductiveEventKindMetadata>
      _metadata = {
    ReproductiveEventKind.sexualSpawn: _ReproductiveEventKindMetadata(
      id: 'sexual_spawn',
      label: 'Sexual Spawn',
      aliases: ['spawn', 'sexual', 'broadcast'],
    ),
    ReproductiveEventKind.gameteCollection: _ReproductiveEventKindMetadata(
      id: 'gamete_collection',
      label: 'Gamete Collection',
      aliases: ['gamete', 'collection'],
    ),
    ReproductiveEventKind.cross: _ReproductiveEventKindMetadata(
      id: 'cross',
      label: 'Cross / Fertilization',
      aliases: ['cross_fertilization', 'crossing'],
    ),
    ReproductiveEventKind.larvalSettlement: _ReproductiveEventKindMetadata(
      id: 'larval_settlement',
      label: 'Larval Settlement',
      aliases: ['settlement', 'larval'],
    ),
    ReproductiveEventKind.asexualPropagation: _ReproductiveEventKindMetadata(
      id: 'asexual_propagation',
      label: 'Asexual Propagation',
      aliases: ['fragmentation', 'asexual'],
    ),
  };

  String get id => _metadata[this]!.id;
  String get label => _metadata[this]!.label;
  List<String> get aliases => _metadata[this]!.aliases;

  static ReproductiveEventKind fromName(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Unsupported reproductive event kind. '
            'Expected one of: ${ReproductiveEventKind.values.map((k) => k.id).join(', ')}',
      );
    }
    return parsed;
  }

  static ReproductiveEventKind? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    return ReproductiveEventKind.values.firstWhereOrNull((kind) {
      if (kind.name.toLowerCase() == normalized) return true;
      final metadata = _metadata[kind]!;
      if (metadata.id == normalized) return true;
      return metadata.aliases.any(
        (alias) => alias.toLowerCase() == normalized,
      );
    });
  }
}

class _ReproductiveEventKindMetadata {
  const _ReproductiveEventKindMetadata({
    required this.id,
    required this.label,
    this.aliases = const <String>[],
  });

  final String id;
  final String label;
  final List<String> aliases;
}
