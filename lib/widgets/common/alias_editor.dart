// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/services/alias_uniqueness_service.dart';

typedef AliasIndexedValueChanged = void Function(int index, String value);

/// Alias systems that should be handled by dedicated fields instead of the alias list.
const Set<String> kReservedAliasSystems = {
  'clonalid',
  'clonal_id',
  'csr',
};

/// Builds a keyed map of validation errors for alias entries.
Map<int, String?> buildAliasErrorMap(List<GenetAliasEntry> aliases) {
  final errors = <int, String?>{};
  final seen = <String, int>{};

  for (var i = 0; i < aliases.length; i++) {
    final entry = aliases[i];
    final value = entry.value.trim();
    final source = entry.sourceSystem.trim().isEmpty
        ? 'custom'
        : entry.sourceSystem.trim().toLowerCase();

    if (value.isEmpty) {
      errors[i] = 'Alias value is required';
      continue;
    }

    final key = '$source::${value.toLowerCase()}';
    if (seen.containsKey(key)) {
      errors[i] = 'Duplicate alias';
      errors[seen[key]!] = 'Duplicate alias';
      continue;
    }

    seen[key] = i;
  }

  return errors;
}

/// Editable row for tagging an alias to a genet/provenance record.
class AliasEditorRow extends StatelessWidget {
  const AliasEditorRow({
    super.key,
    required this.index,
    required this.entry,
    required this.onValueChanged,
    required this.onSourceChanged,
    required this.onRemove,
    this.errorText,
    this.onLabelChanged,
    this.labelText,
    this.excludedSystems = const {},
    this.enabled = true,
  });

  final int index;
  final GenetAliasEntry entry;
  final String? errorText;
  final ValueChanged<String> onValueChanged;
  final ValueChanged<String> onSourceChanged;
  final VoidCallback onRemove;
  final ValueChanged<String>? onLabelChanged;
  final String? labelText;
  final Set<String> excludedSystems;

  /// Whether the alias row fields are editable.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final excluded = excludedSystems
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final sourceLabels = Map<String, String>.from(
      AliasUniquenessService.defaultSystems,
    )..removeWhere((key, _) => excluded.contains(key.toLowerCase()));
    final normalizedSource = entry.sourceSystem.trim();
    final normalizedLower = normalizedSource.toLowerCase();
    final hasKnownSource = sourceLabels.keys.contains(normalizedLower);

    String? dropdownValue = hasKnownSource
        ? normalizedLower
        : (normalizedSource.isEmpty ? null : normalizedSource);

    final dropdownItems = <DropdownMenuItem<String>>[
      ...sourceLabels.entries.map(
        (entry) => DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        ),
      ),
    ];

    if (!hasKnownSource && normalizedSource.isNotEmpty) {
      dropdownItems.insert(
        0,
        DropdownMenuItem<String>(
          value: normalizedSource,
          child: Text(normalizedSource),
        ),
      );
    }

    dropdownItems.add(
      const DropdownMenuItem<String>(
        value: '__custom__',
        child: Text('Custom source…'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: dropdownValue,
                items: dropdownItems,
                decoration: const InputDecoration(
                  labelText: 'Source System',
                  border: OutlineInputBorder(),
                ),
                onChanged: enabled
                    ? (value) => _handleSourceChanged(context, value)
                    : null,
              ),
            ),
            if (enabled)
              IconButton(
                tooltip: 'Remove alias',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('alias-value-$index'),
          enabled: enabled,
          decoration: InputDecoration(
            labelText: 'Identifier',
            hintText: 'Enter external ID',
            border: const OutlineInputBorder(),
            errorText: errorText,
          ),
          initialValue: entry.value,
          onChanged: enabled ? onValueChanged : null,
        ),
        if (onLabelChanged != null) ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('alias-label-$index'),
            enabled: enabled,
            decoration: InputDecoration(
              labelText: labelText ?? 'Display label (optional)',
              border: const OutlineInputBorder(),
            ),
            initialValue: entry.label ?? '',
            onChanged: enabled ? onLabelChanged : null,
          ),
        ],
      ],
    );
  }

  Future<void> _handleSourceChanged(
    BuildContext context,
    String? value,
  ) async {
    if (value == null) return;
    if (value == '__custom__') {
      final custom = await _promptCustomSource(context);
      if (custom != null && custom.trim().isNotEmpty) {
        onSourceChanged(custom.trim());
      }
      return;
    }
    onSourceChanged(value);
  }

  Future<String?> _promptCustomSource(BuildContext context) async {
    final controller = TextEditingController(text: entry.sourceSystem);
    return showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Alias Source'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Aquarium Legacy ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Reusable editor list that renders all alias rows plus the add/remove
/// controls shared across dialogs.
class AliasEditorList extends StatelessWidget {
  const AliasEditorList({
    super.key,
    required this.aliases,
    this.onAddAlias,
    this.onRemoveAlias,
    this.onValueChanged,
    this.onSourceChanged,
    this.onLabelChanged,
    this.emptyLabel = 'No aliases yet',
    this.addButtonLabel = 'Add Alias',
    this.errorMap,
    this.excludedSystems = const {},
    this.enabled = true,
  });

  final List<GenetAliasEntry> aliases;
  final VoidCallback? onAddAlias;
  final ValueChanged<int>? onRemoveAlias;
  final AliasIndexedValueChanged? onValueChanged;
  final AliasIndexedValueChanged? onSourceChanged;
  final AliasIndexedValueChanged? onLabelChanged;
  final String emptyLabel;
  final String addButtonLabel;
  final Map<int, String?>? errorMap;
  final Set<String> excludedSystems;

  /// Whether the alias fields are editable.
  /// Set to false for custodians who can only edit location/quantity.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final aliasErrors = errorMap ?? buildAliasErrorMap(aliases);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aliases.isEmpty)
          Text(
            enabled ? emptyLabel : 'No aliases (managed by owner)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ...aliases.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final alias = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AliasEditorRow(
                index: index,
                entry: alias,
                errorText: aliasErrors[index],
                onValueChanged: enabled && onValueChanged != null
                    ? (value) => onValueChanged!(index, value)
                    : (_) {},
                onSourceChanged: enabled && onSourceChanged != null
                    ? (source) => onSourceChanged!(index, source)
                    : (_) {},
                onLabelChanged: enabled && onLabelChanged != null
                    ? (label) => onLabelChanged!(index, label)
                    : null,
                excludedSystems: excludedSystems,
                onRemove: enabled && onRemoveAlias != null
                    ? () => onRemoveAlias!(index)
                    : () {},
                enabled: enabled,
              ),
            );
          },
        ),
        if (enabled)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddAlias,
              icon: const Icon(Icons.add),
              label: Text(addButtonLabel),
            ),
          ),
      ],
    );
  }
}
