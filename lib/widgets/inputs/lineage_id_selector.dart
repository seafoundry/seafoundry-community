// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/dialogs/create_genet_dialog.dart';
import 'package:seafoundry_app/widgets/inputs/provenance_autocomplete_field.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';

typedef GenetLabelBuilder = String Function(Genet genet);
typedef GenetFilter = bool Function(Genet genet);

enum _ExternalFieldKind { pid, alias, clonal, accession }

class LineageIdSelector extends StatefulWidget {
  const LineageIdSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.species,
    this.allowedProvenanceTypeIds,
    this.localFilter,
    this.itemLabelBuilder,
    this.helperText,
    this.allowCreate = false,
    this.createLabel = 'Create New Genet',
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final Species? species;
  final List<String>? allowedProvenanceTypeIds;
  final GenetFilter? localFilter;
  final GenetLabelBuilder? itemLabelBuilder;
  final String? helperText;
  final bool allowCreate;
  final String createLabel;

  @override
  State<LineageIdSelector> createState() => _LineageIdSelectorState();
}

class _LineageIdSelectorState extends State<LineageIdSelector> {
  final _pidField = _ExternalFieldState(
    kind: _ExternalFieldKind.pid,
    aliasType: null,
  );
  final _aliasField = _ExternalFieldState(
    kind: _ExternalFieldKind.alias,
    aliasType: null,
  );
  final _clonalField = _ExternalFieldState(
    kind: _ExternalFieldKind.clonal,
    aliasType: ProvenanceAliasType.clonalId,
  );
  final _accessionField = _ExternalFieldState(
    kind: _ExternalFieldKind.accession,
    aliasType: ProvenanceAliasType.accessionNumber,
  );

