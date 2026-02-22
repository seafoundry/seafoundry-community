// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/models.dart';

/// Manages the list of aliases for a genet during creation/editing.
///
/// Supports adding, updating (value/source/label), and removing alias entries.
/// Provides deduplication and normalization when converting to OrganismAlias.
class AliasCubit extends Cubit<AliasState> {
  AliasCubit() : super(const AliasState(aliases: []));

  /// Add a new empty alias entry to the list.
  void addAlias() {
    final updatedAliases = List<GenetAliasEntry>.from(state.aliases)
      ..add(const GenetAliasEntry());
    emit(state.copyWith(aliases: updatedAliases));
  }

  /// Update the value of an alias at the specified index.
  ///
  /// Returns without emitting if the index is invalid.
  void updateAliasValue(int index, String value) {
    if (index < 0 || index >= state.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(state.aliases);
    updatedAliases[index] = updatedAliases[index].copyWith(value: value);
    emit(state.copyWith(aliases: updatedAliases));
  }

  /// Update the source system of an alias at the specified index.
  ///
  /// Returns without emitting if the index is invalid.
  void updateAliasSource(int index, String source) {
    if (index < 0 || index >= state.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(state.aliases);
    updatedAliases[index] = updatedAliases[index].copyWith(sourceSystem: source);
    emit(state.copyWith(aliases: updatedAliases));
  }

  /// Update the label of an alias at the specified index.
  ///
  /// Returns without emitting if the index is invalid.
  void updateAliasLabel(int index, String label) {
    if (index < 0 || index >= state.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(state.aliases);
    updatedAliases[index] = updatedAliases[index].copyWith(label: label);
    emit(state.copyWith(aliases: updatedAliases));
  }

  /// Remove the alias at the specified index.
  ///
  /// Returns without emitting if the index is invalid.
  void removeAlias(int index) {
    if (index < 0 || index >= state.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(state.aliases)
      ..removeAt(index);
    emit(state.copyWith(aliases: updatedAliases));
  }

  /// Get the list of alias labels from the current state.
  ///
  /// Returns labels from non-empty aliases, using value as fallback if label is null.
  List<String> getLabels() {
    return state.aliases
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => (entry.label ?? entry.value).trim())
        .where((label) => label.isNotEmpty)
        .toList();
  }

  /// Initialize aliases from an existing Genet.
  ///
  /// Extracts aliases from the genet's alias field and converts them to
  /// GenetAliasEntry objects. Filters out entries with empty values.
  void initializeFromGenet(Genet genet) {
    final raw = genet.aliases ?? const <Map<String, dynamic>>[];
    if (raw.isEmpty) {
      emit(const AliasState(aliases: []));
      return;
    }

    final entries = raw
        .map(
          (entry) => GenetAliasEntry(
            sourceSystem: entry['sourceSystem']?.toString() ??
                entry['source']?.toString() ??
                'custom',
            value: entry['value']?.toString() ?? entry['label']?.toString() ?? '',
            label: entry['label']?.toString(),
          ),
        )
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList();

    emit(AliasState(aliases: entries));
  }

  /// Convert current alias entries to normalized OrganismAlias list.
  ///
  /// Performs deduplication based on source system and value (case-insensitive).
  /// Trims values and normalizes source systems to lowercase.
  /// Filters out empty values.
  List<OrganismAlias> toOrganismAliases() {
    final seen = <String>{};
    final cleaned = <OrganismAlias>[];

    for (final entry in state.aliases) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;

      final source = entry.sourceSystem.trim().isEmpty
          ? 'custom'
          : entry.sourceSystem.trim().toLowerCase();
      final key = '$source::${value.toLowerCase()}';

      if (seen.add(key)) {
        cleaned.add(
          entry.copyWith(sourceSystem: source, value: value).toOrganismAlias(),
        );
      }
    }

    return cleaned;
  }

  /// Reset to empty alias list.
  void clear() {
    emit(const AliasState(aliases: []));
  }
}

/// Immutable state representing the list of alias entries.
class AliasState extends Equatable {
  const AliasState({required this.aliases});

  final List<GenetAliasEntry> aliases;

  @override
  List<Object?> get props => [aliases];

  AliasState copyWith({List<GenetAliasEntry>? aliases}) {
    return AliasState(aliases: aliases ?? this.aliases);
  }
}