  ProvenanceLookupService? _lookupService;
  Future<List<Genet>>? _genetsFuture;
  String? _speciesCode;
  _ExternalFieldKind? _activeExternalKind;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lookupService ??= context.maybeRead<ProvenanceLookupService>();
    _genetsFuture ??= context.read<GenetRepository>().getAll();
    _speciesCode ??= widget.species?.code;
  }

  @override
  void didUpdateWidget(LineageIdSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSpeciesCode = widget.species?.code;
    if (nextSpeciesCode != _speciesCode) {
      _speciesCode = nextSpeciesCode;
      _clearExternalSelection(notifyParent: false);
    }
  }

  @override
  void dispose() {
    _pidField.dispose();
    _aliasField.dispose();
    _clonalField.dispose();
    _accessionField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSpecies = widget.species != null;
    final externalEnabled = hasSpecies && _lookupService != null;

    return FutureBuilder<List<Genet>>(
      future: _genetsFuture,
      builder: (context, snapshot) {
        final allGenets = snapshot.data ?? const <Genet>[];
        final filteredGenets = _filterGenets(allGenets);
        final selectedLocal = _findSelectedLocal(filteredGenets, widget.value);
        final isLocalSelection = selectedLocal != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLocalSelector(
              context: context,
              snapshot: snapshot,
              filteredGenets: filteredGenets,
              selectedLocal: selectedLocal,
            ),
            if (widget.allowCreate) ...[
              const SizedBox(height: 8),
              OceanicSecondaryButton(
                onPressed: () => _showCreateGenetDialog(context),
                icon: Icons.add,
                label: widget.createLabel,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'External lookup',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              hasSpecies
                  ? 'Search PIDs, aliases, clonal IDs, or accession numbers from other organizations.'
                  : 'Select a species to search external IDs.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ExpansionTile(
                key: const PageStorageKey('lineage_external_ids'),
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12),
                title: Text(
                  'Select External Aliases & IDs',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                children: [
                  ProvenanceAutocompleteField(
                    label: 'Provenance ID (PID)',
                    hintText: 'Search PID (e.g., PID-APAL-0007)',
                    icon: Icons.fingerprint,
                    value: _pidField.value,
                    suggestions: _pidField.suggestions,
                    isSearching: _pidField.isSearching,
                    displayValueBuilder: (suggestion) =>
                        suggestion.provenanceId,
                    showOtherAliases: false,
                    enabled: externalEnabled && !_isDisabled(_pidField),
                    onTextChanged: (value) =>
                        _onExternalTextChanged(_pidField, value),
                    onSuggestionSelected: (suggestion) =>
                        _selectExternalSuggestion(_pidField, suggestion),
                    onEditingComplete: () => _commitManualExternal(_pidField),
                    onDisabledTap: _isDisabled(_pidField)
                        ? () => _clearExternalSelection()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ProvenanceAutocompleteField(
                    label: 'Alias',
                    hintText: 'Search alias or local ID',
                    icon: Icons.label_outline,
                    value: _aliasField.value,
                    suggestions: _aliasField.suggestions,
                    isSearching: _aliasField.isSearching,
                    displayValueBuilder: (suggestion) =>
                        ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                    showOtherAliases: false,
                    enabled: externalEnabled && !_isDisabled(_aliasField),
                    onTextChanged: (value) =>
                        _onExternalTextChanged(_aliasField, value),
                    onSuggestionSelected: (suggestion) =>
                        _selectExternalSuggestion(_aliasField, suggestion),
                    onEditingComplete: () => _commitManualExternal(_aliasField),
                    onDisabledTap: _isDisabled(_aliasField)
                        ? () => _clearExternalSelection()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ProvenanceAutocompleteField(
                    label: 'Clonal ID',
                    hintText: 'Search clonal ID',
                    icon: Icons.content_copy,
                    value: _clonalField.value,
                    suggestions: _clonalField.suggestions,
                    isSearching: _clonalField.isSearching,
                    enabled: externalEnabled && !_isDisabled(_clonalField),
                    onTextChanged: (value) =>
                        _onExternalTextChanged(_clonalField, value),
                    onSuggestionSelected: (suggestion) =>
                        _selectExternalSuggestion(_clonalField, suggestion),
                    onEditingComplete: () =>
                        _commitManualExternal(_clonalField),
                    onDisabledTap: _isDisabled(_clonalField)
                        ? () => _clearExternalSelection()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ProvenanceAutocompleteField(
                    label: 'Accession Number',
                    hintText: 'Search accession number',
                    icon: Icons.confirmation_number,
                    value: _accessionField.value,
                    suggestions: _accessionField.suggestions,
                    isSearching: _accessionField.isSearching,
                    displayValueBuilder: (suggestion) =>
                        ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                    showOtherAliases: false,
                    enabled: externalEnabled && !_isDisabled(_accessionField),
                    onTextChanged: (value) =>
                        _onExternalTextChanged(_accessionField, value),
                    onSuggestionSelected: (suggestion) =>
                        _selectExternalSuggestion(_accessionField, suggestion),
                    onEditingComplete: () =>
                        _commitManualExternal(_accessionField),
                    onDisabledTap: _isDisabled(_accessionField)
                        ? () => _clearExternalSelection()
                        : null,
                  ),
                ],
              ),
            ),
            if (!isLocalSelection &&
                widget.value != null &&
                widget.value!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _ExternalSelectionChip(
                value: widget.value!.trim(),
                onClear: _clearSelection,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLocalSelector({
    required BuildContext context,
    required AsyncSnapshot<List<Genet>> snapshot,
    required List<Genet> filteredGenets,
    required Genet? selectedLocal,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (snapshot.hasError) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          helperText: widget.helperText,
        ),
        child: Text(
          'Unable to load local genets.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (filteredGenets.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          helperText: widget.helperText,
        ),
        child: const Text(
          'No matching genets in inventory.',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('lineage_${widget.label}_${selectedLocal?.id ?? 'none'}'),
      initialValue: selectedLocal?.id,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        helperText: widget.helperText,
      ),
      items: filteredGenets.map((genet) {
        final label = widget.itemLabelBuilder?.call(genet) ?? genet.name;
        return DropdownMenuItem<String>(value: genet.id, child: Text(label));
      }).toList(),
      onChanged: (value) {
        if (value == null || value.isEmpty) return;
        widget.onChanged(value);
        _clearExternalSelection(notifyParent: false);
      },
    );
  }

  List<Genet> _filterGenets(List<Genet> genets) {
    var filtered = genets;
    final speciesId = widget.species?.id;
    if (speciesId != null && speciesId.trim().isNotEmpty) {
      filtered = filtered
          .where((g) => g.speciesId.trim() == speciesId.trim())
          .toList();
    }
    if (widget.allowedProvenanceTypeIds != null) {
      filtered = filtered.where((g) {
        if (widget.allowedProvenanceTypeIds!.contains(g.provenanceTypeId)) {
          return true;
        }
        final parsed = ProvenanceTypeX.tryParse(g.provenanceTypeId);
        return parsed != null &&
            widget.allowedProvenanceTypeIds!.contains(parsed.id);
      }).toList();
    }
    if (widget.localFilter != null) {
      filtered = filtered.where(widget.localFilter!).toList();
    }
    return filtered;
  }

  Genet? _findSelectedLocal(List<Genet> genets, String? value) {
    final id = value?.trim();
    if (id == null || id.isEmpty) return null;
    try {
      return genets.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  void _onExternalTextChanged(_ExternalFieldState field, String value) {
    field.debounce?.cancel();
    if (field.lastSelectedValue != null && value == field.lastSelectedValue) {
      return;
    }
    field.lastSelectedValue = null;
    setState(() {
      field.value = value;
      if (field.match != null) {
        field.match = null;
        field.suggestions = const [];
      }
    });
    field.debounce = Timer(const Duration(milliseconds: 300), () {
      _performExternalSearch(field, value);
    });
  }

  Future<void> _performExternalSearch(
    _ExternalFieldState field,
    String prefix,
  ) async {
    final service = _lookupService;
    if (service == null || !mounted) return;

    final requestId = ++field.searchId;
    setState(() => field.isSearching = true);

    try {
      final results = field.kind == _ExternalFieldKind.pid
          ? await service.searchProvenanceIds(
              prefix: prefix,
              speciesCode: _speciesCode ?? '',
            )
          : await service.searchAliases(
              prefix: prefix,
              speciesCode: _speciesCode ?? '',
              aliasType: field.aliasType,
            );

      if (!mounted || requestId != field.searchId) return;
      setState(() {
        field.suggestions = results;
        field.isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != field.searchId) return;
      setState(() {
        field.isSearching = false;
        field.suggestions = const [];
      });
    }
  }

  void _selectExternalSuggestion(
    _ExternalFieldState field,
    ProvenanceSuggestion suggestion,
  ) {
    final displayValue = switch (field.kind) {
      _ExternalFieldKind.pid => suggestion.provenanceId,
      _ExternalFieldKind.clonal => ClonalIdDisplayService.resolveForSuggestion(
        suggestion,
      ),
      _ExternalFieldKind.alias => suggestion.aliasValue,
      _ExternalFieldKind.accession => suggestion.aliasValue,
    };
    setState(() {
      field.value = displayValue;
      field.lastSelectedValue = displayValue;
      field.match = suggestion;
      field.suggestions = const [];
      field.isSearching = false;
      _activeExternalKind = field.kind;
      _clearExternalFields(
        except: field,
        preservePid: field.kind != _ExternalFieldKind.pid,
        notify: false,
      );
      if (field.kind != _ExternalFieldKind.pid) {
        _pidField.value = suggestion.provenanceId;
        _pidField.lastSelectedValue = suggestion.provenanceId;
        _pidField.suggestions = const [];
        _pidField.isSearching = false;
      }
    });
    widget.onChanged(suggestion.provenanceId);
  }

  void _commitManualExternal(_ExternalFieldState field) {
    final value = field.value.trim();
    if (value.isEmpty) return;
    if (field.match != null && field.kind != _ExternalFieldKind.pid) {
      final displayValue = switch (field.kind) {
        _ExternalFieldKind.clonal =>
          ClonalIdDisplayService.resolveForSuggestion(field.match!),
        _ExternalFieldKind.alias => field.match!.aliasValue,
        _ExternalFieldKind.accession => field.match!.aliasValue,
        _ExternalFieldKind.pid => field.match!.provenanceId,
      };
      if (displayValue == value) return;
    }
    setState(() {
      field.match = null;
      field.suggestions = const [];
      _activeExternalKind = field.kind;
      _clearExternalFields(except: field, notify: false);
    });
    widget.onChanged(value);
  }

  void _clearExternalFields({
    _ExternalFieldState? except,
    bool preservePid = false,
    bool notify = true,
  }) {
    void run() {
      if (except != _pidField && !preservePid) _resetField(_pidField);
      if (except != _aliasField) _resetField(_aliasField);
      if (except != _clonalField) _resetField(_clonalField);
      if (except != _accessionField) _resetField(_accessionField);
    }

    if (notify) {
      setState(run);
    } else {
      run();
    }
  }

  void _clearSelection() {
    widget.onChanged(null);
    _clearExternalSelection(notifyParent: false);
  }

  void _clearExternalSelection({bool notifyParent = true}) {
    setState(() {
      _activeExternalKind = null;
      _resetField(_pidField);
      _resetField(_aliasField);
      _resetField(_clonalField);
      _resetField(_accessionField);
    });
    if (notifyParent) {
      widget.onChanged(null);
    }
  }

  bool _isLocked(_ExternalFieldState field) =>
      _activeExternalKind != null && _activeExternalKind != field.kind;

  bool get _hasResolvedSelection =>
      _pidField.match != null ||
      _aliasField.match != null ||
      _clonalField.match != null ||
      _accessionField.match != null;

  bool _isDisabled(_ExternalFieldState field) =>
      _hasResolvedSelection || _isLocked(field);

  void _resetField(_ExternalFieldState field) {
    field.debounce?.cancel();
    field.value = '';
    field.match = null;
    field.suggestions = const [];
    field.isSearching = false;
    field.lastSelectedValue = null;
  }

  Future<void> _showCreateGenetDialog(BuildContext context) async {
    Species? initialSpecies = widget.species;
    if (initialSpecies == null) {
      final fallback = SpeciesRegistry.globalAll();
      if (fallback.isNotEmpty) {
        initialSpecies = fallback.first;
      }
    }

    final createdGenet = await CreateGenetDialog.show(
      context,
      initialSpecies: initialSpecies,
    );
    if (!context.mounted || createdGenet == null) return;
    setState(() {
      _genetsFuture = context.read<GenetRepository>().getAll();
    });
    widget.onChanged(createdGenet.id);
  }
}

class _ExternalFieldState {
  _ExternalFieldState({required this.kind, required this.aliasType});

  final _ExternalFieldKind kind;
  final ProvenanceAliasType? aliasType;
  String value = '';
  List<ProvenanceSuggestion> suggestions = const [];
  bool isSearching = false;
  ProvenanceSuggestion? match;
  Timer? debounce;
  int searchId = 0;
  String? lastSelectedValue;

  void dispose() {
    debounce?.cancel();
  }
}

class _ExternalSelectionChip extends StatelessWidget {
  const _ExternalSelectionChip({required this.value, required this.onClear});

  final String value;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.link, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Selected ID: $value',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.primary),
          ),
        ),
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.clear, size: 18),
          tooltip: 'Clear selection',
        ),
      ],
    );
  }
}
